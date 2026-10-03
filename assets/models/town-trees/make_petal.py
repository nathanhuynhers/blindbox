"""Write sakura_petal.png: the falling-petal particle texture (128 px, soft pink, transparent).

Standard library only. Run from the repository root:
  python assets/models/town-trees/make_petal.py
"""

import math
import struct
import zlib
from pathlib import Path

SIZE = 128
OUT = Path(__file__).with_name("sakura_petal.png")


def petal_alpha(x, y):
    """Signed coverage of a rounded petal with a notch at its tip (0 = outside, 1 = inside)."""
    u = (x - SIZE / 2) / (SIZE * 0.36)
    v = (y - SIZE * 0.56) / (SIZE * 0.44)
    # Teardrop body: wider near the tip (top), tapering to the base (bottom).
    width = 0.62 + 0.38 * max(0.0, min(1.0, 1.0 - (v + 1.0) / 2.0)) ** 0.7
    body = (u / width) ** 2 + v**2
    notch = math.hypot(u, (v + 1.02) * 1.6) < 0.32
    edge = 1.0 - body
    if notch or edge <= 0.0:
        return 0.0
    return max(0.0, min(1.0, edge * 6.0))


def pixel(x, y):
    a = petal_alpha(x + 0.5, y + 0.5)
    if a == 0.0:
        return (0, 0, 0, 0)
    # White-pink centre warming to a deeper pink rim, like the sakura's coral flecks.
    rim = 1.0 - min(1.0, a)
    t = (y / SIZE) * 0.5 + rim * 0.5
    r = int(255 - 12 * t)
    g = int(232 - 70 * t)
    b = int(240 - 52 * t)
    return (r, g, b, int(255 * a))


def write_png(path):
    rows = []
    for y in range(SIZE):
        row = bytearray([0])
        for x in range(SIZE):
            row.extend(pixel(x, y))
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


if __name__ == "__main__":
    write_png(OUT)
    print(OUT, OUT.stat().st_size, "bytes")
