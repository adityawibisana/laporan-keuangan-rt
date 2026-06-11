"""Compose Play Store marketing screenshots (1080x1920, 9:16) from raw device captures.

Crops the cluttered system status/nav bars off each raw screenshot, rounds the
corners, drops a soft shadow, and places it on a brand-teal gradient canvas with
an Indonesian headline + subtitle. Output is Play-Store-ready PNGs.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "screenshots")
OUT = os.path.join(ROOT, "screenshots", "playstore")
os.makedirs(OUT, exist_ok=True)

W, H = 1080, 1920
# Brand teal gradient (matches the in-app saldo hero: #26A69A -> #00695C)
TOP = (0x23, 0xA1, 0x93)
BOT = (0x00, 0x4D, 0x43)

FONT_DIR = "C:/Windows/Fonts"
F_BOLD = os.path.join(FONT_DIR, "segoeuib.ttf")
F_REG = os.path.join(FONT_DIR, "segoeui.ttf")

# Raw device captures are 720x1600. Trim the OS status bar (top) and the
# gesture/nav bar (bottom) so only the app's own UI shows.
CROP_TOP = 70
CROP_BOT = 96

SHOTS = [
    ("raw_id_top.png", "Laporan Keuangan RT", "Pantau saldo kas warga setiap bulan"),
    ("raw_id_rincian.png", "Pemasukan & Pengeluaran", "Tercatat rinci, jelas, dan transparan"),
    ("raw_en_top.png", "Riwayat Tiap Bulan", "Geser untuk melihat laporan bulan lain"),
    ("raw_en.png", "Dwibahasa", "Tersedia dalam Bahasa Indonesia & English"),
    ("raw_en_rincian.png", "Rincian Per Pos", "Lihat alokasi tiap kategori anggaran"),
]


def gradient(w, h, top, bot):
    base = Image.new("RGB", (w, h), top)
    draw = ImageDraw.Draw(base)
    for y in range(h):
        t = y / (h - 1)
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    return base


def rounded(img, radius):
    """Return img (RGBA) with rounded corners."""
    img = img.convert("RGBA")
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius, fill=255)
    img.putalpha(mask)
    return img


def wrap(draw, text, font, max_w):
    words = text.split()
    lines, cur = [], ""
    for word in words:
        trial = (cur + " " + word).strip()
        if draw.textlength(trial, font=font) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def compose(raw_name, headline, subtitle, out_name):
    canvas = gradient(W, H, TOP, BOT)
    draw = ImageDraw.Draw(canvas)

    # --- Headline + subtitle ---
    f_head = ImageFont.truetype(F_BOLD, 64)
    f_sub = ImageFont.truetype(F_REG, 36)
    margin = 80
    y = 110
    for line in wrap(draw, headline, f_head, W - 2 * margin):
        draw.text((margin, y), line, font=f_head, fill=(255, 255, 255))
        y += 78
    y += 6
    for line in wrap(draw, subtitle, f_sub, W - 2 * margin):
        draw.text((margin, y), line, font=f_sub, fill=(255, 255, 255, 230))
        y += 48

    # --- Phone screenshot ---
    raw = Image.open(os.path.join(RAW, raw_name)).convert("RGB")
    rw, rh = raw.size
    raw = raw.crop((0, CROP_TOP, rw, rh - CROP_BOT))

    target_w = 760
    scale = target_w / raw.size[0]
    target_h = int(raw.size[1] * scale)
    raw = raw.resize((target_w, target_h), Image.LANCZOS)
    card = rounded(raw, 44)

    px = (W - target_w) // 2
    py = 470
    # bleed off the bottom edge if too tall
    if py + target_h > H - 30:
        card = card.crop((0, 0, target_w, H - 30 - py))

    # soft drop shadow
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([px, py + 18, px + target_w, py + card.size[1] + 18], 44, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    canvas = canvas.convert("RGBA")
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(card, (px, py))

    canvas.convert("RGB").save(os.path.join(OUT, out_name), "PNG")
    print("wrote", out_name)


for i, (raw_name, head, sub) in enumerate(SHOTS, 1):
    compose(raw_name, head, sub, f"{i:02d}_{raw_name.replace('raw_', '').replace('.png','')}.png")

print("done ->", OUT)
