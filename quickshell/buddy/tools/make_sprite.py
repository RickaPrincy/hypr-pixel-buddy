#!/usr/bin/env python3
"""Planche de sprites du compagnon : frames 24x32 assemblées à partir de pièces.
Sorties : assets/sprite.png, assets/props.png, Frames.js (nom -> index)."""
from PIL import Image
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
PAL = {
    'O': (26, 20, 32), 'd': (84, 50, 30), 'H': (122, 74, 42), 'h': (165, 105, 60),
    'S': (242, 196, 156), 's': (214, 160, 122), 'G': (20, 20, 24), 'E': (60, 115, 175), 'W': (235, 245, 255),
    'm': (176, 90, 74), 'r': (235, 120, 120), 'C': (78, 83, 96), 'c': (56, 60, 71), 'k': (98, 104, 118),
    'w': (230, 230, 235), 'P': (44, 58, 86), 'p': (32, 42, 64), 'B': (236, 236, 236), 'b': (190, 190, 196),
    'L': (58, 62, 78), 'l': (90, 96, 116), 'A': (96, 176, 255), 'M': (240, 240, 245), 'f': (120, 72, 50),
    'N': (60, 62, 72), 'n': (120, 124, 138), 'X': (6, 6, 8),
}
FW, FH, OX = 24, 32, 4

HEAD = [
    "....OOOOOOO.....",
    "..OOdHHHHHHOO...",
    ".OdHHHhhHHHHHO..",
    "OdHHHhhHHHHHHHO.",
    "OdHHHHHHHHHHHHHO",
    "OdHHdHHHHdHHHHHO",
    "OdHdSSdHHSSdHHdO",
    "OddSSSSSSSSSSHdO",
    "OdSGGGGGGGGGSSHO",
    "OdSGWEGSGWEGSSsO",
    ".OSGGGGSGGGGSSsO",
    ".OSSSSSSSSSSSssO",
    "..OSSSSSmmSSSsO.",
    "...OOSSSSSSSOO..",
    ".....OOsssOO....",
]
def head(kind="normal"):
    h = list(HEAD)
    if kind in ("blink", "sleep", "happy"):
        h[9] = "OdSGSSGSGSSGSSsO"
    if kind == "talk":
        h[12] = "..OSSSSSOOSSSsO."
    if kind == "angry":
        h[7] = "OddOOSSSSOOSSHdO"
        h[11] = ".OSrSSSSSSSrSssO"
        h[12] = "..OSSSSOOOOSSsO."
    if kind == "shout":
        h[7] = "OddOOSSSSOOSSHdO"
        h[11] = ".OSrSSSOOSSrSssO"
        h[12] = "..OSSSSOrrOSSsO."
        h[13] = "...OOSSSOOSSOO.."
    if kind == "sleep":
        h[12] = "..OSSSSSSmSSSsO."
    if kind == "happy":
        h[12] = "..OSSSmSSSmSSsO."
        h[13] = "...OOSSmmmSSOO.."
    if kind == "dizzy":
        h[9] = "OdSGEWEGEWEGSSsO"
        h[12] = "..OSSSSmSmSSSsO."
    return h

TORSO = [
    "...OccCCCCccO...",
    "..OcCCCCCCCCcO..",
    ".OcCCCwCCwCCCcO.",
    ".OcCCCwCCwCCCcO.",
    ".OcCCCCCCCCCCcO.",
    ".OcCkkkkkkkkCcO.",
    ".OcCCCCCCCCCCcO.",
    "..OccccccccccO..",
]
LEGS = {
    "together": ["...OPPPPPPPPO...", "....OPPPPPpO....", "....OPPOOPpO....", "....OPPOOPpO....",
                 "....OPPOOPpO....", "...OBBBOOBBbO...", "...OOOOOOOOOO..."],
    "apart": ["...OPPPPPPPPO...", "...OPPPOOPPpO...", "..OPPPO..OPPpO..", "..OPPO....OPpO..",
              ".OPPO......OPpO.", ".OBBBO....OBBbO.", ".OOOOO....OOOOO."],
    "lift": ["...OPPPPPPPPO...", "....OPPPPPpO....", "....OPPOOPpO....", "...OBBBOOPpO....",
             "...OOOOOOPpO....", "........OBBbO...", "........OOOOO..."],
    "dangle": ["...OPPPPPPPPO...", "....OPPOOPpO....", "....OPPOOPpO....", "....OPPOOPpO....",
               "....OPPOOPpO....", "....OBBOOBbO....", "....OOOOOOOO...."],
    "sit": ["..OPPPPPPPPPPO..", ".OPPPPPPPPPPPpO.", ".OBBOOOOOOOOBbO.", ".OOO........OOO."],
}

def blank():
    return Image.new("RGBA", (FW, FH), (0, 0, 0, 0))

def paste_rows(img, rows, ox, oy, mirror=False):
    for y, row in enumerate(rows):
        row = row[::-1] if mirror else row
        for x, ch in enumerate(row):
            if ch != '.' and 0 <= ox + x < FW and 0 <= oy + y < FH:
                img.putpixel((ox + x, oy + y), PAL[ch] + (255,))

def line(p0, p1):
    (x0, y0), (x1, y1) = p0, p1
    pts = []; dx, dy = abs(x1 - x0), -abs(y1 - y0); sx = 1 if x0 < x1 else -1; sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if (x0, y0) == (x1, y1): break
        e2 = 2 * err
        if e2 >= dy: err += dy; x0 += sx
        if e2 <= dx: err += dx; y0 += sy
    return pts

def draw_arm(img, path, by):
    """path : points (dans le repère du torse, y relatif au haut du torse) ; le dernier = main."""
    layer = blank()
    pts = []
    for a, b in zip(path, path[1:]):
        pts += line(a, b)
    for (x, y) in pts[:-1]:
        if 0 <= x < FW and 0 <= y + by < FH: layer.putpixel((x, y + by), PAL['c'] + (255,))
    hx, hy = pts[-1]
    if 0 <= hx < FW and 0 <= hy + by < FH: layer.putpixel((hx, hy + by), PAL['S'] + (255,))
    # contour automatique
    out = blank()
    for y in range(FH):
        for x in range(FW):
            if layer.getpixel((x, y))[3] == 0 and any(
                    0 <= x + dx < FW and 0 <= y + dy < FH and layer.getpixel((x + dx, y + dy))[3]
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), PAL['O'] + (255,))
    img.alpha_composite(out); img.alpha_composite(layer)

# Bras : (gauche, droite) ; y relatif au haut du torse
L0, R0 = (5, 1), (18, 1)
ARMS = {
    "down": ([L0, (5, 5)], [R0, (18, 5)]),
    "swingA": ([L0, (4, 5)], [R0, (18, 4)]),
    "swingB": ([L0, (5, 4)], [R0, (19, 5)]),
    "up": ([L0, (4, -5)], [R0, (19, -5)]),
    "upB": ([L0, (3, -4)], [R0, (20, -4)]),
    "hips": ([L0, (3, 3), (5, 5)], [R0, (20, 3), (18, 5)]),
    "head": ([L0, (3, -2), (4, -7)], [R0, (20, -2), (19, -7)]),
    "pushR": ([(6, 3), (21, 3)], [R0, (22, 2)]),
    "type": ([L0, (6, 5), (8, 6)], [R0, (17, 5), (15, 6)]),
    "mugLow": ([L0, (5, 5)], [R0, (19, 4), (16, 4)]),
    "mugHigh": ([L0, (5, 5)], [R0, (19, 2), (16, -2)]),
    "waveA": ([L0, (5, 5)], [R0, (20, -2), (21, -5)]),
    "waveB": ([L0, (5, 5)], [R0, (20, -2), (19, -6)]),
    "aim": ([L0, (8, 4), (10, 5)], [R0, (15, 4), (13, 5)]),
    "reins": ([L0, (7, 4), (10, 4)], [R0, (16, 4), (13, 4)]),
    "armsOut": ([L0, (1, 1), (0, 1)], [R0, (22, 1), (23, 1)]),
    "flossL": ([L0, (2, 5)], [R0, (14, 5), (12, 6)]),
    "dabL": ([L0, (2, -2), (0, -4)], [R0, (20, 0), (15, -3)]),
    "auraL": ([L0, (1, 0), (0, -1)], [R0, (18, 5)]),
    "vampA": ([L0, (3, -2), (5, -5)], [R0, (20, 3), (21, 5)]),
    "vampC": ([L0, (2, 4), (1, 6)], [R0, (21, 4), (22, 6)]),
    "none": None,
}

def frame(h="normal", legs="together", arms="down", dy=0, hdy=0, mirror_legs=False, laptop=False, mug=None, gun=False):
    img = blank()
    sit = legs == "sit"
    by = (3 if sit else 0) + dy + 1
    paste_rows(img, LEGS[legs], OX, by + 15 + 8, mirror=mirror_legs)
    paste_rows(img, TORSO, OX, by + 15)
    paste_rows(img, head(h), OX, by + hdy)
    if ARMS[arms]:
        for p in ARMS[arms]:
            draw_arm(img, p, by + 15)
    if laptop:  # dos de l'écran du laptop (logo bleu)
        top = by + 15 + 4
        for y in range(top, top + 8):
            for x in range(6, 18):
                c = 'O' if (x in (6, 17) or y in (top, top + 7)) else ('l' if y == top + 1 else 'L')
                img.putpixel((x, y), PAL[c] + (255,))
        for (x, y) in ((11, 3), (12, 3), (11, 4), (12, 4), (10, 5), (13, 5)):
            img.putpixel((x, top + y - 1), PAL['A'] + (255,))
    if gun:  # pistolet pointé vers l'écran (vers toi)
        gy = by + 15 + 3
        for y in range(gy, gy + 5):
            for x in range(9, 15):
                c = 'O' if x in (9, 14) or y in (gy, gy + 4) else ('n' if y == gy + 1 else 'N')
                img.putpixel((x, y), PAL[c] + (255,))
        for (x, y) in ((11, 2), (12, 2), (11, 3), (12, 3)):
            img.putpixel((x, gy + y - 1), PAL['X'] + (255,))
        img.putpixel((9, gy + 2), PAL['S'] + (255,)); img.putpixel((14, gy + 2), PAL['S'] + (255,))
    if mug:
        mx, my = (14, by + 15 + 2) if mug == "low" else (14, by + 9)
        for y in range(4):
            for x in range(4):
                img.putpixel((mx + x, my + y), PAL['O' if x in (0, 3) or y == 3 else ('f' if y == 0 else 'M')] + (255,))
        img.putpixel((mx - 1, my + 1), PAL['O'] + (255,))
    return img

FRAMES = [
    ("walk0", dict(legs="apart", arms="swingA", dy=1)),
    ("walk1", dict(legs="lift", arms="down")),
    ("walk2", dict(legs="apart", arms="swingB", dy=1, mirror_legs=True)),
    ("walk3", dict(legs="lift", arms="down", mirror_legs=True)),
    ("idle", dict()),
    ("blink", dict(h="blink")),
    ("talk", dict(h="talk")),
    ("angry", dict(h="angry", arms="hips")),
    ("shout", dict(h="shout", arms="hips", dy=-1)),
    ("dangle0", dict(h="shout", legs="dangle", arms="up")),
    ("dangle1", dict(h="talk", legs="dangle", arms="upB")),
    ("fall", dict(h="shout", legs="apart", arms="upB")),
    ("land", dict(h="dizzy", legs="apart", arms="down", dy=1)),
    ("dizzy", dict(h="dizzy")),
    ("sit", dict(legs="sit")),
    ("sitBlink", dict(h="blink", legs="sit")),
    ("type0", dict(legs="sit", arms="type", laptop=True)),
    ("type1", dict(legs="sit", arms="type", laptop=True, hdy=1)),
    ("typeBlink", dict(h="blink", legs="sit", arms="type", laptop=True)),
    ("mugLow", dict(legs="sit", arms="mugLow", mug="low")),
    ("mugHigh", dict(h="blink", legs="sit", arms="mugHigh", mug="high")),
    ("sleep0", dict(h="sleep", legs="sit", hdy=1)),
    ("sleep1", dict(h="sleep", legs="sit", hdy=2)),
    ("push0", dict(legs="apart", arms="pushR", dy=1)),
    ("push1", dict(legs="lift", arms="pushR", h="angry")),
    ("wave0", dict(h="happy", arms="waveA")),
    ("wave1", dict(h="happy", arms="waveB")),
    ("facepalm", dict(h="angry", arms="head")),
    ("cheer", dict(h="happy", arms="up", dy=-1)),
    ("jump", dict(h="happy", legs="dangle", arms="upB")),
    ("crouch", dict(legs="apart", arms="down", dy=2, hdy=1)),
    ("aim0", dict(h="angry", arms="aim", gun=True)),
    ("aim1", dict(h="shout", arms="aim", gun=True, hdy=1)),
    ("dangle2", dict(h="shout", legs="apart", arms="up")),
    ("flossL", dict(h="happy", legs="apart", arms="flossL")),
    ("dabL", dict(h="blink", legs="apart", arms="dabL", hdy=1)),
    ("reins", dict(h="happy", legs="apart", arms="reins")),
    ("reinsLift", dict(h="happy", legs="lift", arms="reins", dy=-1)),
    ("armsOut", dict(h="happy", arms="armsOut")),
    ("auraL", dict(h="normal", legs="apart", arms="auraL")),
    ("auraIdle", dict(h="blink", legs="apart", arms="down", hdy=1)),
    ("vampA", dict(h="angry", legs="apart", arms="vampA")),
    ("vampC", dict(h="normal", legs="together", arms="vampC", dy=1)),
    ("hipsHappy", dict(h="happy", arms="hips")),
    ("headHappy", dict(h="happy", arms="head")),
]
sheet = Image.new("RGBA", (FW * len(FRAMES), FH), (0, 0, 0, 0))
for i, (_, kw) in enumerate(FRAMES):
    sheet.paste(frame(**kw), (i * FW, 0))
sheet.save(os.path.join(ROOT, "assets", "sprite.png"))

# ---------- accessoires : tuyau (24x24), bug (3 frames 12x8) ----------
props = Image.new("RGBA", (64, 40), (0, 0, 0, 0))
G1, G2, G3, G4 = (70, 160, 80), (46, 120, 60), (110, 200, 110), (24, 60, 34)
for y in range(24):
    for x in range(24):
        rim = y < 7
        x0, x1 = (0, 23) if rim else (2, 21)
        if x0 <= x <= x1:
            if x in (x0, x1) or y in (0, 6, 23) or (not rim and y == 7): c = G4
            elif x < x0 + 3: c = G3
            elif x > x1 - 5: c = G2
            else: c = G1
            if rim and y in (1, 2) and x0 < x < x1: c = (18, 30, 22) if y == 1 else G4  # ouverture
            props.putpixel((x, y), c + (255,))
BUG = ["....OO..OO..", "...O..OO..O.", "..OgggOppppO", "..OgEgOppppO", "..OgggOppppO", "...OOOOOOOO.",
       "...O.O..O.O."]
BUGB = ["....OO..OO..", "...O..OO..O.", "..OgggOppppO", "..OgEgOppppO", "..OgggOppppO", "...OOOOOOOO.",
        "..O.O..O.O.."]
BUGX = ["............", "............", "............", "...O..O..O..", "..OggOppppO.", ".OOOOOOOOOOO", "............"]
BPAL = {'O': (30, 20, 40), 'g': (120, 220, 90), 'E': (20, 20, 20), 'p': (160, 90, 220)}
for i, art in enumerate((BUG, BUGB, BUGX)):
    for y, row in enumerate(art):
        for x, ch in enumerate(row):
            if ch != '.': props.putpixel((24 + i * 12 + x, y), BPAL[ch] + (255,))
BOOM = [
    "..OOOOOOOOOOOOOOOO..",
    ".O..............O...",
    "OOOOOOOOOOOOOOOOOOOO",
    "OrrrrrrrrrrrrrrrrrrO",
    "OrOOOOrrOOOOrrOOOOrO",
    "OOkkkkOryyyyrOkkkkOO",
    "OOkKKkOryyyyrOkKKkOO",
    "OOkKKkOrrrrrrOkKKkOO",
    "OOkkkkOrbrbrrOkkkkOO",
    "OrOOOOrrrrrrrrOOOOrO",
    "OrrrrrrrrrrrrrrrrrrO",
    "OOOOOOOOOOOOOOOOOOOO",
]
RPAL = {'O': (24, 18, 30), 'r': (200, 70, 110), 'k': (60, 56, 70), 'K': (30, 26, 36), 'y': (250, 220, 120), 'b': (120, 220, 255)}
for y, row in enumerate(BOOM):
    for x, ch in enumerate(row):
        if ch != '.': props.putpixel((x, 26 + y), RPAL[ch] + (255,))
props.save(os.path.join(ROOT, "assets", "props.png"))

with open(os.path.join(ROOT, "Frames.js"), "w") as f:
    f.write("// Généré par tools/make_sprite.py\n.pragma library\n")
    f.write(f"var W = {FW}, H = {FH};\nvar F = {{\n")
    f.write(",\n".join(f'    "{n}": {i}' for i, (n, _) in enumerate(FRAMES)))
    f.write("\n};\n")
print(len(FRAMES), "frames")
