#!/usr/bin/env python3
"""
Generates the pixel art for the in-game Windows-95-style desktop:

  assets/desktop/icons/<name>.png      32x32 icons
  assets/desktop/icons/<name>_16.png   16x16 versions (for title bars, menus, taskbar)
  assets/desktop/icons/tb_<name>.png   24x24 browser toolbar glyphs
  assets/desktop/icons/pt_<name>.png   16x16 Paint tool glyphs
  assets/desktop/web/<name>.png        graphics for the fake web pages

Everything is drawn from scratch with Pillow, so it is ours outright.

Usage: python3 tools/build_desktop_art.py      (requires numpy + Pillow)
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "desktop", "icons")
WEB = os.path.join(ROOT, "assets", "desktop", "web")
os.makedirs(ICONS, exist_ok=True)
os.makedirs(WEB, exist_ok=True)

DJV_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
LIB_B = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
LIB_R = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
SERIF_B = "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf"
SERIF_R = "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf"
MONO_B = "/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf"

K = (0, 0, 0, 255)
W = (255, 255, 255, 255)
G = (192, 192, 192, 255)
LG = (223, 223, 223, 255)
DG = (128, 128, 128, 255)
NAVY = (0, 0, 128, 255)
BLUE = (0, 0, 255, 255)
SKY = (128, 192, 255, 255)
TEAL = (0, 128, 128, 255)
YEL = (255, 255, 0, 255)
DYEL = (128, 128, 0, 255)
CREAM = (255, 255, 160, 255)
RED = (255, 0, 0, 255)
DRED = (128, 0, 0, 255)
GRN = (0, 255, 0, 255)
DGRN = (0, 128, 0, 255)
MAG = (255, 0, 255, 255)
ORG = (255, 128, 0, 255)


def canvas(n=32):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def box(d, x0, y0, x1, y1, fill=G, raised=True):
    """Win95 3D box (inclusive coordinates)."""
    d.rectangle([x0, y0, x1, y1], fill=fill)
    tl, br = (W, K) if raised else (K, W)
    itl, ibr = (LG, DG) if raised else (DG, LG)
    d.line([x0, y0, x1 - 1, y0], fill=tl)
    d.line([x0, y0, x0, y1 - 1], fill=tl)
    d.line([x0, y1, x1, y1], fill=br)
    d.line([x1, y0, x1, y1], fill=br)
    d.line([x0 + 1, y0 + 1, x1 - 2, y0 + 1], fill=itl)
    d.line([x0 + 1, y0 + 1, x0 + 1, y1 - 2], fill=itl)
    d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=ibr)
    d.line([x1 - 1, y0 + 1, x1 - 1, y1 - 1], fill=ibr)


def glyph(img, text, xy, size, fill, font=DJV_B, anchor="mm"):
    """Hard-edged text (no antialiasing) so it stays crisp when tiny."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text(xy, text, font=ImageFont.truetype(font, size), fill=255, anchor=anchor)
    mask = mask.point(lambda v: 255 if v > 110 else 0)
    img.paste(Image.new("RGBA", img.size, fill), (0, 0), mask)


def outline_poly(d, pts, fill, line=K):
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=line)


def small(img, n=16):
    """Box-filter down, then snap alpha so edges stay hard."""
    s = img.resize((n, n), Image.BOX)
    a = np.array(s)
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    return Image.fromarray(a)


# ------------------------------------------------------------------ 32px icons
def monitor(d, x=6, y=2):
    box(d, x, y, x + 19, y + 17)
    d.rectangle([x + 3, y + 3, x + 16, y + 13], fill=TEAL, outline=DG)
    d.line([x + 4, y + 4, x + 9, y + 4], fill=(120, 220, 220, 255))


def ic_computer():
    img, d = canvas()
    monitor(d, 6, 1)
    box(d, 2, 21, 29, 29)
    d.rectangle([5, 24, 17, 26], fill=DG)
    d.rectangle([22, 24, 24, 25], fill=GRN, outline=DGRN)
    return img


def ic_folder(open_=False):
    img, d = canvas()
    outline_poly(d, [(2, 7), (12, 7), (14, 9), (28, 9), (28, 26), (2, 26)], (200, 200, 90, 255))
    if open_:
        outline_poly(d, [(6, 14), (30, 14), (26, 26), (2, 26)], CREAM)
    else:
        d.rectangle([3, 11, 27, 25], fill=CREAM, outline=K)
        d.line([4, 12, 26, 12], fill=W)
    return img


def ic_doc(lines=True, color=W):
    img, d = canvas()
    outline_poly(d, [(8, 3), (21, 3), (26, 8), (26, 29), (8, 29)], color)
    d.polygon([(21, 3), (21, 8), (26, 8)], fill=G, outline=K)
    if lines:
        for y in (12, 15, 18, 21, 24):
            d.line([11, y, 22, y], fill=DG)
    return img


def ic_notepad():
    img, d = canvas()
    d.rectangle([6, 5, 25, 29], fill=W, outline=K)
    d.rectangle([7, 6, 24, 10], fill=(80, 140, 255, 255))
    for x in range(9, 24, 3):
        d.rectangle([x, 3, x + 1, 8], fill=DG, outline=K)
    for y in (14, 17, 20, 23, 26):
        d.line([9, y, 22, y], fill=(120, 160, 255, 255))
    return img


def ic_paint():
    img, d = canvas()
    d.ellipse([2, 8, 29, 27], fill=(250, 235, 200, 255), outline=K)
    d.ellipse([20, 18, 24, 22], fill=W, outline=K)
    for (x, y, c) in [(7, 13, RED), (12, 11, YEL), (18, 11, BLUE), (23, 14, DGRN), (7, 20, MAG)]:
        d.ellipse([x, y, x + 4, y + 4], fill=c, outline=K)
    d.line([20, 24, 31, 4], fill=(150, 90, 30, 255), width=2)
    d.polygon([(28, 4), (31, 2), (31, 7)], fill=K)
    return img


def ic_calc():
    img, d = canvas()
    box(d, 7, 2, 25, 29)
    d.rectangle([10, 5, 22, 11], fill=(190, 255, 190, 255), outline=K)
    d.line([19, 7, 21, 7], fill=DGRN)
    for r in range(4):
        for c in range(3):
            x, y = 10 + c * 5, 14 + r * 4
            d.rectangle([x, y, x + 3, y + 2], fill=(RED if (c == 2 and r == 0) else W), outline=DG)
    return img


def ic_dos():
    img, d = canvas()
    box(d, 2, 4, 29, 27)
    d.rectangle([4, 6, 27, 9], fill=NAVY)
    d.rectangle([4, 10, 27, 25], fill=K)
    d.line([7, 14, 9, 16], fill=W)
    d.line([9, 16, 7, 18], fill=W)
    d.line([12, 19, 16, 19], fill=W)
    return img


def ic_globe():
    img, d = canvas()
    d.ellipse([3, 3, 28, 28], fill=(30, 80, 200, 255), outline=K)
    land = (40, 170, 60, 255)
    d.polygon([(8, 8), (14, 6), (17, 9), (14, 13), (16, 17), (11, 19), (8, 15)], fill=land)
    d.polygon([(19, 14), (25, 12), (26, 18), (22, 24), (19, 20)], fill=land)
    d.polygon([(11, 23), (15, 22), (14, 26), (11, 25)], fill=land)
    d.arc([3, 3, 28, 28], 200, 260, fill=(180, 220, 255, 255), width=2)
    d.ellipse([3, 3, 28, 28], outline=K)
    return img


def ic_mail():
    img, d = canvas()
    d.rectangle([3, 8, 28, 25], fill=W, outline=K)
    d.line([3, 8, 15, 18], fill=DG)
    d.line([28, 8, 16, 18], fill=DG)
    d.line([3, 25, 12, 16], fill=DG)
    d.line([28, 25, 19, 16], fill=DG)
    d.rectangle([21, 10, 25, 14], fill=(255, 140, 140, 255), outline=DRED)
    return img


def ic_inbox():
    img, d = canvas()
    box(d, 2, 17, 29, 28)
    d.rectangle([5, 21, 26, 24], fill=DG)
    d.rectangle([7, 7, 24, 19], fill=W, outline=K)
    d.line([7, 7, 15, 14], fill=DG)
    d.line([24, 7, 16, 14], fill=DG)
    return img


def ic_mine():
    img, d = canvas()
    d.rectangle([0, 0, 31, 31], fill=G)
    d.rectangle([0, 0, 31, 31], outline=DG)
    c = 16
    for a in range(0, 360, 45):
        x, y = c + 12 * math.cos(math.radians(a)), c + 12 * math.sin(math.radians(a))
        d.line([c, c, x, y], fill=K, width=2)
    d.ellipse([7, 7, 24, 24], fill=K)
    d.rectangle([11, 11, 13, 13], fill=W)
    return img


def ic_trash(full=False):
    img, d = canvas()
    if full:
        for (x, y, a) in [(9, 2, W), (14, 0, CREAM), (18, 3, W)]:
            d.rectangle([x, y + 3, x + 7, y + 12], fill=a, outline=DG)
    outline_poly(d, [(7, 9), (25, 9), (23, 29), (9, 29)], G)
    d.rectangle([5, 6, 27, 9], fill=LG, outline=K)
    d.rectangle([13, 4, 19, 6], fill=LG, outline=K)
    for x in (11, 16, 21):
        d.line([x, 12, x - (1 if x < 16 else -1 if x > 16 else 0), 26], fill=DG)
    return img


def ic_network():
    img, d = canvas()
    box(d, 1, 3, 14, 13)
    d.rectangle([3, 5, 12, 10], fill=TEAL)
    box(d, 17, 15, 30, 25)
    d.rectangle([19, 17, 28, 22], fill=TEAL)
    d.line([8, 14, 8, 28], fill=K)
    d.line([8, 28, 24, 28], fill=K)
    d.line([24, 26, 24, 28], fill=K)
    d.rectangle([4, 14, 12, 16], fill=G, outline=K)
    return img


def ic_cam():
    img, d = canvas()
    box(d, 4, 8, 22, 18)
    d.rectangle([22, 10, 28, 16], fill=(30, 30, 60, 255), outline=K)
    d.rectangle([25, 12, 27, 14], fill=(80, 120, 255, 255))
    d.rectangle([6, 10, 8, 12], fill=RED)
    d.rectangle([9, 18, 14, 20], fill=DG, outline=K)
    d.line([11, 20, 11, 27], fill=K, width=3)
    d.rectangle([6, 27, 17, 29], fill=DG, outline=K)
    return img


def ic_gate():
    img, d = canvas()
    box(d, 3, 9, 9, 29)
    d.rectangle([4, 12, 8, 14], fill=RED)
    for i in range(6):
        x = 10 + i * 4
        d.polygon([(x, 12), (x + 2, 12), (x + 4, 17), (x + 2, 17)], fill=RED if i % 2 == 0 else W)
    d.rectangle([10, 12, 31, 12], fill=K)
    d.rectangle([10, 17, 31, 17], fill=K)
    d.rectangle([2, 26, 10, 29], fill=DG, outline=K)
    return img


def ic_drive(kind="hd"):
    img, d = canvas()
    if kind == "hd":
        box(d, 2, 12, 29, 25)
        d.rectangle([6, 17, 20, 19], fill=DG)
        d.rectangle([24, 18, 26, 19], fill=GRN, outline=DGRN)
    elif kind == "floppy":
        d.rectangle([5, 4, 27, 28], fill=(40, 40, 70, 255), outline=K)
        d.rectangle([10, 4, 22, 12], fill=(220, 220, 230, 255), outline=K)
        d.rectangle([16, 6, 19, 10], fill=K)
        d.rectangle([8, 17, 24, 27], fill=W, outline=DG)
        d.line([10, 20, 22, 20], fill=(120, 160, 255, 255))
    else:
        d.ellipse([3, 3, 28, 28], fill=(210, 220, 230, 255), outline=K)
        d.ellipse([12, 12, 19, 19], fill=(0, 0, 0, 0), outline=K)
        d.ellipse([5, 5, 26, 26], outline=(150, 170, 220, 255))
    return img


def ic_control():
    img, d = canvas()
    box(d, 3, 4, 28, 27)
    d.rectangle([5, 6, 26, 9], fill=NAVY)
    for i, x in enumerate((9, 15, 21)):
        d.line([x, 13, x, 24], fill=DG, width=2)
        y = (17, 21, 15)[i]
        d.rectangle([x - 2, y, x + 2, y + 2], fill=W, outline=K)
    return img


def ic_clock():
    img, d = canvas()
    d.ellipse([3, 3, 28, 28], fill=W, outline=K, width=2)
    for a in range(0, 360, 30):
        x1, y1 = 15.5 + 10 * math.cos(math.radians(a)), 15.5 + 10 * math.sin(math.radians(a))
        x2, y2 = 15.5 + 12 * math.cos(math.radians(a)), 15.5 + 12 * math.sin(math.radians(a))
        d.line([x1, y1, x2, y2], fill=K)
    d.line([16, 16, 16, 8], fill=K, width=2)
    d.line([16, 16, 22, 19], fill=RED, width=1)
    return img


def ic_round(color, text, tcol=W, fsize=22):
    img, d = canvas()
    d.ellipse([2, 2, 29, 29], fill=color, outline=K)
    glyph(img, text, (16, 16), fsize, tcol)
    return img


def ic_warn():
    img, d = canvas()
    outline_poly(d, [(16, 2), (30, 28), (2, 28)], YEL)
    glyph(img, "!", (16, 20), 18, K)
    return img


def ic_error():
    return ic_round(RED, "X", W, 20)


def ic_help():
    img = ic_round((0, 0, 200, 255), "?", W, 22)
    return img


def ic_gear():
    img, d = canvas()
    c = 15.5
    pts = []
    for i in range(16):
        a = math.radians(i * 22.5)
        r = 14 if i % 2 == 0 else 10.5
        pts.append((c + r * math.cos(a), c + r * math.sin(a)))
    d.polygon(pts, fill=G, outline=K)
    d.ellipse([11, 11, 20, 20], fill=(0, 0, 0, 0), outline=K)
    d.ellipse([12, 12, 19, 19], fill=(0, 0, 0, 0))
    return img


def ic_find():
    img, d = canvas()
    d.ellipse([4, 3, 20, 19], fill=(200, 230, 255, 255), outline=K, width=2)
    d.line([18, 17, 28, 28], fill=(120, 80, 20, 255), width=4)
    d.line([8, 8, 11, 6], fill=W)
    return img


def ic_run():
    img, d = canvas()
    box(d, 2, 5, 25, 24)
    d.rectangle([4, 7, 23, 10], fill=NAVY)
    d.rectangle([4, 12, 23, 22], fill=W)
    d.polygon([(15, 18), (24, 18), (24, 15), (30, 20), (24, 25), (24, 22), (15, 22)], fill=BLUE, outline=K)
    return img


def ic_app():
    img, d = canvas()
    box(d, 2, 4, 29, 27)
    d.rectangle([4, 6, 27, 9], fill=NAVY)
    d.rectangle([4, 11, 27, 25], fill=W)
    d.rectangle([7, 14, 14, 21], fill=SKY, outline=DG)
    return img


def ic_image():
    img, d = canvas()
    d.rectangle([3, 5, 28, 26], fill=W, outline=K)
    d.rectangle([5, 7, 26, 24], fill=SKY)
    d.polygon([(5, 24), (11, 14), (16, 21), (20, 16), (26, 24)], fill=DGRN)
    d.ellipse([19, 8, 23, 12], fill=YEL)
    return img


def ic_moon():
    img, d = canvas()
    d.rectangle([0, 0, 31, 31], fill=(0, 0, 90, 255))
    d.ellipse([5, 4, 27, 26], fill=YEL)
    d.ellipse([10, 1, 32, 23], fill=(0, 0, 90, 255))
    for (x, y) in [(22, 20), (26, 12), (9, 27)]:
        d.rectangle([x, y, x + 1, y + 1], fill=W)
    return img


def ic_speaker():
    img, d = canvas()
    d.polygon([(4, 12), (11, 12), (18, 6), (18, 26), (11, 20), (4, 20)], fill=G, outline=K)
    d.arc([14, 10, 26, 22], -50, 50, fill=K, width=2)
    d.arc([14, 5, 30, 27], -50, 50, fill=K, width=2)
    return img


def ic_programs():
    img = ic_folder()
    d = ImageDraw.Draw(img)
    d.rectangle([14, 14, 25, 23], fill=W, outline=K)
    d.rectangle([15, 15, 24, 17], fill=NAVY)
    return img


def ic_documents():
    img = ic_folder()
    d = ImageDraw.Draw(img)
    d.rectangle([15, 12, 24, 23], fill=W, outline=K)
    for y in (15, 18, 21):
        d.line([17, y, 22, y], fill=DG)
    return img


def ic_shutdown():
    img = ic_computer()
    d = ImageDraw.Draw(img)
    d.ellipse([22, 20, 30, 28], fill=RED, outline=K)
    d.line([26, 21, 26, 25], fill=W, width=1)
    return img


def ic_user():
    img, d = canvas()
    d.ellipse([10, 3, 21, 14], fill=(255, 210, 170, 255), outline=K)
    d.pieslice([4, 15, 27, 40], 180, 360, fill=(60, 90, 200, 255), outline=K)
    return img


def ic_modem():
    img, d = canvas()
    box(d, 2, 12, 29, 25)
    for i, x in enumerate((6, 10, 14, 18)):
        d.rectangle([x, 17, x + 1, 18], fill=(GRN if i < 2 else DRED))
    d.line([22, 18, 26, 18], fill=DG)
    return img


ICONS_32 = {
    "computer": ic_computer, "folder": ic_folder, "folder_open": lambda: ic_folder(True),
    "doc": ic_doc, "notepad": ic_notepad, "paint": ic_paint, "calc": ic_calc, "dos": ic_dos,
    "globe": ic_globe, "mail": ic_mail, "inbox": ic_inbox, "mine": ic_mine,
    "trash": ic_trash, "trash_full": lambda: ic_trash(True), "network": ic_network,
    "cam": ic_cam, "gate": ic_gate, "drive_hd": lambda: ic_drive("hd"),
    "drive_floppy": lambda: ic_drive("floppy"), "drive_cd": lambda: ic_drive("cd"),
    "control": ic_control, "clock": ic_clock, "info": lambda: ic_round((0, 0, 200, 255), "i", W, 22),
    "warn": ic_warn, "error": ic_error, "question": ic_help, "settings": ic_gear,
    "find": ic_find, "run": ic_run, "app": ic_app, "image": ic_image, "moon": ic_moon,
    "speaker": ic_speaker, "programs": ic_programs, "documents": ic_documents,
    "shutdown": ic_shutdown, "user": ic_user, "modem": ic_modem, "help": ic_help,
}


# -------------------------------------------------------------- toolbar glyphs
def tb_canvas():
    return canvas(32)


def tb_back(flip=False):
    img, d = tb_canvas()
    d.polygon([(4, 16), (15, 5), (15, 11), (28, 11), (28, 21), (15, 21), (15, 27)], fill=(60, 180, 60, 255), outline=K)
    return img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img


def tb_stop():
    img, d = tb_canvas()
    pts = [(10, 3), (22, 3), (29, 10), (29, 22), (22, 29), (10, 29), (3, 22), (3, 10)]
    outline_poly(d, pts, RED)
    glyph(img, "X", (16, 16), 18, W)
    return img


def tb_refresh():
    img, d = tb_canvas()
    d.arc([5, 5, 27, 27], 30, 330, fill=(40, 120, 40, 255), width=4)
    d.polygon([(21, 2), (30, 9), (19, 11)], fill=(40, 120, 40, 255), outline=K)
    return img


def tb_home():
    img, d = tb_canvas()
    d.polygon([(16, 3), (30, 16), (2, 16)], fill=(200, 60, 40, 255), outline=K)
    d.rectangle([6, 16, 26, 28], fill=CREAM, outline=K)
    d.rectangle([13, 20, 19, 28], fill=(120, 70, 30, 255), outline=K)
    return img


def tb_search():
    return ic_find()


def tb_star():
    img, d = tb_canvas()
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 14 if i % 2 == 0 else 6
        pts.append((16 + r * math.cos(a), 17 + r * math.sin(a)))
    outline_poly(d, pts, YEL)
    return img


def tb_print():
    img, d = tb_canvas()
    d.rectangle([9, 3, 23, 11], fill=W, outline=K)
    box(d, 3, 11, 28, 23)
    d.rectangle([8, 18, 23, 28], fill=W, outline=K)
    d.line([10, 22, 21, 22], fill=DG)
    return img


TOOLBAR = {"back": tb_back, "forward": lambda: tb_back(True), "stop": tb_stop, "refresh": tb_refresh,
           "home": tb_home, "search": tb_search, "star": tb_star, "print": tb_print}


# ----------------------------------------------------------------- paint tools
def pt_pencil():
    img, d = canvas()
    d.polygon([(24, 3), (29, 8), (10, 27), (4, 28), (5, 22)], fill=YEL, outline=K)
    d.polygon([(4, 28), (5, 22), (10, 27)], fill=(240, 200, 150, 255), outline=K)
    d.line([24, 3, 29, 8], fill=K, width=2)
    return img


def pt_brush():
    img, d = canvas()
    d.line([26, 4, 12, 18], fill=(150, 90, 30, 255), width=4)
    d.polygon([(13, 15), (18, 20), (8, 29), (3, 28), (4, 23)], fill=K)
    return img


def pt_eraser():
    img, d = canvas()
    outline_poly(d, [(4, 20), (16, 7), (28, 15), (16, 28)], (255, 150, 170, 255))
    d.polygon([(4, 20), (10, 24), (16, 28), (10, 17)], fill=W, outline=K)
    return img


def pt_fill():
    img, d = canvas()
    outline_poly(d, [(6, 14), (16, 4), (26, 14), (16, 24)], W)
    d.polygon([(6, 14), (16, 24), (26, 14), (16, 18)], fill=BLUE)
    d.ellipse([24, 20, 28, 28], fill=BLUE)
    d.rectangle([24, 22, 28, 28], fill=BLUE)
    return img


def pt_spray():
    img, d = canvas()
    box(d, 5, 12, 14, 29)
    d.rectangle([7, 7, 12, 11], fill=DG, outline=K)
    for (x, y) in [(18, 8), (22, 5), (24, 11), (20, 14), (27, 8), (26, 16), (22, 9)]:
        d.rectangle([x, y, x + 1, y + 1], fill=K)
    return img


def pt_line():
    img, d = canvas()
    d.line([4, 28, 28, 4], fill=K, width=3)
    return img


def pt_rect():
    img, d = canvas()
    d.rectangle([4, 7, 28, 25], outline=K, width=3)
    return img


def pt_ellipse():
    img, d = canvas()
    d.ellipse([3, 6, 29, 26], outline=K, width=3)
    return img


def pt_pick():
    img, d = canvas()
    d.line([8, 24, 22, 10], fill=DG, width=5)
    d.polygon([(21, 4), (28, 11), (24, 15), (17, 8)], fill=K)
    d.polygon([(4, 29), (6, 24), (9, 27)], fill=K)
    return img


PAINT = {"pencil": pt_pencil, "brush": pt_brush, "eraser": pt_eraser, "fill": pt_fill, "spray": pt_spray,
         "line": pt_line, "rect": pt_rect, "ellipse": pt_ellipse, "pick": pt_pick}


# ------------------------------------------------------------------- web art
def vgrad(w, h, top, bot):
    t = np.linspace(0, 1, h)[:, None, None]
    a = (np.array(top)[None, None, :] * (1 - t) + np.array(bot)[None, None, :] * t)
    return Image.fromarray(np.repeat(a, w, axis=1).astype(np.uint8), "RGB")


def web_banner():
    img = Image.new("RGB", (468, 60), (10, 20, 40))
    d = ImageDraw.Draw(img)
    for i in range(0, 468, 6):
        d.line([i, 0, i - 30, 60], fill=(16, 32, 64))
    d.rectangle([0, 0, 467, 59], outline=(90, 140, 220))
    d.rectangle([2, 2, 465, 57], outline=(40, 70, 130))
    d.text((18, 8), "NIGHTWATCH", font=ImageFont.truetype(LIB_B, 26), fill=(255, 220, 90))
    d.text((218, 17), "SECURITY SYSTEMS", font=ImageFont.truetype(LIB_B, 18), fill=(255, 255, 255))
    d.text((20, 40), "Somebody is always watching the lot.", font=ImageFont.truetype(LIB_R, 12), fill=(150, 190, 255))
    d.ellipse([410, 10, 450, 50], outline=(255, 220, 90), width=3)
    d.ellipse([421, 21, 439, 39], fill=(255, 220, 90))
    d.ellipse([427, 27, 433, 33], fill=(10, 20, 40))
    return img


def web_construction():
    img = Image.new("RGBA", (96, 84), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(48, 2), (94, 70), (2, 70)], fill=(255, 210, 0, 255), outline=K)
    d.polygon([(48, 12), (84, 66), (12, 66)], outline=K)
    for i in range(6):
        d.line([20 + i * 12, 66, 28 + i * 12, 54], fill=K, width=3)
    d.ellipse([42, 28, 54, 40], fill=K)
    d.polygon([(40, 52), (56, 52), (52, 40), (44, 40)], fill=K)
    d.rectangle([44, 72, 52, 82], fill=(150, 90, 30, 255))
    d.rectangle([20, 74, 76, 80], fill=(150, 90, 30, 255))
    return img


def web_rainbow():
    img = Image.new("RGB", (480, 6))
    px = img.load()
    cols = [(255, 0, 0), (255, 140, 0), (255, 255, 0), (0, 200, 0), (0, 100, 255), (150, 0, 200)]
    for x in range(480):
        c = cols[(x // 4) % 6]
        for y in range(6):
            px[x, y] = c if (y % 2 == 0) else tuple(int(v * 0.65) for v in c)
    return img


def web_button(text, bg, fg=(255, 255, 255)):
    img = Image.new("RGB", (88, 31), bg)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 87, 30], outline=(255, 255, 255))
    d.rectangle([1, 1, 86, 29], outline=(0, 0, 0))
    lines = text.split("\n")
    f = ImageFont.truetype(LIB_B, 10)
    y = 15 - len(lines) * 6
    for ln in lines:
        d.text((44, y + 6), ln, font=f, fill=fg, anchor="mm")
        y += 12
    return img


def web_masthead():
    img = Image.new("RGB", (560, 72), (240, 236, 224))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 559, 71], outline=(0, 0, 0))
    d.rectangle([3, 3, 556, 68], outline=(0, 0, 0))
    d.text((280, 34), "The Ashford Gazette", font=ImageFont.truetype(SERIF_B, 44), fill=(10, 10, 10), anchor="mm")
    d.text((280, 60), "SERVING ASHFORD COUNTY SINCE 1923", font=ImageFont.truetype(SERIF_R, 10), fill=(40, 40, 40), anchor="mm")
    return img


def noise(img, amount, seed):
    r = np.random.default_rng(seed)
    a = np.array(img).astype(np.int16)
    a += r.normal(0, amount, a.shape).astype(np.int16)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def web_lot_photo(figure=False, seed=3):
    """A murky night photo of the car park, quantised to 16 colours like a scanned GIF."""
    w, h = 320, 200
    base = vgrad(w, h, (4, 6, 14), (10, 12, 18))
    d = ImageDraw.Draw(base)
    # ground
    d.rectangle([0, 120, w, h], fill=(14, 14, 16))
    # bay lines
    for i in range(-2, 9):
        d.line([i * 50 + 20, 200, i * 30 + 120, 122], fill=(60, 60, 56), width=2)
    # fence + trees
    for x in range(0, w, 7):
        d.line([x, 100, x, 124], fill=(30, 32, 36))
    d.line([0, 104, w, 104], fill=(40, 42, 46))
    d.line([0, 120, w, 120], fill=(40, 42, 46))
    for (x, r) in [(20, 28), (70, 36), (240, 40), (290, 30)]:
        d.ellipse([x - r, 70 - r // 2, x + r, 110], fill=(4, 8, 6))
    # cars
    for (x, y, cw) in [(40, 150, 70), (210, 140, 80)]:
        d.rounded_rectangle([x, y, x + cw, y + 22], radius=6, fill=(18, 20, 28))
        d.polygon([(x + 12, y), (x + 20, y - 14), (x + cw - 22, y - 14), (x + cw - 10, y)], fill=(14, 16, 22))
    # lamp
    d.rectangle([155, 40, 158, 125], fill=(24, 24, 26))
    d.line([158, 40, 172, 40], fill=(24, 24, 26), width=3)
    glow = Image.new("RGB", (w, h), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r in range(110, 0, -3):
        k = (1 - r / 110) ** 2
        gd.ellipse([172 - r, 44 - r, 172 + r, 44 + r], fill=(int(255 * k), int(160 * k), int(50 * k)))
    base = Image.fromarray(np.clip(np.array(base).astype(np.int16) + np.array(glow).astype(np.int16) * 0.55, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(base)
    d.ellipse([168, 38, 176, 46], fill=(255, 230, 170))
    if figure:
        d.ellipse([264, 112, 270, 118], fill=(30, 30, 34))
        d.rectangle([263, 118, 271, 140], fill=(26, 26, 30))
        d.line([263, 140, 262, 150], fill=(26, 26, 30), width=2)
        d.line([271, 140, 272, 150], fill=(26, 26, 30), width=2)
    base = base.filter(ImageFilter.GaussianBlur(0.8))
    base = noise(base, 9, seed)
    return base.quantize(16, dither=Image.FLOYDSTEINBERG).convert("RGB")


def save_web(name, img):
    img.save(os.path.join(WEB, name + ".png"))


def main():
    for name, fn in ICONS_32.items():
        img = fn()
        img.save(os.path.join(ICONS, name + ".png"))
        small(img, 16).save(os.path.join(ICONS, name + "_16.png"))
    for name, fn in TOOLBAR.items():
        img = fn()
        small(img, 24).save(os.path.join(ICONS, "tb_" + name + ".png"))
    for name, fn in PAINT.items():
        small(fn(), 16).save(os.path.join(ICONS, "pt_" + name + ".png"))

    save_web("banner_nws", web_banner())
    save_web("construction", web_construction())
    save_web("rainbow", web_rainbow())
    save_web("btn_nightnet", web_button("Best viewed with\nNightNet 1.0", (0, 0, 128)))
    save_web("btn_800", web_button("Optimised for\n640 x 480", (128, 0, 0)))
    save_web("btn_ring", web_button("Night Owls\nWeb Ring", (0, 90, 60)))
    save_web("masthead", web_masthead())
    save_web("lot_photo", web_lot_photo(False, 3))
    save_web("lot_photo2", web_lot_photo(True, 7))
    print("done:", len(os.listdir(ICONS)), "icons,", len(os.listdir(WEB)), "web images")


if __name__ == "__main__":
    main()
