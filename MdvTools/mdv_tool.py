#!/usr/bin/env python3
"""
mdv_tool.py — Outil d'images Microdrive QLAY pour Sinclair QL
Format : QLAY MDV, 255 secteurs × 686 bytes = 174930 bytes
Compatible MAME (-utap1), QLAY, Q-emuLator (QLAY style), vDriveQL

Sous-commandes :
  create   crée une image
  list     liste le contenu d'une image
  extract  extrait des fichiers d'une image
  test     lance les tests unitaires embarqués

Le format complet est documenté dans MDV_FORMAT.md. Rappels :

Secteur sur disque (686 bytes) :
  [  0.. 11] Header preamble : 10×0x00 + 2×0xFF
  [ 12.. 25] Header data     : sflag(1) + sno(1) + name(10) + rand(2)
  [ 26.. 27] Header checksum : sum(0x0F0F + header_data)
  [ 28.. 39] Block preamble  : 10×0x00 + 2×0xFF
  [ 40.. 41] Block header    : fno(1) + bno(1)
  [ 42.. 43] Block checksum  : sum(0x0F0F + block_header)
  [ 44.. 51] Data preamble   : 6×0x00 + 2×0xFF
  [ 52..563] Data            : 512 bytes
  [564..565] Data checksum   : sum(0x0F0F + data)
  [566..685] Filler          : 120 bytes

Structure logique :
  Secteur 0  : sector map — fno=0x80 dans le block header, mais identifié
               par 0xF8 dans les données du map (deux encodages distincts,
               confirmé par un FORMAT réel sous Minerva)
  Secteur 1+ : répertoire (fno=0x00) puis fichiers (fno=1..0xF7)

Répertoire (fno=0x00, blocs de 8 entrées de 64 bytes) : l'entrée du fichier
fno=k est à l'offset 64*k ; le slot 0 est l'en-tête du répertoire lui-même,
dont les 4 premiers bytes (big-endian) donnent la longueur totale
(64 × (1 + nombre max de fno)). Confirmé par un SAVE réel sous Minerva.

En-tête de fichier QDOS dans data[0..63] du bloc 0 de chaque fichier :
  [0..3]   length      : longueur totale (header 64 + données) big-endian
  [4]      access      : droits (0=normal)
  [5]      type        : 0=data, 1=exec
  [6..9]   dataspace   : pile+BSS pour exec, big-endian (lu depuis en-tête XTcc)
  [10..13] extra       : réservé (0)
  [14..15] name_len    : longueur du nom, big-endian
  [16..51] name        : nom du fichier (max 36 chars, paddé de 0)
  [52..55] last_update : date (secondes depuis 1/1/1961), big-endian
  [56..63] version/backup : réservé (0)
"""

import sys
import os
import struct
import time
import argparse
import random
import unittest

# ---------------------------------------------------------------------------
# Constantes du format QLAY MDV
# ---------------------------------------------------------------------------

NSECTORS    = 255       # nombre de secteurs physiques
SECTOR_LEN  = 686       # taille d'un secteur sur disque (bytes)
MDV_SIZE    = NSECTORS * SECTOR_LEN  # = 174930 bytes
DATA_SIZE   = 512       # données utiles par secteur
FILE_HDR    = 64        # taille de l'en-tête de fichier QDOS
QDOS_EPOCH  = (9 * 365 + 2) * 86400  # décalage époque QDOS (1/1/1961 - 1/1/1970)

# fno spéciaux dans le BLOCK HEADER
FNO_MAP  = 0x80  # secteur map (secteur 0) — PAS 0xF8 (confirmé par FORMAT réel)
FNO_DIR  = 0x00  # secteur répertoire
FNO_VAC  = 0xFD  # secteur vacant
FNO_NAV  = 0xFF  # secteur non disponible
FNO_FILE_MAX = 0xF7  # dernier fno de fichier valide

# Identifiants dans les DONNÉES du sector map (encodage distinct du block header)
MAP_SELF     = 0xF8  # entrée du map lui-même
MAP_VACANT   = 0xFD  # secteur libre
MAP_NONAVAIL = 0xFF  # secteur non disponible


# ---------------------------------------------------------------------------
# Calcul du checksum QDOS
# ---------------------------------------------------------------------------

def qdos_checksum(data: bytes) -> int:
    """Checksum QDOS : somme des octets + 0x0F0F, tronquée à 16 bits."""
    s = 0x0F0F
    for b in data:
        s += b
    return s & 0xFFFF


# ---------------------------------------------------------------------------
# Construction d'un secteur sur disque
# ---------------------------------------------------------------------------

def build_sector(sflag: int, sno: int, name: bytes, rand: int,
                 fno: int, bno: int, data: bytes) -> bytes:
    """
    Construit les 686 bytes d'un secteur QLAY MDV.

    sflag : 0xFF = secteur valide
    sno   : numéro de secteur physique (0-254)
    name  : nom de cartouche, 10 bytes (paddé d'espaces)
    rand  : valeur aléatoire 16 bits (identifiant cartouche)
    fno   : numéro de fichier (0x00=dir, 0x80=map, 0xFD=vacant, 1-0xF7=fichier)
    bno   : numéro de bloc dans le fichier
    data  : 512 bytes de données (paddé de 0 si plus court)
    """
    assert len(name) == 10
    assert len(data) <= DATA_SIZE

    # Padder les données à 512 bytes
    data = data.ljust(DATA_SIZE, b'\x00')

    # --- Header ---
    hdr_preamble = b'\x00' * 10 + b'\xFF\xFF'
    hdr_data = bytes([sflag, sno]) + name + struct.pack('<H', rand)
    hdr_csum = struct.pack('<H', qdos_checksum(hdr_data))

    # --- Block header ---
    blk_preamble = b'\x00' * 10 + b'\xFF\xFF'
    blk_data = bytes([fno, bno])
    blk_csum = struct.pack('<H', qdos_checksum(blk_data))

    # --- Data ---
    dat_preamble = b'\x00' * 6 + b'\xFF\xFF'
    dat_csum = struct.pack('<H', qdos_checksum(data))

    # --- Filler ---
    filler = b'\x5A' * 120

    sector = (hdr_preamble + hdr_data + hdr_csum +
              blk_preamble + blk_data + blk_csum +
              dat_preamble + data + dat_csum +
              filler)

    assert len(sector) == SECTOR_LEN, f"Sector len = {len(sector)}"
    return sector


# ---------------------------------------------------------------------------
# Lecture de la dataspace depuis l'en-tête XTcc d'un binaire QDOS
# ---------------------------------------------------------------------------

def read_xtcc_dataspace(filepath: str) -> int:
    """
    Lit la dataspace depuis l'en-tête de fichier QDOS (XTcc).
    L'en-tête de fichier fait 64 bytes ; la dataspace est aux octets [6..9]
    en big-endian.
    Retourne 0 si le fichier n'a pas d'en-tête QDOS valide.
    """
    try:
        with open(filepath, 'rb') as f:
            hdr = f.read(FILE_HDR)
        if len(hdr) < FILE_HDR:
            return 0
        # Vérifier que le type est 1 (exécutable)
        if hdr[5] == 1:
            dataspace = struct.unpack('>I', hdr[6:10])[0]
            return dataspace
        return 0
    except OSError:
        return 0


# ---------------------------------------------------------------------------
# En-tête de fichier QDOS : construction et décodage
# ---------------------------------------------------------------------------

def build_file_header(filename: str, file_size: int,
                      is_exec: bool, dataspace: int,
                      mtime: int = 0) -> bytes:
    """
    Construit les 64 bytes d'en-tête de fichier QDOS.

    filename  : nom du fichier sur la cartouche (max 36 chars)
    file_size : taille des données du fichier (sans l'en-tête)
    is_exec   : True si fichier exécutable (type=1)
    dataspace : dataspace en bytes (pour les exécutables)
    mtime     : date de modification Unix (secondes depuis 1/1/1970)
    """
    if len(filename) > 36:
        raise ValueError(f"Nom de fichier trop long (max 36): {filename}")

    total_length = file_size + FILE_HDR  # longueur totale incluant l'en-tête
    qdos_time = mtime + QDOS_EPOCH if mtime else 0

    hdr = bytearray(FILE_HDR)
    struct.pack_into('>I', hdr, 0,  total_length)   # [0..3]  length
    hdr[4] = 0                                        # [4]     access
    hdr[5] = 1 if is_exec else 0                     # [5]     type
    struct.pack_into('>I', hdr, 6,  dataspace)       # [6..9]  dataspace
    # [10..13] réservé = 0
    name_bytes = filename.encode('ascii', errors='replace')
    struct.pack_into('>H', hdr, 14, len(name_bytes)) # [14..15] name_len
    hdr[16:16+len(name_bytes)] = name_bytes          # [16..51] name
    struct.pack_into('>I', hdr, 52, qdos_time)       # [52..55] last_update

    return bytes(hdr)


def parse_file_header(hdr: bytes) -> dict:
    """
    Décode 64 bytes d'en-tête de fichier QDOS (ou d'entrée de répertoire).
    Retourne un dict {length, data_size, access, type, dataspace, name, mtime}
    où length est la longueur totale (en-tête inclus), data_size la longueur
    des données seules, et mtime la date Unix (0 si absente).
    """
    length    = struct.unpack('>I', hdr[0:4])[0]
    access    = hdr[4]
    ftype     = hdr[5]
    dataspace = struct.unpack('>I', hdr[6:10])[0]
    name_len  = struct.unpack('>H', hdr[14:16])[0]
    name      = hdr[16:16+min(name_len, 36)].decode('ascii', errors='replace')
    qdos_time = struct.unpack('>I', hdr[52:56])[0]
    mtime     = qdos_time - QDOS_EPOCH if qdos_time else 0
    return {
        'length':    length,
        'data_size': max(0, length - FILE_HDR),
        'access':    access,
        'type':      ftype,
        'dataspace': dataspace,
        'name':      name,
        'mtime':     mtime,
    }


# ---------------------------------------------------------------------------
# Écriture : image MDV en construction
# ---------------------------------------------------------------------------

class MDVImage:
    """
    Représentation en mémoire d'une image Microdrive QLAY en construction.

    Structure interne :
      self.sectors : liste de 255 éléments, chacun = dict {
          'sflag': int,   # 0xFF=valide
          'fno':  int,    # numéro de fichier (block header)
          'bno':  int,    # numéro de bloc dans le fichier
          'data': bytes,  # 512 bytes de données
      }
    """

    def __init__(self, label: str = 'MDVIMAGE', rand: int = None):
        """
        label : nom de la cartouche (max 10 chars)
        rand  : valeur aléatoire 16 bits (identifiant unique de cartouche)
        """
        self.label = label[:10].upper()
        self.rand  = rand if rand is not None else (random.randint(0, 0xFFFF))
        self.name  = self.label.encode('ascii').ljust(10, b' ')[:10]

        # 255 secteurs initialisés comme vacants
        self.sectors = []
        for s in range(NSECTORS):
            self.sectors.append({
                'sflag': 0xFF,   # secteur valide mais vacant
                'fno':   FNO_VAC,
                'bno':   0,
                'data':  b'\x00' * DATA_SIZE,
            })

        # Secteur 0 : sector map (fno=0x80 dans le block header)
        self.sectors[0]['fno'] = FNO_MAP

        # Secteur 1 : début du répertoire (fno=0x00, bno=0)
        self.sectors[1]['fno'] = FNO_DIR
        self.sectors[1]['bno'] = 0

        # Pointeur sur le prochain secteur libre (commence à 2)
        self._next_sector = 2
        # Prochain numéro de fichier libre (commence à 1)
        self._next_fno = 1
        # Entrées de répertoire : l'entrée du fichier fno=k est le slot k du
        # répertoire ; le slot 0 est l'en-tête du répertoire lui-même.
        self._dir_entries = []   # liste de bytes(64), index k-1 pour fno=k
        self._dir_blocks  = 1   # nombre de secteurs alloués au répertoire

    @property
    def _dir_length(self) -> int:
        """Longueur totale du répertoire : slot d'en-tête + une entrée par fno."""
        return FILE_HDR * (1 + len(self._dir_entries))

    # --- Allocation ---

    def _alloc_sector(self) -> int:
        """Retourne l'index du prochain secteur libre, ou lève une exception."""
        if self._next_sector >= NSECTORS:
            raise RuntimeError("Cartouche MDV pleine")
        s = self._next_sector
        self._next_sector += 1
        return s

    # --- Sector map ---

    def _build_map_data(self) -> bytes:
        """
        Construit les 512 bytes du sector map (données du secteur 0).
        data[2*s..2*s+1] = (fno, bno) pour le secteur physique s ;
        le map lui-même est encodé (0xF8, 0x00) — pas 0x80 comme dans son
        block header. Vacant : (0xFD, 0x00), non disponible : (0xFF, 0x00).
        """
        data = bytearray(DATA_SIZE)
        for s in range(NSECTORS):
            fno = self.sectors[s]['fno']
            bno = self.sectors[s]['bno']
            if fno == FNO_VAC:
                data[2*s]   = MAP_VACANT
                data[2*s+1] = 0x00
            elif fno == FNO_MAP:
                data[2*s]   = MAP_SELF
                data[2*s+1] = 0x00
            else:
                data[2*s]   = fno
                data[2*s+1] = bno
        # Dernier secteur = non disponible
        data[2*254]   = MAP_NONAVAIL
        data[2*254+1] = 0x00
        return bytes(data)

    def _build_dir_data(self, block_no: int) -> bytes:
        """
        Construit les 512 bytes d'un bloc de répertoire (8 slots de 64 bytes).
        Slot global 0 (début du bloc 0) = en-tête du répertoire : longueur
        totale big-endian dans les 4 premiers bytes, reste à zéro.
        Slot global k (k>=1) = entrée du fichier fno=k.
        """
        data = bytearray(DATA_SIZE)
        for i in range(8):
            slot = block_no * 8 + i
            if slot == 0:
                struct.pack_into('>I', data, 0, self._dir_length)
            elif slot <= len(self._dir_entries):
                data[i*FILE_HDR:(i+1)*FILE_HDR] = self._dir_entries[slot-1]
        return bytes(data)

    # --- Ajout de fichier ---

    def add_file(self, qdos_name: str, file_data: bytes,
                 is_exec: bool = False, dataspace: int = 0,
                 mtime: int = 0) -> None:
        """
        Ajoute un fichier dans l'image MDV.

        qdos_name : nom QDOS du fichier sur la cartouche (max 36 chars)
        file_data : contenu brut du fichier (sans en-tête QDOS)
        is_exec   : True si exécutable
        dataspace : dataspace en bytes (lue depuis XTcc si is_exec)
        mtime     : date de modification Unix
        """
        if len(qdos_name) > 36:
            raise ValueError(f"Nom trop long (max 36 chars): {qdos_name}")
        if self._next_fno > FNO_FILE_MAX:
            raise RuntimeError(f"Trop de fichiers (max {FNO_FILE_MAX})")

        # Construire l'en-tête de fichier QDOS
        file_hdr = build_file_header(qdos_name, len(file_data),
                                     is_exec, dataspace, mtime)

        # Combiner en-tête + données
        payload = file_hdr + file_data

        # Calculer le nombre de secteurs nécessaires
        n_sectors = (len(payload) + DATA_SIZE - 1) // DATA_SIZE

        fno = self._next_fno
        self._next_fno += 1

        # Écrire les secteurs du fichier
        for bno in range(n_sectors):
            s_idx = self._alloc_sector()
            chunk = payload[bno*DATA_SIZE : (bno+1)*DATA_SIZE]
            self.sectors[s_idx]['fno']  = fno
            self.sectors[s_idx]['bno']  = bno
            self.sectors[s_idx]['data'] = chunk.ljust(DATA_SIZE, b'\x00')

        # Ajouter l'entrée dans le répertoire (slot fno)
        self._dir_entries.append(file_hdr)

        # Allouer les secteurs de répertoire manquants (slot 0 = en-tête)
        needed_dir_sectors = (1 + len(self._dir_entries) + 7) // 8
        while self._dir_blocks < needed_dir_sectors:
            s_idx = self._alloc_sector()
            self.sectors[s_idx]['fno'] = FNO_DIR
            self.sectors[s_idx]['bno'] = self._dir_blocks
            self._dir_blocks += 1

    # --- Finalisation et écriture ---

    def _finalize(self) -> None:
        """Met à jour les données de tous les secteurs avant l'écriture."""
        # Secteurs de répertoire
        for s in range(NSECTORS):
            if self.sectors[s]['fno'] == FNO_DIR:
                self.sectors[s]['data'] = self._build_dir_data(self.sectors[s]['bno'])

        # Sector map (secteur 0), après la mise à jour des autres secteurs
        self.sectors[0]['data'] = self._build_map_data()
        self.sectors[0]['fno']  = FNO_MAP
        self.sectors[0]['bno']  = 0

    def tobytes(self) -> bytes:
        """Retourne les 174930 bytes de l'image."""
        self._finalize()
        out = bytearray()
        for s_idx in range(NSECTORS):
            sec = self.sectors[s_idx]
            out += build_sector(
                sflag = sec['sflag'],
                sno   = s_idx,
                name  = self.name,
                rand  = self.rand,
                fno   = sec['fno'],
                bno   = sec['bno'],
                data  = sec['data'],
            )
        assert len(out) == MDV_SIZE
        return bytes(out)

    def write(self, filepath: str) -> None:
        """Écrit l'image MDV dans un fichier."""
        with open(filepath, 'wb') as f:
            f.write(self.tobytes())

    def info(self) -> None:
        """Affiche des informations sur l'image."""
        used = sum(1 for s in self.sectors
                   if s['fno'] not in (FNO_VAC, FNO_MAP))
        free = NSECTORS - used - 1  # -1 pour le map
        print(f"Cartouche : {self.label!r}")
        print(f"Rand      : 0x{self.rand:04X}")
        print(f"Secteurs  : {NSECTORS} total, {used} utilisés, {free} libres")
        print(f"Répertoire: {len(self._dir_entries)} fichier(s), "
              f"{self._dir_blocks} secteur(s) dir")
        if self._dir_entries:
            print("Fichiers  :")
            for entry in self._dir_entries:
                h = parse_file_header(entry)
                type_str = 'exec' if h['type'] == 1 else 'data'
                ds_str   = f", ds={h['dataspace']}" if h['type'] == 1 else ''
                print(f"  {h['name']:<36} {h['data_size']:6d} bytes  [{type_str}{ds_str}]")


# ---------------------------------------------------------------------------
# Lecture : parsing d'une image MDV existante
# ---------------------------------------------------------------------------

class MDVReader:
    """
    Lit une image QLAY MDV existante : label, sector map, répertoire, fichiers.

    Les secteurs sans sync 0xFF/0xFF aux offsets [10..11] sont considérés
    non formatés (une image entièrement à zéro = cartouche vierge).
    Le contenu est reconstruit depuis les block headers (fno/bno), pas
    depuis le sector map — ce qui tolère les images au block checksum
    périmé (cas CHESS.MDV) tout en le signalant.
    """

    def __init__(self, image: bytes):
        if len(image) != MDV_SIZE:
            raise ValueError(f"Taille d'image invalide : {len(image)} "
                             f"(attendu {MDV_SIZE})")
        self.sectors = []       # secteurs formatés uniquement
        self.n_unformatted = 0
        self.label = None
        self.rand  = None
        self.checksum_errors = 0

        for s in range(NSECTORS):
            raw = image[s*SECTOR_LEN:(s+1)*SECTOR_LEN]
            if raw[10:12] != b'\xFF\xFF':
                self.n_unformatted += 1
                continue
            hdr_csum = struct.unpack('<H', raw[26:28])[0]
            blk_csum = struct.unpack('<H', raw[42:44])[0]
            dat_csum = struct.unpack('<H', raw[564:566])[0]
            sec = {
                'slot':   s,
                'sflag':  raw[12],
                'sno':    raw[13],
                'name':   raw[14:24],
                'rand':   struct.unpack('<H', raw[24:26])[0],
                'fno':    raw[40],
                'bno':    raw[41],
                'data':   raw[52:564],
                'hdr_ok': hdr_csum == qdos_checksum(raw[12:26]),
                'blk_ok': blk_csum == qdos_checksum(raw[40:42]),
                'dat_ok': dat_csum == qdos_checksum(raw[52:564]),
            }
            self.checksum_errors += (not sec['hdr_ok']) + \
                                    (not sec['blk_ok']) + (not sec['dat_ok'])
            self.sectors.append(sec)
            if self.label is None and sec['hdr_ok']:
                self.label = sec['name'].decode('ascii', errors='replace').rstrip()
                self.rand  = sec['rand']

    @classmethod
    def from_file(cls, filepath: str) -> 'MDVReader':
        with open(filepath, 'rb') as f:
            return cls(f.read())

    def _map_data(self) -> bytes:
        """Données du sector map (fno=0x80 dans le block header), ou None."""
        for s in self.sectors:
            if s['fno'] == FNO_MAP:
                return s['data']
        return None

    def _file_sectors(self, fno: int) -> list:
        """
        Secteurs du fichier fno, triés par bno. Résolus via le sector map
        quand il existe : après une réécriture de fichier, l'ancien secteur
        est re-marqué vacant dans le map mais son block header périmé reste
        sur bande (cas observé dans CHESS.MDV — deux blocs fno=2/bno=0,
        seul celui pointé par le map est valide).
        """
        mapdata = self._map_data() if fno != FNO_MAP else None
        if mapdata is not None:
            by_sno = {s['sno']: s for s in self.sectors}
            out = []
            for sno in range(NSECTORS):
                if mapdata[2*sno] == fno and sno in by_sno:
                    out.append((mapdata[2*sno+1], by_sno[sno]))
            return [sec for _, sec in sorted(out, key=lambda t: t[0])]
        return sorted((s for s in self.sectors if s['fno'] == fno),
                      key=lambda s: s['bno'])

    def directory(self) -> list:
        """
        Retourne la liste des entrées de répertoire présentes :
        [(fno, header_dict), ...] triée par fno. Les slots vides
        (fichier jamais créé ou supprimé, entrée à zéro) sont ignorés.
        """
        dir_data = b''.join(s['data'] for s in self._file_sectors(FNO_DIR))
        if not dir_data:
            return []
        dir_length = struct.unpack('>I', dir_data[0:4])[0]
        dir_length = min(dir_length, len(dir_data))
        entries = []
        for off in range(FILE_HDR, dir_length, FILE_HDR):
            entry = dir_data[off:off+FILE_HDR]
            if len(entry) < FILE_HDR or entry == b'\x00' * FILE_HDR:
                continue
            h = parse_file_header(entry)
            if h['length'] < FILE_HDR:
                continue
            entries.append((off // FILE_HDR, h))
        return entries

    def read_file(self, fno: int, with_header: bool = False) -> bytes:
        """
        Reconstruit le contenu du fichier fno depuis ses blocs.
        La longueur vient de l'en-tête QDOS du bloc 0 ; par défaut
        l'en-tête de 64 bytes est retiré.
        """
        secs = self._file_sectors(fno)
        if not secs:
            raise KeyError(f"Aucun secteur pour fno={fno}")
        expected = list(range(len(secs)))
        got = [s['bno'] for s in secs]
        if got != expected:
            raise ValueError(f"Blocs manquants ou dupliqués pour fno={fno} : "
                             f"bno={got}")
        payload = b''.join(s['data'] for s in secs)
        h = parse_file_header(payload[0:FILE_HDR])
        payload = payload[:h['length']]
        return payload if with_header else payload[FILE_HDR:]

    def map_stats(self) -> dict:
        """Statistiques depuis le sector map (secteur fno=0x80), ou None."""
        map_secs = self._file_sectors(FNO_MAP)
        if not map_secs:
            return None
        data = map_secs[0]['data']
        stats = {'vacant': 0, 'nonavail': 0, 'map': 0, 'used': 0}
        for s in range(NSECTORS):
            f = data[2*s]
            if f == MAP_VACANT:
                stats['vacant'] += 1
            elif f == MAP_NONAVAIL:
                stats['nonavail'] += 1
            elif f == MAP_SELF:
                stats['map'] += 1
            else:
                stats['used'] += 1
        return stats


# ---------------------------------------------------------------------------
# Sous-commandes
# ---------------------------------------------------------------------------

def cmd_create(args) -> int:
    img = MDVImage(label=args.label, rand=args.rand)

    for filespec in args.file:
        # Décoder HOSTPATH[:QDOSNAME]
        if ':' in filespec:
            host_path, qdos_name = filespec.rsplit(':', 1)
        else:
            host_path = filespec
            qdos_name = os.path.basename(host_path)

        if not os.path.isfile(host_path):
            print(f"Erreur : fichier introuvable : {host_path}", file=sys.stderr)
            return 1

        with open(host_path, 'rb') as f:
            raw_data = f.read()

        mtime = int(os.path.getmtime(host_path))

        # Détecter si c'est un exécutable XTC68 (marqueur XTcc en fin de fichier)
        is_exec = False
        dataspace = 0
        file_data = raw_data

        if not args.data and len(raw_data) >= 8:
            if raw_data[-8:-4] == b'XTcc':
                # Binaire produit par qld (XTC68) : dataspace dans les 4 derniers
                # octets, précédés du marqueur "XTcc". On retire ces 8 octets du
                # code stocké dans le MDV (marqueur hôte uniquement).
                is_exec = True
                dataspace = struct.unpack('>I', raw_data[-4:])[0]
                file_data = raw_data[:-8]
                if not args.quiet:
                    print(f"  {host_path} : XTcc détecté, dataspace={dataspace}")

        try:
            img.add_file(qdos_name, file_data,
                         is_exec=is_exec,
                         dataspace=dataspace,
                         mtime=mtime)
            if not args.quiet:
                print(f"  Ajouté : {qdos_name} ({len(file_data)} bytes)")
        except (ValueError, RuntimeError) as e:
            print(f"Erreur lors de l'ajout de {qdos_name}: {e}", file=sys.stderr)
            return 1

    try:
        img.write(args.output)
    except Exception as e:
        print(f"Erreur d'écriture: {e}", file=sys.stderr)
        return 1

    if not args.quiet:
        print()
        img.info()
        print(f"\nImage écrite : {args.output} ({MDV_SIZE} bytes)")
    return 0


def _format_mtime(mtime: int) -> str:
    if not mtime:
        return '-'
    return time.strftime('%Y-%m-%d %H:%M', time.localtime(mtime))


def cmd_list(args) -> int:
    try:
        rd = MDVReader.from_file(args.image)
    except (OSError, ValueError) as e:
        print(f"Erreur : {e}", file=sys.stderr)
        return 1

    if not rd.sectors:
        print(f"{args.image} : cartouche vierge (non formatée)")
        return 0

    print(f"Cartouche : {rd.label!r}  (rand 0x{rd.rand:04X})")
    line = f"Secteurs  : {len(rd.sectors)} formatés, {rd.n_unformatted} non formatés"
    stats = rd.map_stats()
    if stats:
        line += (f" — map : {stats['used']} utilisés, {stats['vacant']} vacants, "
                 f"{stats['nonavail']} indisponibles")
    print(line)
    if rd.checksum_errors:
        print(f"ATTENTION : {rd.checksum_errors} checksum(s) invalide(s) "
              f"(image réparable avec tools/mdv_fix_checksums.py)")

    entries = rd.directory()
    if not entries:
        print("Fichiers  : (aucun)")
        return 0
    print(f"Fichiers  : {len(entries)}")
    print(f"  {'fno':>3}  {'nom':<36} {'bytes':>7}  type  {'ds':>6}  màj")
    for fno, h in entries:
        type_str = 'exec' if h['type'] == 1 else 'data'
        ds_str = str(h['dataspace']) if h['type'] == 1 else '-'
        print(f"  {fno:>3}  {h['name']:<36} {h['data_size']:>7}  {type_str}  "
              f"{ds_str:>6}  {_format_mtime(h['mtime'])}")
    return 0


def _host_filename(qdos_name: str) -> str:
    """Nom de fichier hôte sûr à partir d'un nom QDOS."""
    return ''.join(c if (c.isalnum() or c in '._-') else '_'
                   for c in qdos_name) or 'unnamed'


def cmd_extract(args) -> int:
    try:
        rd = MDVReader.from_file(args.image)
    except (OSError, ValueError) as e:
        print(f"Erreur : {e}", file=sys.stderr)
        return 1

    entries = rd.directory()
    if args.names:
        wanted = set(args.names)
        entries = [(fno, h) for fno, h in entries if h['name'] in wanted]
        missing = wanted - {h['name'] for _, h in entries}
        if missing:
            print(f"Erreur : fichier(s) introuvable(s) : {', '.join(sorted(missing))}",
                  file=sys.stderr)
            return 1
    if not entries:
        print("Aucun fichier à extraire", file=sys.stderr)
        return 1

    os.makedirs(args.output_dir, exist_ok=True)
    status = 0
    for fno, h in entries:
        try:
            data = rd.read_file(fno, with_header=args.with_header)
        except (KeyError, ValueError) as e:
            print(f"Erreur : {h['name']} : {e}", file=sys.stderr)
            status = 1
            continue
        if args.xtcc and not args.with_header and h['type'] == 1:
            # Trailer XTcc : permet de ré-importer l'exécutable avec sa
            # dataspace via la sous-commande create
            data += b'XTcc' + struct.pack('>I', h['dataspace'])
        out_path = os.path.join(args.output_dir, _host_filename(h['name']))
        with open(out_path, 'wb') as f:
            f.write(data)
        if h['mtime']:
            os.utime(out_path, (h['mtime'], h['mtime']))
        if not args.quiet:
            print(f"  Extrait : {h['name']} -> {out_path} ({len(data)} bytes)")
    return status


# ---------------------------------------------------------------------------
# Tests unitaires (sous-commande "test")
# ---------------------------------------------------------------------------

class TestChecksum(unittest.TestCase):
    def test_empty(self):
        self.assertEqual(qdos_checksum(b''), 0x0F0F)

    def test_vacant_block_header(self):
        # (0xFD, 0x00) -> 0x0F0F + 0xFD = 0x100C : le fameux checksum "vacant"
        self.assertEqual(qdos_checksum(bytes([0xFD, 0x00])), 0x100C)

    def test_truncation(self):
        self.assertEqual(qdos_checksum(b'\xff' * 0x1000), (0x0F0F + 0xFF * 0x1000) & 0xFFFF)


class TestSectorLayout(unittest.TestCase):
    def test_map_block_header_is_0x80(self):
        img = MDVImage(label='TEST', rand=0x1234)
        raw = img.tobytes()
        # Block header du secteur 0 : fno=0x80, bno=0
        self.assertEqual(raw[40], 0x80)
        self.assertEqual(raw[41], 0x00)
        # Checksum du block header cohérent
        self.assertEqual(struct.unpack('<H', raw[42:44])[0],
                         qdos_checksum(raw[40:42]))

    def test_map_self_entry_is_0xf8(self):
        # Dans les DONNÉES du map, le map lui-même est encodé 0xF8 (pas 0x80)
        img = MDVImage(label='TEST', rand=0x1234)
        raw = img.tobytes()
        map_data = raw[52:564]
        self.assertEqual(map_data[0], 0xF8)
        self.assertEqual(map_data[1], 0x00)

    def test_map_entries(self):
        img = MDVImage(label='TEST', rand=0x1234)
        img.add_file('afile', b'x' * 600)     # fno=1, 2 blocs (secteurs 2 et 3)
        raw = img.tobytes()
        map_data = raw[52:564]
        self.assertEqual((map_data[2], map_data[3]), (FNO_DIR, 0))   # secteur 1
        self.assertEqual((map_data[4], map_data[5]), (1, 0))         # fno=1 bno=0
        self.assertEqual((map_data[6], map_data[7]), (1, 1))         # fno=1 bno=1
        self.assertEqual((map_data[8], map_data[9]), (MAP_VACANT, 0))
        self.assertEqual((map_data[2*254], map_data[2*254+1]), (MAP_NONAVAIL, 0))

    def test_all_checksums_valid(self):
        img = MDVImage(label='TEST', rand=0x1234)
        img.add_file('afile', b'hello')
        rd = MDVReader(img.tobytes())
        self.assertEqual(rd.checksum_errors, 0)
        self.assertEqual(len(rd.sectors), NSECTORS)


class TestDirectoryLayout(unittest.TestCase):
    def test_slot0_is_dir_header(self):
        # Le slot 0 du répertoire est l'en-tête du répertoire : longueur
        # totale en big-endian dans les 4 premiers bytes, PAS une entrée
        # de fichier (confirmé par un SAVE réel sous Minerva).
        img = MDVImage(label='TEST', rand=0x1234)
        img.add_file('prog', b'10 PRINT "hello"\n')
        raw = img.tobytes()
        dir_data = raw[SECTOR_LEN + 52 : SECTOR_LEN + 564]  # secteur 1
        self.assertEqual(struct.unpack('>I', dir_data[0:4])[0], 2 * FILE_HDR)
        self.assertEqual(dir_data[4:FILE_HDR], b'\x00' * (FILE_HDR - 4))

    def test_entry_for_fno_k_at_offset_64k(self):
        img = MDVImage(label='TEST', rand=0x1234)
        img.add_file('first', b'aaa')
        img.add_file('second', b'bbbb')
        raw = img.tobytes()
        dir_data = raw[SECTOR_LEN + 52 : SECTOR_LEN + 564]
        e1 = parse_file_header(dir_data[FILE_HDR:2*FILE_HDR])
        e2 = parse_file_header(dir_data[2*FILE_HDR:3*FILE_HDR])
        self.assertEqual(e1['name'], 'first')
        self.assertEqual(e1['data_size'], 3)
        self.assertEqual(e2['name'], 'second')
        self.assertEqual(e2['data_size'], 4)
        self.assertEqual(struct.unpack('>I', dir_data[0:4])[0], 3 * FILE_HDR)

    def test_dir_grows_past_8_slots(self):
        # 8 fichiers + slot d'en-tête = 9 slots -> 2 secteurs de répertoire
        img = MDVImage(label='TEST', rand=0x1234)
        for i in range(8):
            img.add_file(f'file{i}', bytes([i]) * 10)
        rd = MDVReader(img.tobytes())
        dir_secs = rd._file_sectors(FNO_DIR)
        self.assertEqual([s['bno'] for s in dir_secs], [0, 1])
        entries = rd.directory()
        self.assertEqual([h['name'] for _, h in entries],
                         [f'file{i}' for i in range(8)])


class TestReaderRoundTrip(unittest.TestCase):
    def _image(self):
        img = MDVImage(label='RTRIP', rand=0xBEEF)
        self.data1 = bytes(range(256)) * 5              # 1280 bytes, 3 blocs
        self.data2 = b'10 PRINT "hello"\n'
        img.add_file('bigfile', self.data1, mtime=1000000000)
        img.add_file('prog', self.data2, is_exec=True, dataspace=4096)
        return img.tobytes()

    def test_label_and_rand(self):
        rd = MDVReader(self._image())
        self.assertEqual(rd.label, 'RTRIP')
        self.assertEqual(rd.rand, 0xBEEF)

    def test_directory_listing(self):
        rd = MDVReader(self._image())
        entries = rd.directory()
        self.assertEqual(len(entries), 2)
        (fno1, h1), (fno2, h2) = entries
        self.assertEqual((fno1, h1['name'], h1['data_size'], h1['type']),
                         (1, 'bigfile', len(self.data1), 0))
        self.assertEqual(h1['mtime'], 1000000000)
        self.assertEqual((fno2, h2['name'], h2['data_size'], h2['type']),
                         (2, 'prog', len(self.data2), 1))
        self.assertEqual(h2['dataspace'], 4096)

    def test_extract_data(self):
        rd = MDVReader(self._image())
        self.assertEqual(rd.read_file(1), self.data1)
        self.assertEqual(rd.read_file(2), self.data2)

    def test_extract_with_header(self):
        rd = MDVReader(self._image())
        full = rd.read_file(2, with_header=True)
        self.assertEqual(len(full), FILE_HDR + len(self.data2))
        h = parse_file_header(full[:FILE_HDR])
        self.assertEqual(h['name'], 'prog')
        self.assertEqual(full[FILE_HDR:], self.data2)

    def test_missing_block_detected(self):
        raw = bytearray(self._image())
        # Corrompre le sync du secteur 3 (2e bloc de bigfile) -> non formaté
        base = 3 * SECTOR_LEN
        raw[base+10:base+12] = b'\x00\x00'
        rd = MDVReader(bytes(raw))
        with self.assertRaises(ValueError):
            rd.read_file(1)

    def test_stale_duplicate_resolved_by_map(self):
        # Un block header périmé (fno=1/bno=0 sur un secteur marqué vacant
        # dans le map) ne doit pas polluer la reconstruction — cas CHESS.MDV
        raw = bytearray(self._image())
        base = 10 * SECTOR_LEN  # secteur vacant, sno=10
        raw[base+40], raw[base+41] = 1, 0
        struct.pack_into('<H', raw, base+42, qdos_checksum(bytes([1, 0])))
        rd = MDVReader(bytes(raw))
        self.assertEqual(rd.read_file(1), self.data1)

    def test_map_stats(self):
        rd = MDVReader(self._image())
        stats = rd.map_stats()
        # bigfile 3 blocs + prog 1 bloc + 1 secteur dir = 5 utilisés
        self.assertEqual(stats['used'], 5)
        self.assertEqual(stats['map'], 1)
        self.assertEqual(stats['nonavail'], 1)
        self.assertEqual(stats['vacant'], NSECTORS - 5 - 1 - 1)


class TestBlankImage(unittest.TestCase):
    def test_all_zero_image_is_unformatted(self):
        rd = MDVReader(bytes(MDV_SIZE))
        self.assertEqual(len(rd.sectors), 0)
        self.assertEqual(rd.n_unformatted, NSECTORS)
        self.assertEqual(rd.directory(), [])
        self.assertIsNone(rd.map_stats())

    def test_bad_size_rejected(self):
        with self.assertRaises(ValueError):
            MDVReader(bytes(MDV_SIZE - 1))


class TestCLI(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def _path(self, name):
        return os.path.join(self.dir, name)

    def test_create_list_extract(self):
        # create
        src = self._path('hello_txt')
        content = b'Hello, QL!'
        with open(src, 'wb') as f:
            f.write(content)
        mdv = self._path('test.mdv')
        rc = main(['create', '--label', 'CLI', '--rand', '0x42',
                   '--output', mdv, '--file', f'{src}:hello', '--quiet'])
        self.assertEqual(rc, 0)
        self.assertEqual(os.path.getsize(mdv), MDV_SIZE)

        # list
        rc = main(['list', mdv])
        self.assertEqual(rc, 0)

        # extract
        outdir = self._path('out')
        rc = main(['extract', mdv, '--output-dir', outdir, '--quiet'])
        self.assertEqual(rc, 0)
        with open(os.path.join(outdir, 'hello'), 'rb') as f:
            self.assertEqual(f.read(), content)

    def test_extract_xtcc_roundtrip(self):
        # Un exécutable XTcc importé puis extrait avec --xtcc est identique
        src = self._path('binary')
        payload = b'\x4e\x75' * 100  # RTS x100
        with open(src, 'wb') as f:
            f.write(payload + b'XTcc' + struct.pack('>I', 8192))
        mdv = self._path('test.mdv')
        self.assertEqual(main(['create', '-o', mdv, '-f', src, '--quiet']), 0)

        outdir = self._path('out')
        self.assertEqual(main(['extract', mdv, '--xtcc',
                               '--output-dir', outdir, '--quiet']), 0)
        with open(os.path.join(outdir, 'binary'), 'rb') as f:
            self.assertEqual(f.read(), payload + b'XTcc' + struct.pack('>I', 8192))

    def test_extract_by_name_missing(self):
        mdv = self._path('empty.mdv')
        self.assertEqual(main(['create', '-o', mdv, '--quiet']), 0)
        rc = main(['extract', mdv, 'nosuchfile',
                   '--output-dir', self._path('out'), '--quiet'])
        self.assertEqual(rc, 1)


def cmd_test(args) -> int:
    argv = [sys.argv[0]]
    if args.verbose:
        argv.append('-v')
    unittest.main(module=sys.modules[__name__], argv=argv, exit=False)
    return 0


# ---------------------------------------------------------------------------
# Interface ligne de commande
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description='Outil d\'images Microdrive QLAY pour Sinclair QL '
                    '(MAME, QLAY, vDriveQL)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples :
  # Créer une image vierge (formatée, sans fichier)
  %(prog)s create --label RPUFOS --output ma_cartouche.mdv

  # Créer une image avec un exécutable QDOS (dataspace lue depuis XTcc)
  %(prog)s create --label RPUFOS --output boot.mdv --file build/bonjour_qdos

  # Renommer côté QDOS / forcer le type data
  %(prog)s create -o boot.mdv --file build/bonjour_qdos:BONJOUR
  %(prog)s create -o boot.mdv --file mondata.txt:MYDATA --data

  # Lister le contenu d'une image
  %(prog)s list ma_cartouche.mdv

  # Extraire tous les fichiers / certains fichiers
  %(prog)s extract ma_cartouche.mdv --output-dir dump/
  %(prog)s extract ma_cartouche.mdv BONJOUR MYDATA -O dump/

  # Lancer les tests unitaires
  %(prog)s test -v
""")
    sub = parser.add_subparsers(dest='command', required=True)

    # --- create ---
    p = sub.add_parser('create', help='Crée une image MDV')
    p.add_argument('--label', '-l', default='MDVIMAGE',
                   help='Label de la cartouche (max 10 chars, défaut: MDVIMAGE)')
    p.add_argument('--output', '-o', required=True,
                   help='Fichier de sortie (.mdv)')
    p.add_argument('--rand', '-r', type=lambda x: int(x, 0), default=None,
                   help='Valeur rand 16 bits (défaut: aléatoire)')
    p.add_argument('--file', '-f', action='append', default=[],
                   metavar='HOSTPATH[:QDOSNAME]',
                   help='Fichier à inclure (peut être répété). '
                        'Le format HOSTPATH:QDOSNAME permet de renommer.')
    p.add_argument('--data', '-d', action='store_true',
                   help='Forcer le type "data" (non exécutable) pour tous les fichiers')
    p.add_argument('--quiet', '-q', action='store_true', help='Mode silencieux')
    p.set_defaults(func=cmd_create)

    # --- list ---
    p = sub.add_parser('list', help='Liste le contenu d\'une image MDV')
    p.add_argument('image', help='Image .mdv à lire')
    p.set_defaults(func=cmd_list)

    # --- extract ---
    p = sub.add_parser('extract', help='Extrait des fichiers d\'une image MDV')
    p.add_argument('image', help='Image .mdv à lire')
    p.add_argument('names', nargs='*',
                   help='Noms QDOS à extraire (défaut : tous)')
    p.add_argument('--output-dir', '-O', default='.',
                   help='Répertoire de sortie (défaut : répertoire courant)')
    p.add_argument('--with-header', action='store_true',
                   help='Conserver l\'en-tête QDOS de 64 bytes')
    p.add_argument('--xtcc', action='store_true',
                   help='Ajouter le trailer XTcc (dataspace) aux exécutables, '
                        'pour ré-import via create')
    p.add_argument('--quiet', '-q', action='store_true', help='Mode silencieux')
    p.set_defaults(func=cmd_extract)

    # --- test ---
    p = sub.add_parser('test', help='Lance les tests unitaires embarqués')
    p.add_argument('--verbose', '-v', action='store_true')
    p.set_defaults(func=cmd_test)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == '__main__':
    sys.exit(main())
