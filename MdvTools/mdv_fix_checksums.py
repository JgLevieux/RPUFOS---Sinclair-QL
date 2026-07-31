#!/usr/bin/env python3
"""Fix block-header checksums in a QLAY MDV image.

Some MDV images (e.g. CHESS.MDV) were built by tools that rewrote the
fno/bno of file sectors but left the old "vacant sector" checksum
(0x100c = qdos_checksum(0xfd, 0x00)) in the block header. The QL ROM
*does* enforce this checksum (Minerva md/read.asm, rblock/checksum), so
such images fail on real hardware and on faithful emulation with
"bad or changed medium".

Usage:
    python3 tools/mdv_fix_checksums.py INPUT.MDV OUTPUT.MDV
"""

import sys

SECTOR_COUNT = 255
SECTOR_LENGTH = 686
IMAGE_LENGTH = SECTOR_COUNT * SECTOR_LENGTH

OFF_FNO = 40        # block header: fno, bno
OFF_BLOCK_CSUM = 42 # block checksum, little-endian


def qdos_checksum(data):
    return (0x0F0F + sum(data)) & 0xFFFF


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)

    data = bytearray(open(sys.argv[1], "rb").read())
    if len(data) != IMAGE_LENGTH:
        sys.exit(f"error: expected {IMAGE_LENGTH} bytes, got {len(data)}")

    fixed = 0
    for s in range(SECTOR_COUNT):
        base = s * SECTOR_LENGTH
        fno, bno = data[base + OFF_FNO], data[base + OFF_FNO + 1]
        want = qdos_checksum((fno, bno))
        have = data[base + OFF_BLOCK_CSUM] | (data[base + OFF_BLOCK_CSUM + 1] << 8)
        if have != want:
            data[base + OFF_BLOCK_CSUM] = want & 0xFF
            data[base + OFF_BLOCK_CSUM + 1] = want >> 8
            print(f"sector {s:3d}: fno={fno:02x} bno={bno:02x} csum {have:04x} -> {want:04x}")
            fixed += 1

    open(sys.argv[2], "wb").write(data)
    print(f"{fixed} block checksum(s) fixed, written to {sys.argv[2]}")


if __name__ == "__main__":
    main()
