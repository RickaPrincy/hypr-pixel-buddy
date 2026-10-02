#!/usr/bin/env python3
"""Génère le fond d'écran pixel-art (480x270 logiques, x4 -> 1920x1080) + scene.json pour le compagnon."""
import json, math, os, random
from PIL import Image

LW, LH, S = 480, 270, 4
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_IMG = os.path.expanduser("~/Pictures/Wallpapers/pixel-world.png")
OUT_JSON = os.path.join(HERE, "..", "scene.json")
rnd = random.Random(7)
img = Image.new("RGB", (LW, LH))
P = img.load()

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
def dith(x, y, t):  # t dans [0,1] -> True si on prend la couleur suivante
    return t * 16 > BAYER[y % 4][x % 4] + 0.5

def put(x, y, c):
    if 0 <= x < LW and 0 <= y < LH:
        P[x, y] = c

def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# ---------- ciel ----------
SKY = [(10, 12, 26), (16, 18, 38), (26, 22, 52), (38, 28, 62), (48, 34, 66)]
for y in range(LH):
    u = y / (LH * 0.85) * (len(SKY) - 1)
    i = min(int(u), len(SKY) - 2); t = min(1, u - i)
    for x in range(LW):
        P[x, y] = SKY[i + 1] if dith(x, y, t) else SKY[i]

# étoiles
for _ in range(170):
    x, y = rnd.randrange(LW), rnd.randrange(int(LH * 0.6))
    b = rnd.choice([70, 90, 120, 160])
    put(x, y, mix(P[x, y], (220, 215, 255), b / 255))
for _ in range(9):
    x, y = rnd.randrange(20, LW - 20), rnd.randrange(50, 130)
    c = (200, 195, 240)
    put(x, y, c); put(x - 1, y, mix(P[x - 1, y], c, .5)); put(x + 1, y, mix(P[x + 1, y], c, .5))
    put(x, y - 1, mix(P[x, y - 1], c, .5)); put(x, y + 1, mix(P[x, y + 1], c, .5))

# lune + halo
MX, MY, MR = 392, 46, 17
for y in range(MY - 60, MY + 60):
    for x in range(MX - 60, MX + 60):
        d = math.hypot(x - MX, y - MY)
        if d <= MR:
            c = (222, 218, 240)
            if d > MR - 2.2 and x > MX: c = (196, 190, 224)
            for cx, cy, cr in ((-5, -4, 4), (6, 3, 3), (-2, 8, 2.5), (4, -8, 2)):
                if math.hypot(x - MX - cx, y - MY - cy) < cr: c = (198, 192, 222)
            put(x, y, c)
        elif d < MR + 40 and 0 <= x < LW and 0 <= y < LH:
            t = (1 - (d - MR) / 40) ** 2 * 0.5
            if dith(x, y, t): put(x, y, mix(P[x, y], (90, 80, 140), 0.35))

# ---------- reliefs ----------
def ridge(base, amps, seed):
    r = random.Random(seed)
    ph = [r.random() * 6.28 for _ in amps]
    return [base + sum(a * math.sin(x * f + p) for (a, f), p in zip(amps, ph)) for x in range(LW)]

def fill_ridge(h, col, edge=None):
    for x in range(LW):
        top = int(h[x])
        for y in range(max(0, top), LH):
            P[x, y] = col
        if edge and 0 <= top < LH:
            P[x, top] = edge

far = ridge(178, [(14, .013), (7, .041), (3, .11)], 1)
fill_ridge(far, (34, 30, 60), (52, 44, 82))
mid = ridge(200, [(10, .02), (6, .057), (2, .19)], 2)
fill_ridge(mid, (26, 32, 50), (36, 44, 64))
# arbres (silhouettes) sur la colline du milieu
for _ in range(38):
    x = rnd.randrange(LW); top = int(mid[x]); h = rnd.randint(10, 26); w = rnd.randint(4, 8)
    for yy in range(h):
        hw = int(w * (yy / h)) + 1
        for xx in range(-hw, hw + 1):
            put(x + xx, top - h + yy + 2, (24, 30, 46) if xx < hw - 1 else (30, 38, 56))
near = ridge(226, [(6, .03), (4, .09), (2, .23)], 3)
fill_ridge(near, (18, 30, 36), (26, 44, 46))
# buissons proches
for _ in range(60):
    x = rnd.randrange(LW); y = int(near[x]); r = rnd.randint(3, 8)
    for yy in range(-r, r):
        for xx in range(-r, r):
            if xx * xx + yy * yy < r * r:
                put(x + xx, y + yy, (20, 36, 40) if yy > -r + 2 else (30, 54, 52))

# ---------- sol ----------
GROUND = 247
for x in range(LW):
    gy = GROUND + (1 if (x // 9) % 3 == 0 else 0)
    for y in range(gy, LH):
        d = y - gy
        if d < 2: c = (78, 140, 74) if d == 0 else (58, 110, 60)
        elif d < 4: c = (48, 88, 52) if dith(x, y, .5) else (70, 52, 40)
        else:
            c = (70, 50, 40) if dith(x, y, min(1, (d - 4) / 18)) is False else (52, 36, 30)
        P[x, y] = c
# pierres dans la terre
for _ in range(70):
    x, y = rnd.randrange(LW), rnd.randrange(GROUND + 6, LH - 1)
    put(x, y, (96, 84, 86)); put(x + 1, y, (80, 70, 74)); put(x, y + 1, (60, 50, 54))
# touffes d'herbe et fleurs
for _ in range(120):
    x = rnd.randrange(LW)
    for k in range(rnd.randint(1, 3)):
        put(x + k, GROUND - 1 - (k % 2), (88, 156, 80))
for _ in range(16):
    x = rnd.randrange(LW)
    put(x, GROUND - 1, (70, 120, 60)); put(x, GROUND - 2, rnd.choice([(230, 140, 200), (240, 220, 120), (150, 200, 255)]))
# champignons lumineux
mush = []
for x in (28, 96, 205, 300, 452):
    put(x, GROUND - 1, (210, 200, 190)); put(x, GROUND - 2, (210, 200, 190))
    for xx in (-1, 0, 1): put(x + xx, GROUND - 3, (110, 220, 230))
    put(x, GROUND - 4, (150, 240, 245))
    mush.append([x * S, (GROUND - 4) * S])

# ---------- îles flottantes ----------
def island(x1, x2, top, seed, depth=None):
    r = random.Random(seed)
    w = x2 - x1
    depth = depth or int(w * 0.55)
    for x in range(x1, x2):
        u = (x - x1) / (w - 1)
        bottom = top + 3 + int(depth * (1 - abs(u * 2 - 1) ** 1.6)) + r.randint(0, 1)
        for y in range(top, bottom):
            d = y - top
            if d == 0: c = (84, 150, 78)
            elif d < 3: c = (56, 112, 62)
            elif d < 4: c = (40, 84, 50) if dith(x, y, .5) else (70, 48, 40)
            else:
                shade = (x - x1) / w + (d / depth) * 0.35
                c = (70, 48, 40) if (shade < .6 or not dith(x, y, min(1, (shade - .6) * 2.5))) else (50, 34, 30)
                if r.random() < 0.012: c = (88, 74, 72)
            put(x, y, c)
        # racines
        if r.random() < 0.13:
            L = r.randint(4, 14)
            for k in range(L):
                put(x + (k // 5) * (1 if r.random() < .5 else 0), bottom + k, (64, 46, 36) if k < L - 2 else (54, 40, 34))
    # contour sombre sous l'île
    for x in range(x1, x2):
        put(x, top - 1, mix(P[x, top - 1], (120, 190, 100), .6) if (x * 7) % 5 == 0 else P[x, top - 1])

islands = [(36, 150, 168, 11), (322, 432, 122, 12), (212, 266, 197, 13)]
for x1, x2, top, sd in islands:
    island(x1, x2, top, sd)
    for _ in range((x2 - x1) // 6):  # herbe
        x = rnd.randrange(x1 + 2, x2 - 2)
        put(x, top - 1, (110, 186, 96)); put(x + 1, top - 2, (96, 170, 86))

# arbre sur l'île gauche
tx, ty = 58, 168
for y in range(ty - 22, ty):
    put(tx, y, (80, 56, 42)); put(tx + 1, y, (64, 44, 34))
for cy, cr in ((ty - 26, 9), (ty - 32, 7), (ty - 22, 7)):
    for yy in range(-cr, cr + 1):
        for xx in range(-cr - 3, cr + 4):
            if (xx / (cr + 3)) ** 2 + (yy / cr) ** 2 <= 1:
                put(tx + xx, cy + yy, (54, 112, 64) if (xx + yy) < cr // 2 else (40, 86, 54))
for _ in range(10):
    put(tx + rnd.randint(-8, 8), ty - 26 + rnd.randint(-8, 8), (84, 150, 84))

# panneau "hello world" sur l'île gauche
FONT = {'h': ["1.1", "1.1", "111", "1.1", "1.1"], 'e': ["111", "1..", "11.", "1..", "111"], 'l': ["1..", "1..", "1..", "1..", "111"],
        'o': ["111", "1.1", "1.1", "1.1", "111"], 'w': ["1.1", "1.1", "1.1", "111", "1.1"], 'r': ["11.", "1.1", "11.", "1.1", "1.1"],
        'd': ["11.", "1.1", "1.1", "1.1", "11."], ' ': ["...", "...", "...", "...", "..."]}
sx, sy = 84, 146
for y in range(sy, sy + 15):
    for x in range(sx, sx + 30):
        put(x, y, (140, 98, 62) if (y - sy) % 5 else (118, 80, 52))
for x in range(sx - 1, sx + 31): put(x, sy - 1, (60, 40, 30)); put(x, sy + 15, (60, 40, 30))
for y in range(sy, sy + 15): put(sx - 1, y, (60, 40, 30)); put(sx + 30, y, (60, 40, 30))
for y in range(sy + 15, 168): put(sx + 14, y, (90, 62, 44)); put(sx + 15, y, (70, 48, 36))
for line, (ox, oy) in (("hello", (sx + 3, sy + 2)), ("world", (sx + 7, sy + 8))):
    for i, ch in enumerate(line):
        for yy, row in enumerate(FONT[ch]):
            for xx, v in enumerate(row):
                if v == "1": put(ox + i * 4 + xx, oy + yy, (250, 238, 210))

# cristaux sur l'île droite
crystals = []
def crystal(x, base, h, w, c1, c2, c3):
    for y in range(h):
        hw = w if y < h - 4 else max(0, w - (y - (h - 5)))
        for xx in range(-hw, hw + 1):
            c = c1 if xx < 0 else c2
            if xx == -hw or xx == hw: c = c3
            put(x + xx, base - y, c)
    put(x - 1, base - h + 5, (240, 248, 255)); put(x - 1, base - h + 6, (210, 230, 255))
    crystals.append([(x - w) * S, (base - h) * S, (2 * w + 1) * S, h * S])
crystal(392, 121, 22, 4, (120, 200, 255), (70, 140, 230), (40, 80, 160))
crystal(402, 121, 13, 3, (190, 140, 255), (140, 90, 220), (80, 50, 150))
crystal(383, 121, 9, 2, (140, 230, 240), (90, 180, 210), (50, 110, 150))
crystal(238, 197, 7, 2, (255, 160, 210), (210, 110, 170), (130, 60, 110))

# lianes depuis le haut
def vine(x, length, seed):
    r = random.Random(seed)
    for y in range(0, length):
        xx = x + int(2 * math.sin(y * 0.15 + seed))
        put(xx, y, (34, 70, 48)); put(xx + 1, y, (26, 54, 40))
        if r.random() < 0.18:
            d = 1 if r.random() < .5 else -2
            put(xx + d, y, (60, 120, 70)); put(xx + d * 2, y + 1, (48, 100, 60))
for x, L, sd in ((6, 90, 1), (16, 54, 2), (30, 34, 3), (468, 70, 4), (455, 40, 5), (160, 22, 6), (300, 28, 7)):
    vine(x, L, sd)

# légère vignette
for y in range(LH):
    for x in range(LW):
        d = math.hypot((x - LW / 2) / (LW / 2), (y - LH / 2) / (LH / 2))
        if d > 0.9 and dith(x, y, min(1, (d - 0.9) * 1.6)):
            P[x, y] = mix(P[x, y], (6, 6, 14), 0.35)

big = img.resize((LW * S, LH * S), Image.NEAREST)
big.save(OUT_IMG)

scene = {
    "scale": S,
    "ground": GROUND * S,
    "platforms": [{"x1": x1 * S, "x2": x2 * S, "y": top * S} for x1, x2, top, _ in islands],
    "crystals": crystals,
    "mushrooms": mush,
    "sign": [sx * S, sy * S, 30 * S, 15 * S],
    "pipes": [{"x": 372 * S, "y": GROUND * S, "to": 1}, {"x": 116 * S, "y": 168 * S, "to": 0}],
    "tree": [tx * S, (ty - 40) * S],
}
with open(OUT_JSON, "w") as f:
    json.dump(scene, f, indent=1)
print("->", OUT_IMG, OUT_JSON)
