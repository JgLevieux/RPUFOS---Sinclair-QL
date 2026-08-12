import os
from PIL import Image

# Configuration
NUM_FRAMES = 16
CHAR_WIDTH = 4
CHAR_HEIGHT = 8

# Paramètres de la grille
OFFSET_X = 1       # Le premier pixel de la lettre A est à x=1
OFFSET_Y = 10      # Le premier pixel du haut de la lettre A est à y=10
CELL_WIDTH = 5     # 4 pixels de lettre + 1 pixel de séparation
NUM_LETTERS = 26   # De A à Z

# Paramètre de couleur
SEUIL_NOIR = 50    # Valeur RGB en dessous de laquelle le pixel d'origine est considéré comme du texte

# Options
CORRIGER_DECALAGE = True     # Resynchronise l'animation des lettres
TRANSFORMER_COULEURS = False  # Active la transformation des couleurs (blanc sur fond transparent)

frames = []
# Chargement et traitement des images sources
for i in range(NUM_FRAMES):
    filename = f"frame_{i:02d}_delay-0.06s.gif"
    if os.path.exists(filename):
        img = Image.open(filename).convert("RGBA")
        
        if TRANSFORMER_COULEURS:
            # Remplacement des couleurs et gestion de la transparence
            new_pixels = []
            for r, g, b, a in img.getdata():
                if r < SEUIL_NOIR and g < SEUIL_NOIR and b < SEUIL_NOIR:
                    # Le texte (proche du noir) -> Devient Blanc opaque
                    new_pixels.append((255, 255, 255, 255))
                else:
                    # Le reste (fond, gris) -> Devient Transparent (Alpha = 0)
                    new_pixels.append((0, 0, 0, 0))
            
            img.putdata(new_pixels)
            
        frames.append(img)
    else:
        print(f"Info: {filename} introuvable dans le dossier actuel.")

if not frames:
    print("Erreur: Aucune image source trouvée.")
    exit()

num_available_frames = len(frames)

for i in range(num_available_frames):
    # Image de sortie : 4 pixels de large, 208 pixels de haut (26 lettres * 8 pixels)
    out_img = Image.new("RGBA", (CHAR_WIDTH, NUM_LETTERS * CHAR_HEIGHT), (0, 0, 0, 0))
    
    for j in range(NUM_LETTERS):
        src_frame_idx = i
        
        if CORRIGER_DECALAGE and (j % 2 != 0):
            src_frame_idx = (i + (num_available_frames // 2)) % num_available_frames
        
        # Calcul de la position tenant compte des lignes de séparation
        src_x = OFFSET_X + (j * CELL_WIDTH)
        
        box = (src_x, OFFSET_Y, src_x + CHAR_WIDTH, OFFSET_Y + CHAR_HEIGHT)
        
        # Extraction de la lettre sans la bordure
        letter_img = frames[src_frame_idx].crop(box)
        
        # Collage dans l'image finale
        dest_y = j * CHAR_HEIGHT
        out_img.paste(letter_img, (0, dest_y))
        
    out_filename = f"output_anim_{i:02d}.png"
    out_img.save(out_filename, "PNG")
    print(f"Image générée : {out_filename}")