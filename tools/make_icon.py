#!/usr/bin/env python3
"""Generate FindMyParty/Media/MinimapIcon.tga: three yellow party-member silhouettes.

Used for the minimap button and the AddOns menu (the TOC's IconTexture).

Usage: python3 tools/make_icon.py [output.tga] [preview.png]
"""
import math
import struct
import sys

SIZE = 64        # WoW textures must be a power of two
SAMPLES = 4      # supersampling per axis for smooth edges
OUTLINE = 2.5    # black outline thickness, in pixels

FRONT = (1.00, 0.86, 0.10)   # bright yellow
BACK = (0.88, 0.66, 0.05)    # a darker yellow for the two behind
BOTTOM = 5.0                 # silhouettes are cut flat here (y up, pixels from the bottom)


def figure(cx, base, head_r, body_rx, body_ry, grow=0.0):
    """A head-and-shoulders silhouette; `grow` widens it (for the outline)."""
    head_y = base + body_ry + head_r + 3.0

    def inside(x, y):
        if y < BOTTOM - grow:
            return False
        if (x - cx) ** 2 + (y - head_y) ** 2 <= (head_r + grow) ** 2:
            return True
        if y >= base - grow:
            rx, ry = body_rx + grow, body_ry + grow
            return ((x - cx) / rx) ** 2 + ((y - base) / ry) ** 2 <= 1.0
        return False

    return inside


# back left, back right, then the front one drawn over them
FIGURES = [
    (BACK, 15.0, 9.0, 7.0, 12.5, 15.0),
    (BACK, 49.0, 9.0, 7.0, 12.5, 15.0),
    (FRONT, 32.0, 2.0, 9.0, 17.0, 20.0),
]


def render():
    rows = []
    for row in range(SIZE):
        line = []
        for col in range(SIZE):
            r = g = b = a = 0.0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    x = col + (sx + 0.5) / SAMPLES
                    y = SIZE - (row + (sy + 0.5) / SAMPLES)
                    color = None
                    for fill, cx, base, hr, rx, ry in FIGURES:  # later figures cover earlier ones
                        if figure(cx, base, hr, rx, ry)(x, y):
                            color = fill
                        elif figure(cx, base, hr, rx, ry, OUTLINE)(x, y):
                            color = (0.0, 0.0, 0.0)
                    if color:
                        r += color[0]
                        g += color[1]
                        b += color[2]
                        a += 1.0
            n = float(SAMPLES * SAMPLES)
            line.append((r / a, g / a, b / a, a / n) if a else (0.0, 0.0, 0.0, 0.0))
        rows.append(line)
    return rows


def write_tga(path, rows):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    out = bytearray(header)
    for line in reversed(rows):  # bottom-left origin
        for r, g, b, a in line:
            out += bytes((round(b * 255), round(g * 255), round(r * 255), round(a * 255)))
    with open(path, "wb") as fh:
        fh.write(out)


def write_preview(path, rows):
    from PIL import Image

    img = Image.new("RGBA", (SIZE, SIZE))
    img.putdata([(round(r * 255), round(g * 255), round(b * 255), round(a * 255))
                 for line in rows for r, g, b, a in line])
    img.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "FindMyParty/Media/MinimapIcon.tga"
    pixels = render()
    write_tga(out, pixels)
    if len(sys.argv) > 2:
        write_preview(sys.argv[2], pixels)
    print("wrote", out)
