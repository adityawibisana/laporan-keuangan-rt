"""Generate the master app icon (1024x1024) for RT3 RW21.

Concept: a neighborhood treasury. A teal brand gradient (the app's saldo-hero
colours) with a white "coin" carrying the Rupiah mark, capped by a small house
roof to signal the RT/RW community. Also emits a 432x432 foreground (transparent)
for Android 8+ adaptive icons and a flat 1024 for the Play Store hi-res icon.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icon")
os.makedirs(OUT, exist_ok=True)

TOP = (0x2B, 0xB0, 0xA1)
BOT = (0x00, 0x5A, 0x4E)
WHITE = (255, 255, 255)
ROBOTO_BOLD = os.path.join(ROOT, "fonts", "RobotoMono-Bold.ttf")


def diagonal_gradient(size, top, bot):
    w = h = size
    base = Image.new("RGB", (w, h), top)
    px = base.load()
    for y in range(h):
        for x in range(w):
            t = (x + y) / (w + h - 2)
            px[x, y] = (
                int(top[0] + (bot[0] - top[0]) * t),
                int(top[1] + (bot[1] - top[1]) * t),
                int(top[2] + (bot[2] - top[2]) * t),
            )
    return base


def draw_glyph(img, cx, cy, scale=1.0):
    """A white coin carrying the Rupiah mark, centred on (cx, cy)."""
    d = ImageDraw.Draw(img)

    # Coin — white disc with a subtle teal inner ring (the milled edge).
    coin_r = int(300 * scale)
    d.ellipse([cx - coin_r, cy - coin_r, cx + coin_r, cy + coin_r], fill=WHITE)
    ring_r = int(252 * scale)
    d.ellipse([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
              outline=BOT, width=max(2, int(10 * scale)))

    # Rp mark in the app's money font, teal.
    f = ImageFont.truetype(ROBOTO_BOLD, int(248 * scale))
    text = "Rp"
    tb = d.textbbox((0, 0), text, font=f)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    tx = cx - tw // 2 - tb[0]
    ty = cy - th // 2 - tb[1]
    d.text((tx, ty), text, font=f, fill=BOT)


def make_full(size=1024, rounded=True):
    img = diagonal_gradient(size, TOP, BOT).convert("RGBA")
    draw_glyph(img, size // 2, size // 2, scale=size / 1024)
    if rounded:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, size, size], int(size * 0.22), fill=255)
        img.putalpha(mask)
    return img


# 1) Master square (full bleed, sharp corners) — used by flutter_launcher_icons.
master = make_full(1024, rounded=False)
master.convert("RGB").save(os.path.join(OUT, "icon.png"))

# 2) Adaptive foreground (transparent, glyph inset to survive the safe-zone mask).
fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
draw_glyph(fg, 512, 512, scale=0.74)
fg.save(os.path.join(OUT, "icon_foreground.png"))

# 3) Rounded preview for the Play Store hi-res listing icon.
make_full(512, rounded=True).save(os.path.join(OUT, "icon_play_512.png"))

print("wrote icons ->", OUT)
