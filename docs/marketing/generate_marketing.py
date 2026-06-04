#!/usr/bin/env python3
"""Generate PunctoDock marketing images (hero + feature graphic) with Pillow.

Outputs (next to this script):
    hero.png       1280x640  — GitHub social-preview / README banner
    features.png   1280x460  — three-up feature highlights

Reproducible: re-run after changing copy or colors.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ICON = os.path.join(HERE, "..", "app-icon.png")

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

def vgradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(top, bottom, y / max(1, h - 1)))
    return img

def blob(size, color, radius, alpha):
    """A soft circular glow on a transparent layer."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = size[0] // 2, size[1] // 2
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
              fill=color + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.45))

def drop_shadow(rgba, blur=24, alpha=120, offset=(0, 14)):
    a = rgba.split()[3]
    sh = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    black = Image.new("RGBA", rgba.size, (0, 0, 0, alpha))
    sh.paste(black, (0, 0), a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    return sh, offset

def text_w(d, s, f):
    b = d.textbbox((0, 0), s, font=f)
    return b[2] - b[0]

# ── Hero ──────────────────────────────────────────────────────────────────────
def build_hero():
    W, H = 1280, 640
    bg = vgradient(W, H, (44, 36, 86), (28, 23, 56)).convert("RGBA")
    bg.alpha_composite(blob((W, H), (124, 92, 255), 360, 90), (-120, 120))
    bg.alpha_composite(blob((W, H), (92, 140, 255), 300, 70), (760, -160))

    # App icon, left, with soft shadow.
    icon = Image.open(ICON).convert("RGBA").resize((360, 360), Image.LANCZOS)
    ix, iy = 120, (H - 360) // 2
    sh, (ox, oy) = drop_shadow(icon, blur=30, alpha=140, offset=(0, 18))
    bg.alpha_composite(sh, (ix + ox, iy + oy))
    bg.alpha_composite(icon, (ix, iy))

    d = ImageDraw.Draw(bg)
    tx = 560
    d.text((tx, 196), "PunctoDock", font=font(98, bold=True), fill=(255, 255, 255))
    d.multiline_text((tx, 312),
                     "Punctuation, symbols & clipboard —\none keystroke away.",
                     font=font(36), fill=(222, 216, 244), spacing=10)

    # Shortcut pill "⌥ V"
    pill_font = font(30, bold=True)
    label = "⌥ V"
    pad_x, pad_y = 26, 14
    tw = text_w(d, label, pill_font)
    py = 452
    d.rounded_rectangle([tx, py, tx + tw + pad_x * 2, py + 56], radius=28,
                        fill=(124, 92, 255))
    d.text((tx + pad_x, py + pad_y - 2), label, font=pill_font, fill=(255, 255, 255))

    d.text((tx, 552), "macOS 26  ·  100% local  ·  no telemetry",
           font=font(23), fill=(176, 168, 208))

    out = os.path.join(HERE, "hero.png")
    bg.convert("RGB").save(out)
    print("wrote", out)

# ── Features ───────────────────────────────────────────────────────────────────
def build_features():
    W, H = 1280, 460
    bg = vgradient(W, H, (32, 27, 62), (24, 20, 48)).convert("RGBA")
    d = ImageDraw.Draw(bg)

    d.text((64, 48), "Why PunctoDock", font=font(40, bold=True), fill=(255, 255, 255))

    cards = [
        ((124, 92, 255), "Insert anywhere",
         "Punctuation, symbols and\nemoji land right at your\ncursor — no copy-paste."),
        ((92, 140, 255), "Clipboard history",
         "Recent text and images,\npinnable, pasteable into\nany app you like."),
        ((86, 200, 160), "100% local",
         "No cloud, no telemetry,\nno account. Your data\nstays on your Mac."),
    ]
    gap, mx, top = 28, 64, 150
    cw = (W - mx * 2 - gap * 2) // 3
    ch = 250
    for i, (accent, title, body) in enumerate(cards):
        x = mx + i * (cw + gap)
        # Solid card a touch lighter than the background so light text stays readable.
        d.rounded_rectangle([x, top, x + cw, top + ch], radius=22, fill=(48, 42, 86))
        d.rounded_rectangle([x + 28, top + 28, x + 28 + 46, top + 28 + 10],
                            radius=5, fill=accent)
        d.text((x + 28, top + 52), title, font=font(30, bold=True),
               fill=(255, 255, 255))
        d.multiline_text((x + 28, top + 102), body, font=font(22),
                         fill=(206, 200, 230), spacing=8)

    out = os.path.join(HERE, "features.png")
    bg.convert("RGB").save(out)
    print("wrote", out)

if __name__ == "__main__":
    build_hero()
    build_features()
