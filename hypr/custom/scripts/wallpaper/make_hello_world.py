#!/usr/bin/env python3
"""Génère un fond d'écran animé 'Hello, World!' (1920x1080, 30 fps, boucle parfaite)."""
import math, random, subprocess, sys, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

W, H, FPS, T = 1920, 1080, 30, 16.0
N = int(FPS * T)
OUT = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Pictures/Wallpapers/hello-world.mp4")
FD = "/usr/share/fonts/archcraft/normal-fonts/JetBrainsMono/"
f_title = ImageFont.truetype(FD + "JetBrainsMono-ExtraBold.ttf", 150)
f_code = ImageFont.truetype(FD + "JetBrainsMono-Medium.ttf", 38)
f_small = ImageFont.truetype(FD + "JetBrainsMono-Regular.ttf", 22)

BG1, BG2 = (14, 11, 20), (30, 22, 40)
LAV, PINK, CYAN, GREEN = (205, 180, 255), (255, 143, 209), (127, 227, 255), (150, 240, 170)
random.seed(42)

# --- fond statique : dégradé + vignette ---
bg = Image.new("RGB", (W, H))
px = bg.load()
for y in range(H):
    for x in range(0, W):
        pass
grad = Image.linear_gradient("L").resize((W, H)).rotate(0)
bg = Image.composite(Image.new("RGB", (W, H), BG2), Image.new("RGB", (W, H), BG1), grad)
vig = Image.radial_gradient("L").resize((W, H))
bg = Image.composite(Image.new("RGB", (W, H), (6, 4, 9)), bg, vig.point(lambda v: int(min(255, max(0, (v - 90) * 1.4)))))

# --- extraits de code flottants ---
SNIPS = ['print("Hello, World!")', 'console.log("Hello, World!")', 'puts "Hello, World!"',
         'echo "Hello, World!"', 'fmt.Println("Hello, World!")', 'printf("Hello, World!\\n");',
         'System.out.println("Hello");', 'println!("Hello, World!");', 'main = putStrLn "Hello"',
         '<h1>Hello, World!</h1>', 'SELECT \'Hello, World!\';', 'cout << "Hello" << endl;',
         'say "Hello, World!"', 'IO.puts "Hello"', 'Console.WriteLine("Hi");', '0x48 0x65 0x6C 0x6C 0x6F',
         '01001000 01101001', 'git commit -m "hello"', 'sudo make me-a-sandwich', '// TODO: sleep',
         'while(!coffee) wait();', '404: bug not found', 'return 0;', 'import this']
floaters = []
for i in range(46):
    s = random.choice(SNIPS)
    col = random.choice([LAV, PINK, CYAN, GREEN])
    k = random.choice([1, 1, 2])
    floaters.append(dict(s=s, x=random.randint(-100, W - 200), y0=random.random() * (H + 120),
                         k=k, a=random.randint(28, 70) if k == 1 else random.randint(18, 40), col=col,
                         ph=random.random()))
# pré-rendu de chaque extrait
for f in floaters:
    bb = f_small.getbbox(f["s"])
    im = Image.new("L", (bb[2] + 4, bb[3] + 6))
    ImageDraw.Draw(im).text((2, 0), f["s"], font=f_small, fill=255)
    f["mask"] = im

# --- titre : masque + halo pré-calculés ---
TITLE = "Hello, World!"
tb = f_title.getbbox(TITLE)
tw, th = tb[2] - tb[0], tb[3] - tb[1]
TX, TY = 150, 330
tmask = Image.new("L", (W, H))
ImageDraw.Draw(tmask).text((TX - tb[0], TY - tb[1]), TITLE, font=f_title, fill=255)
glow = tmask.filter(ImageFilter.GaussianBlur(28))
glow2 = tmask.filter(ImageFilter.GaussianBlur(8))
# dégradé horizontal périodique (pour l'animer en boucle)
stops = [LAV, PINK, CYAN, LAV]
gw = tw + 400
gstrip = Image.new("RGB", (gw * 2, 1))
for x in range(gw * 2):
    u = (x % gw) / gw * 3
    i = int(u); fr = u - i
    a, b = stops[i], stops[i + 1]
    gstrip.putpixel((x, 0), tuple(int(a[c] + (b[c] - a[c]) * fr) for c in range(3)))

# --- ligne de code tapée ---
LINES = [("python", 'print("Hello, World!")'), ("js", 'console.log("Hello, World!");'),
         ("c", 'printf("Hello, World!\\n");'), ("rust", 'println!("Hello, World!");')]
SEG = T / len(LINES)

def blobs(t):
    small = Image.new("RGB", (W // 8, H // 8), (0, 0, 0))
    d = ImageDraw.Draw(small)
    for i, (col, r, cx, cy, rx, ry) in enumerate([(LAV, 34, .25, .45, .10, .12), (PINK, 28, .70, .35, .12, .10),
                                                   (CYAN, 24, .55, .75, .14, .08)]):
        ang = 2 * math.pi * (t / T) * (1 if i % 2 == 0 else -1) + i
        x = (cx + rx * math.cos(ang)) * W / 8
        y = (cy + ry * math.sin(ang)) * H / 8
        d.ellipse((x - r, y - r, x + r, y + r), fill=tuple(int(c * .22) for c in col))
    return small.filter(ImageFilter.GaussianBlur(14)).resize((W, H), Image.BILINEAR)

ff = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
                       "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "slow",
                       "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", OUT], stdin=subprocess.PIPE)

for n in range(N):
    t = n / FPS
    fr = ImageChops.add(bg, blobs(t))
    d = ImageDraw.Draw(fr)
    # extraits flottants (montent ; distance parcourue = k * (H+120) par boucle -> boucle parfaite)
    for f in floaters:
        y = (f["y0"] - (t / T) * f["k"] * (H + 120)) % (H + 120) - 60
        a = int(f["a"] * (0.75 + 0.25 * math.sin(2 * math.pi * (t / T * 2 + f["ph"]))))
        fr.paste(Image.new("RGB", f["mask"].size, f["col"]), (f["x"], int(y)),
                 f["mask"].point(lambda v, a=a: v * a // 255))
    # halo pulsant du titre
    pulse = 0.65 + 0.35 * math.sin(2 * math.pi * t / T * 4)
    fr = ImageChops.add(fr, Image.merge("RGB", [glow.point(lambda v, c=c: int(v * c / 255 * 0.9 * pulse)) for c in PINK]))
    fr = ImageChops.add(fr, Image.merge("RGB", [glow2.point(lambda v, c=c: int(v * c / 255 * 0.5)) for c in LAV]))
    off = int((t / T) * gw * 2) % gw
    gcol = gstrip.crop((off, 0, off + tw + 40, 1)).resize((tw + 40, th + 40))
    layer = Image.new("RGB", (W, H)); layer.paste(gcol, (TX - 20, TY - 20))
    fr = Image.composite(layer, fr, tmask)
    d = ImageDraw.Draw(fr)
    # terminal
    li = int(t // SEG) % len(LINES); lt = (t % SEG) / SEG
    lang, code = LINES[li]
    if lt < 0.55: k = int(len(code) * min(1, lt / 0.45))
    elif lt < 0.85: k = len(code)
    else: k = int(len(code) * (1 - (lt - 0.85) / 0.15))
    cy = TY + th + 90
    d.text((TX, cy - 40), f"~/hello.{ {'python':'py','js':'js','c':'c','rust':'rs'}[lang] }", font=f_small, fill=(120, 105, 150))
    d.text((TX, cy), "❯ " if False else "$ ", font=f_code, fill=GREEN)
    x0 = TX + int(f_code.getlength("$ "))
    d.text((x0, cy), code[:k], font=f_code, fill=(225, 215, 240))
    if (int(t * 2) % 2 == 0) or lt < 0.55:
        cx = x0 + int(f_code.getlength(code[:k])) + 2
        d.rectangle((cx, cy + 6, cx + 20, cy + 46), fill=PINK)
    if 0.5 < lt < 0.9:
        d.text((TX, cy + 60), "Hello, World!", font=f_code, fill=(160, 150, 185))
    ff.stdin.write(fr.tobytes())
    if n % 60 == 0: print(f"{n}/{N}", flush=True)

ff.stdin.close(); ff.wait()
print("OK ->", OUT)
