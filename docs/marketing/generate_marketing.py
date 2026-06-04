#!/usr/bin/env python3
"""Generate PunctoDock marketing images (hero + feature graphic) with Pillow.

Palette is taken from the app logo: warm cream/ivory + charcoal. Copy is written in
plain, simple language (friendly for everyone, including non-technical users) while
keeping a light sales tone. Type is SF Pro for readability.

Outputs (next to this script):
    hero.png       1280x640  — GitHub social-preview / README banner
    features.png   1280x520  — three plain-language benefits
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ICON = os.path.join(HERE, "..", "app-icon.png")

# ── Palette (from the logo) ──────────────────────────────────────────────────
CREAM_TOP    = (245, 243, 237)
CREAM_BOTTOM = (232, 229, 220)
CHARCOAL     = (51, 50, 47)      # headlines
WARM_GRAY    = (107, 103, 94)    # body text
MUTED        = (140, 135, 124)   # footer
CARD         = (255, 255, 255)
ACCENTS      = [(60, 60, 58), (154, 146, 129), (196, 189, 173)]  # charcoal, taupe, stone

# ── Fonts (SF Pro variable font, fall back to Arial) ─────────────────────────
def font(size, bold=False):
    try:
        f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
        try:
            f.set_variation_by_name("Bold" if bold else "Regular")
        except Exception:
            pass
        return f
    except Exception:
        p = ("/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold
             else "/System/Library/Fonts/Supplemental/Arial.ttf")
        return ImageFont.truetype(p, size)

# ── Helpers ──────────────────────────────────────────────────────────────────
def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

def text_w(d, s, f):
    b = d.textbbox((0, 0), s, font=f)
    return b[2] - b[0]

def vgradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(top, bottom, y / max(1, h - 1)))
    return img

def drop_shadow(rgba, blur=30, alpha=70, offset=(0, 16)):
    a = rgba.split()[3]
    sh = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    sh.paste(Image.new("RGBA", rgba.size, (40, 39, 36, alpha)), (0, 0), a)
    return sh.filter(ImageFilter.GaussianBlur(blur)), offset

def card_with_shadow(bg, box, radius, fill, blur=20, alpha=46, dy=12):
    x0, y0, x1, y1 = box
    sh = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x0, y0 + dy, x1, y1 + dy], radius=radius,
                                         fill=(60, 58, 54, alpha))
    bg.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))
    ImageDraw.Draw(bg).rounded_rectangle(box, radius=radius, fill=fill)

# ── Hero ──────────────────────────────────────────────────────────────────────
def build_hero():
    W, H = 1280, 640
    bg = vgradient(W, H, CREAM_TOP, CREAM_BOTTOM).convert("RGBA")

    # Logo (already transparent + shaped) with a soft warm shadow so the light
    # neumorphic art lifts off the cream background.
    icon = Image.open(ICON).convert("RGBA").resize((384, 384), Image.LANCZOS)
    ix, iy = 116, (H - 384) // 2
    sh, (ox, oy) = drop_shadow(icon, blur=34, alpha=85, offset=(0, 20))
    bg.alpha_composite(sh, (ix + ox, iy + oy))
    bg.alpha_composite(icon, (ix, iy))

    d = ImageDraw.Draw(bg)
    tx = 560
    d.text((tx, 206), "PunctoDock", font=font(100, bold=True), fill=CHARCOAL)
    d.multiline_text((tx, 330),
                     "Symbols, emoji, and the things you copied —\nright where you type.",
                     font=font(35), fill=WARM_GRAY, spacing=10)
    d.text((tx, 452), "Made for your Mac   ·   Always private   ·   No internet",
           font=font(23), fill=MUTED)

    out = os.path.join(HERE, "hero.png")
    bg.convert("RGB").save(out)
    print("wrote", out)

# ── Features ───────────────────────────────────────────────────────────────────
def build_features():
    W, H = 1280, 470
    bg = vgradient(W, H, CREAM_TOP, CREAM_BOTTOM).convert("RGBA")
    d = ImageDraw.Draw(bg)
    d.text((64, 46), "Why you'll love it", font=font(42, bold=True), fill=CHARCOAL)

    cards = [
        ("Type it anywhere",
         "Drop in symbols, signs and\nemoji right where you type.\nNo copy and paste."),
        ("All your copies",
         "See what you copied before —\ntext and pictures. Pick one\nto paste it again."),
        ("Yours and private",
         "Everything stays on your Mac.\nNo internet, no tracking,\nno sign-up."),
    ]
    gap, mx, top = 30, 64, 150
    cw = (W - mx * 2 - gap * 2) // 3
    ch = 252
    for i, (title, body) in enumerate(cards):
        x = mx + i * (cw + gap)
        card_with_shadow(bg, [x, top, x + cw, top + ch], 24, CARD)
        d.rounded_rectangle([x + 30, top + 30, x + 30 + 50, top + 30 + 10],
                            radius=5, fill=ACCENTS[i])
        d.text((x + 30, top + 58), title, font=font(31, bold=True), fill=CHARCOAL)
        d.multiline_text((x + 30, top + 112), body, font=font(22), fill=WARM_GRAY,
                         spacing=9)

    out = os.path.join(HERE, "features.png")
    bg.convert("RGB").save(out)
    print("wrote", out)

# ── Panel preview (faithful mock of the real window) ────────────────────────────
def build_panel():
    """A clean preview of the floating window: same layout and tabs as the real app
    (Clipboard / Symbols / Emoji) with simple, friendly sample copies. Saved to
    ../screenshot-panel.png. Transparent background + soft shadow so it sits well in
    the README on any theme."""
    W, H = 792, 940
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # Panel with soft shadow.
    px0, py0, px1, py1 = 48, 40, W - 48, H - 56
    radius = 30
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([px0, py0 + 16, px1, py1 + 16], radius=radius,
                                         fill=(20, 20, 22, 150))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(28)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([px0, py0, px1, py1], radius=radius, fill=(28, 28, 31, 255))
    d.rounded_rectangle([px0, py0, px1, py1], radius=radius, outline=(255, 255, 255, 26), width=2)

    # Tab bar
    tabs = ["Clipboard", "Symbols", "Emoji"]
    tb_y0, tb_h = py0 + 24, 64
    seg_w = (px1 - px0 - 40) / 3
    tf = font(28, bold=True)
    for i, label in enumerate(tabs):
        cx = px0 + 20 + seg_w * (i + 0.5)
        if i == 0:  # active
            d.rounded_rectangle([px0 + 20 + i * seg_w + 6, tb_y0,
                                 px0 + 20 + (i + 1) * seg_w - 6, tb_y0 + tb_h],
                                radius=16, fill=(58, 58, 62, 255))
        w = text_w(d, label, tf)
        d.text((cx - w / 2, tb_y0 + 16), label, font=tf,
               fill=(245, 245, 245) if i == 0 else (150, 150, 155))

    # Clipboard rows
    rows = [
        "Everything stays on your Mac",
        "It remembers your pictures too",
        "Symbols and emoji, one click away",
        "Hello world",
    ]
    rf = font(26)
    ry = tb_y0 + tb_h + 22
    row_h, gap = 96, 14
    for text in rows:
        d.rounded_rectangle([px0 + 22, ry, px1 - 22, ry + row_h], radius=16,
                            fill=(42, 42, 46, 255))
        # wrap to 2 lines if long
        d.text((px0 + 44, ry + row_h / 2 - 16), text, font=rf, fill=(232, 232, 234))
        d.text((px1 - 70, ry + row_h / 2 - 20), "•••", font=font(22), fill=(140, 140, 145))
        ry += row_h + gap

    out = os.path.join(HERE, "..", "screenshot-panel.png")
    img.save(out)
    print("wrote", os.path.normpath(out))

if __name__ == "__main__":
    build_hero()
    build_features()
    build_panel()
