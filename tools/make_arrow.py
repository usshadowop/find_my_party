#!/usr/bin/env python3
"""Generate FindMyParty/Media/Arrow.tga.

The arrow is white with a black outline and points straight up, so the addon
can tint it to any color (SetVertexColor) and spin it (SetRotation). It stays
inside the texture's inscribed circle so no corner gets clipped when rotated.

Usage: python3 tools/make_arrow.py [output.tga] [preview.png]
"""
import math
import struct
import sys

SIZE = 128          # WoW textures must be a power of two
SAMPLES = 4         # supersampling per axis for smooth edges
OUTLINE = 6.0       # outline thickness in pixels

# Arrow outline, in pixels, centered on (0, 0) with +y pointing up.
TIP = (0.0, 54.0)
RIGHT = (36.0, -38.0)
NOTCH = (0.0, -16.0)
LEFT = (-36.0, -38.0)
POLY = [TIP, RIGHT, NOTCH, LEFT]


def inside(px, py, poly):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def seg_dist(px, py, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy)


def edge_dist(px, py, poly):
    return min(seg_dist(px, py, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))


def render():
    """Return rows top-to-bottom of (r, g, b, a) floats in 0..1."""
    rows = []
    half = SIZE / 2.0
    for row in range(SIZE):
        line = []
        for col in range(SIZE):
            r = g = b = a = 0.0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    x = col + (sx + 0.5) / SAMPLES - half
                    y = half - (row + (sy + 0.5) / SAMPLES)
                    if inside(x, y, POLY):
                        d = edge_dist(x, y, POLY)
                        if d < OUTLINE * 0.5:
                            shade = 0.0          # black outline (inner half)
                        else:
                            # left half full brightness, right half a bit darker,
                            # which gives the arrow a folded, 3D look
                            shade = 1.0 if x <= 0 else 0.72
                        r += shade
                        g += shade
                        b += shade
                        a += 1.0
                    elif edge_dist(x, y, POLY) < OUTLINE * 0.5:
                        a += 1.0                 # black outline (outer half)
            n = float(SAMPLES * SAMPLES)
            if a > 0:
                # colour is averaged over covered samples only (straight alpha)
                line.append((r / a, g / a, b / a, a / n))
            else:
                line.append((0.0, 0.0, 0.0, 0.0))
        rows.append(line)
    return rows


def write_tga(path, rows):
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0,      # no image id
        0,      # no colour map
        2,      # uncompressed true-colour
        0, 0, 0,
        0, 0,   # origin
        SIZE, SIZE,
        32,     # bits per pixel
        8,      # 8 alpha bits, bottom-left origin
    )
    out = bytearray(header)
    for line in reversed(rows):  # bottom-left origin: last row first
        for r, g, b, a in line:
            out += bytes((round(b * 255), round(g * 255), round(r * 255), round(a * 255)))
    with open(path, "wb") as fh:
        fh.write(out)


def write_preview(path, rows):
    from PIL import Image

    img = Image.new("RGBA", (SIZE, SIZE))
    img.putdata([
        (round(r * 255), round(g * 255), round(b * 255), round(a * 255))
        for line in rows for r, g, b, a in line
    ])
    img.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "FindMyParty/Media/Arrow.tga"
    pixels = render()
    write_tga(out, pixels)
    if len(sys.argv) > 2:
        write_preview(sys.argv[2], pixels)
    print("wrote", out)
