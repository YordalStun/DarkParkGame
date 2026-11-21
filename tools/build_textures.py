#!/usr/bin/env python3
"""
Generates the low-res, PS1-style textures in assets/textures/.

Everything is procedural, so any texture can later be replaced by a
hand-painted PNG with the same name and size.

Usage: python3 tools/build_textures.py      (requires numpy + Pillow)
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures")
rng = np.random.default_rng(1989)


# ------------------------------------------------------------- helpers
def value_noise(size, cells, seed):
    """Tileable value noise in [0,1]."""
    r = np.random.default_rng(seed)
    w, h = size
    grid = r.random((cells[1], cells[0]))
    ys = np.linspace(0, cells[1], h, endpoint=False)
    xs = np.linspace(0, cells[0], w, endpoint=False)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    y1 = (y0 + 1) % cells[1]
    x1 = (x0 + 1) % cells[0]
    a = grid[y0][:, x0]
    b = grid[y0][:, x1]
    c = grid[y1][:, x0]
    d = grid[y1][:, x1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(size, base_cells, octaves, seed):
    acc = np.zeros((size[1], size[0]))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = (base_cells[0] * 2 ** o, base_cells[1] * 2 ** o)
        if c[0] > size[0] or c[1] > size[1]:
            break
        acc += value_noise(size, c, seed + o) * amp
        tot += amp
        amp *= 0.5
    return acc / tot


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5


def colorize(v, c0, c1):
    v = np.clip(v, 0, 1)[..., None]
    return np.array(c0) * (1 - v) + np.array(c1) * v


def save(rgb, name, levels=32, alpha=None):
    """Quantise with an ordered dither (PS1-ish 15-bit colour) and save."""
    h, w = rgb.shape[:2]
    d = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w][..., None]
    q = np.floor(np.clip(rgb / 255.0, 0, 1) * (levels - 1) + 0.5 + d * 0.9) / (levels - 1)
    q = (np.clip(q, 0, 1) * 255).astype(np.uint8)
    if alpha is not None:
        img = Image.fromarray(np.dstack([q, (np.clip(alpha, 0, 1) * 255).astype(np.uint8)]), "RGBA")
    else:
        img = Image.fromarray(q, "RGB")
    img.save(os.path.join(OUT, name))
    print("  ", name, img.size)


def font(size):
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


# ------------------------------------------------------------ textures
def asphalt():
    s = (128, 128)
    n = fbm(s, (4, 4), 5, 10)
    grit = rng.random((128, 128))
    v = 0.35 + 0.35 * n + 0.25 * (grit > 0.93) - 0.15 * (grit < 0.05)
    rgb = colorize(v, (22, 22, 24), (78, 76, 74))
    # a few hairline cracks
    img = Image.fromarray(rgb.astype(np.uint8))
    d = ImageDraw.Draw(img)
    for _ in range(3):
        x, y = rng.integers(0, 128, 2)
        pts = [(x, y)]
        for _ in range(8):
            x = (x + rng.integers(-6, 7)) % 128
            y = (y + rng.integers(2, 9)) % 128
            pts.append((x, y))
        d.line(pts, fill=(14, 14, 15), width=1)
    save(np.array(img, float), "asphalt.png")


def concrete():
    s = (64, 64)
    n = fbm(s, (4, 4), 4, 20)
    speck = rng.random((64, 64))
    v = 0.55 + 0.3 * n - 0.2 * (speck > 0.95)
    save(colorize(v, (70, 68, 64), (150, 146, 138)), "concrete.png")


def wood_desk():
    s = (128, 128)
    n = fbm((128, 128), (2, 16), 4, 30)
    y = np.arange(128)[:, None]
    grain = np.sin(y * 0.55 + n * 9.0) * 0.5 + 0.5
    v = 0.45 + 0.35 * grain * 0.6 + 0.25 * fbm(s, (8, 2), 3, 31)
    save(colorize(v, (62, 38, 22), (150, 102, 62)), "wood_desk.png")


def wall_panel():
    # 80s fake-wood wall panelling with vertical grooves.
    s = (64, 64)
    n = fbm(s, (16, 2), 4, 40)
    x = np.arange(64)[None, :]
    grain = np.sin(x * 0.9 + n * 7.0) * 0.5 + 0.5
    v = 0.45 + 0.3 * grain + 0.15 * fbm(s, (2, 8), 3, 41)
    groove = ((x % 16) == 0) | ((x % 16) == 1)
    v = np.where(groove, v * 0.35, v)
    save(colorize(v, (52, 33, 20), (128, 86, 52)), "wall_panel.png")


def floor_lino():
    s = (64, 64)
    yy, xx = np.mgrid[0:64, 0:64]
    check = ((xx // 32 + yy // 32) % 2).astype(float)
    n = fbm(s, (4, 4), 4, 50)
    v = 0.25 + 0.5 * check + 0.25 * n
    rgb = colorize(v, (60, 56, 48), (150, 142, 120))
    rgb[(xx % 32 == 0) | (yy % 32 == 0)] *= 0.6
    save(rgb, "floor_lino.png")


def ceiling_tile():
    s = (64, 64)
    n = fbm(s, (8, 8), 3, 60)
    holes = rng.random((64, 64)) > 0.9
    v = 0.8 + 0.12 * n - 0.35 * holes
    yy, xx = np.mgrid[0:64, 0:64]
    v[(xx % 64 < 1) | (yy % 64 < 1)] = 0.45
    save(colorize(v, (90, 88, 80), (200, 196, 184)), "ceiling_tile.png")


def painted_metal():
    s = (64, 64)
    n = fbm(s, (4, 4), 4, 70)
    rust = fbm(s, (8, 8), 3, 71) > 0.68
    v = 0.6 + 0.3 * n
    rgb = colorize(v, (90, 92, 88), (170, 172, 165))
    rgb[rust] = rgb[rust] * 0.5 + np.array([90, 50, 25]) * 0.5
    save(rgb, "metal.png")


def beige_plastic():
    s = (64, 64)
    n = fbm(s, (8, 8), 3, 80)
    save(colorize(0.6 + 0.25 * n, (150, 140, 116), (214, 204, 178)), "beige_plastic.png")


def bark():
    s = (64, 64)
    n = fbm(s, (16, 2), 4, 90)
    x = np.arange(64)[None, :]
    v = 0.4 + 0.4 * (np.sin(x * 0.7 + n * 6) * 0.5 + 0.5) * fbm(s, (4, 8), 3, 91)
    save(colorize(v, (28, 22, 16), (92, 74, 56)), "bark.png")


def leaves():
    s = (64, 64)
    n = fbm(s, (8, 8), 4, 100)
    blob = rng.random((64, 64))
    v = 0.25 + 0.5 * n + 0.25 * (blob > 0.8) - 0.2 * (blob < 0.12)
    save(colorize(v, (14, 26, 12), (70, 96, 40)), "leaves.png")


def pine():
    s = (64, 64)
    n = fbm(s, (16, 4), 4, 110)
    y = np.arange(64)[:, None]
    v = 0.3 + 0.4 * n + 0.2 * ((y % 8) < 2)
    save(colorize(v, (8, 20, 14), (38, 70, 46)), "pine.png")


def grass():
    s = (64, 64)
    n = fbm(s, (8, 8), 4, 120)
    blade = rng.random((64, 64))
    v = 0.3 + 0.45 * n + 0.2 * (blade > 0.75)
    save(colorize(v, (16, 24, 10), (66, 80, 36)), "grass.png")


def brick():
    s = (64, 64)
    yy, xx = np.mgrid[0:64, 0:64]
    row = yy // 8
    off = (row % 2) * 8
    mortar = ((yy % 8) == 0) | (((xx + off) % 16) == 0)
    n = fbm(s, (8, 8), 3, 130)
    v = 0.5 + 0.35 * n
    rgb = colorize(v, (58, 26, 20), (130, 62, 46))
    rgb[mortar] = (60, 58, 54)
    save(rgb, "brick.png")


def chainlink():
    s = 32
    a = np.zeros((s, s))
    yy, xx = np.mgrid[0:s, 0:s]
    a[(np.abs((xx + yy) % 16 - 8) < 1) | (np.abs((xx - yy) % 16 - 8) < 1)] = 1
    rgb = np.full((s, s, 3), 150.0)
    save(rgb, "chainlink.png", alpha=a)


def paint_worn():
    # worn white road paint: alpha is the wear mask
    s = (64, 16)
    n = fbm(s, (8, 2), 4, 140)
    speck = rng.random((16, 64))
    a = np.clip((n - 0.25) * 2.2, 0, 1) * (speck > 0.12)
    save(np.full((16, 64, 3), 205.0), "paint_worn.png", alpha=a)


def keyboard():
    w, h = 128, 48
    img = Image.new("RGB", (w, h), (150, 140, 118))
    d = ImageDraw.Draw(img)
    rows = [(14, 0), (14, 2), (13, 4), (12, 6)]
    kw = 7
    for r, (count, off) in enumerate(rows):
        y = 4 + r * 9
        for k in range(count):
            x = 4 + off + k * (kw + 1)
            d.rectangle([x, y, x + kw - 1, y + 7], fill=(196, 186, 160))
            d.line([x, y + 7, x + kw - 1, y + 7], fill=(110, 102, 86))
    d.rectangle([24, 40, 84, 46], fill=(196, 186, 160))  # space bar
    for k in range(4):  # numpad
        for r in range(4):
            x, y = 98 + k * 7, 4 + r * 9
            d.rectangle([x, y, x + 5, y + 7], fill=(176, 166, 140))
    save(np.array(img, float), "keyboard.png")


def paper_log():
    w, h = 64, 80
    img = Image.new("RGB", (w, h), (214, 210, 190))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, 9], fill=(170, 60, 50))
    for y in range(14, h, 6):
        d.line([3, y, w - 3, y], fill=(150, 170, 200))
    d.line([10, 10, 10, h], fill=(210, 120, 120))
    # some scribbled entries
    for i, y in enumerate(range(16, 50, 6)):
        x = 12
        for _ in range(rng.integers(4, 9)):
            l = rng.integers(2, 6)
            d.line([x, y - 2, x + l, y - 3 + rng.integers(0, 3)], fill=(40, 40, 70))
            x += l + 2
    n = fbm((w, h), (4, 5), 3, 150)[..., None]
    save(np.array(img, float) * (0.85 + 0.15 * n), "paper_log.png")


def clock_face():
    s = 64
    img = Image.new("RGB", (s, s), (40, 38, 34))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, s - 2, s - 2], fill=(222, 216, 198), outline=(30, 30, 30))
    c = s / 2 - 0.5
    for i in range(12):
        ang = i / 12 * 2 * np.pi
        r0, r1 = (24, 29) if i % 3 == 0 else (26, 29)
        d.line([c + np.sin(ang) * r0, c - np.cos(ang) * r0,
                c + np.sin(ang) * r1, c - np.cos(ang) * r1],
               fill=(20, 20, 20), width=2 if i % 3 == 0 else 1)
    save(np.array(img, float), "clock_face.png")


def calendar():
    w, h = 64, 88
    img = Image.new("RGB", (w, h), (226, 222, 206))
    d = ImageDraw.Draw(img)
    # picture half: a moody seascape
    for y in range(0, 40):
        t = y / 40
        d.line([0, y, w, y], fill=(int(40 + 80 * t), int(70 + 60 * t), int(110 + 40 * t)))
    d.polygon([(0, 40), (20, 26), (36, 34), (52, 22), (64, 30), (64, 40)], fill=(40, 52, 40))
    f = font(7)
    d.text((4, 41), "OCTOBER 1989", fill=(150, 30, 30), font=f)
    # grid: Oct 1 1989 was a Sunday
    for i in range(31):
        col, row = i % 7, i // 7
        x, y = 3 + col * 8.5, 51 + row * 7
        fill = (190, 40, 40) if i + 1 == 13 else (60, 60, 60)
        d.rectangle([x, y, x + 6, y + 5], outline=(170, 168, 156))
        if i + 1 == 13:
            d.line([x, y, x + 6, y + 5], fill=fill)
            d.line([x + 6, y, x, y + 5], fill=fill)
    save(np.array(img, float), "calendar.png")


def lot_sign():
    w, h = 128, 64
    img = Image.new("RGB", (w, h), (30, 60, 120))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 2, w - 3, h - 3], outline=(220, 220, 220), width=2)
    d.text((10, 8), "LOT C", fill=(235, 235, 235), font=font(18))
    d.text((10, 32), "PERMIT HOLDERS", fill=(235, 235, 235), font=font(9))
    d.text((10, 44), "ONLY  -  24 HR", fill=(235, 235, 235), font=font(9))
    n = fbm((w, h), (8, 4), 3, 160)[..., None]
    save(np.array(img, float) * (0.75 + 0.25 * n), "lot_sign.png")


def corkboard():
    s = (64, 48)
    n = fbm(s, (16, 12), 3, 170)
    speck = rng.random((48, 64))
    v = 0.45 + 0.35 * n + 0.2 * (speck > 0.85)
    rgb = colorize(v, (110, 72, 40), (190, 140, 90))
    img = Image.fromarray(rgb.astype(np.uint8))
    d = ImageDraw.Draw(img)
    notes = [((5, 5, 24, 22), (230, 220, 120)), ((30, 8, 54, 28), (230, 230, 225)),
             ((10, 26, 30, 43), (200, 220, 240)), ((38, 30, 58, 44), (240, 200, 200))]
    for (x0, y0, x1, y1), col in notes:
        d.rectangle([x0, y0, x1, y1], fill=col)
        for y in range(y0 + 4, y1 - 2, 4):
            d.line([x0 + 2, y, x1 - 2 - rng.integers(0, 6), y], fill=(70, 70, 90))
        d.point([(x0 + (x1 - x0) // 2, y0 + 1)], fill=(200, 30, 30))
    save(np.array(img, float), "corkboard.png")


def window_lit():
    # distant office windows: emissive mask texture (mostly dark, a few lit)
    w, h = 64, 64
    rgb = np.zeros((h, w, 3))
    for gy in range(0, h, 8):
        for gx in range(0, w, 8):
            if rng.random() < 0.18:
                warm = rng.random() < 0.7
                col = (255, 200, 120) if warm else (170, 200, 255)
                rgb[gy + 2:gy + 6, gx + 2:gx + 6] = np.array(col) * rng.uniform(0.4, 1.0)
            else:
                rgb[gy + 2:gy + 6, gx + 2:gx + 6] = (10, 12, 16)
    save(rgb, "office_windows.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in [asphalt, concrete, wood_desk, wall_panel, floor_lino, ceiling_tile,
              painted_metal, beige_plastic, bark, leaves, pine, grass, brick,
              chainlink, paint_worn, keyboard, paper_log, clock_face, calendar,
              lot_sign, corkboard, window_lit]:
        f()
