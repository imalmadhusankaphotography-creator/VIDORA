#!/usr/bin/env python3
"""Make VIDORA's app icons and wordmarks from Imal Madhusanka's logo.

    python3 packaging/vidora/make_logo_assets.py

Reads packaging/vidora/logo/vidora-logo.png (the V-and-play symbol on black, as designed) and
writes:
  packaging/vidora/logo/vidora-icon.png         1024 px app icon: the symbol on a rounded black tile
  packaging/vidora/logo/vidora-icon-small.png   the same, cropped tighter for 16-32 px icons
  assets/app-icon/vidora-wordmark-light.png     tile + "VIDORA", light lettering (for dark themes)
  assets/app-icon/vidora-wordmark-dark.png      tile + "VIDORA", dark lettering (for light themes)
and then every app icon file (packaging/vidora/make_icons.py).
Needs Pillow and numpy.
"""
import pathlib
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = ROOT / "packaging/vidora"
LOGO = HERE / "logo/vidora-logo.png"
FONT = ROOT / "assets/fonts/Inter-Bold.ttf"


def symbol_box(img, threshold=12):
    """Bounding box (left, top, right, bottom) of the lit symbol on its black background."""
    a = np.asarray(img.convert("RGB")).astype(int).max(axis=2)
    ys, xs = np.where(a > threshold)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def tile(img, fill, size):
    """A rounded square `size` px wide: the logo cropped so the symbol fills `fill` of its width,
    centred, on the logo's own black, with see-through rounded corners."""
    l, t, r, b = symbol_box(img)
    side = max(r - l, b - t) / fill
    cx, cy = (l + r) / 2, (t + b) / 2
    box = (cx - side / 2, cy - side / 2, cx + side / 2, cy + side / 2)
    # pad with black where the crop runs past the image
    pad = int(side)
    canvas = Image.new("RGB", (img.width + 2 * pad, img.height + 2 * pad), (0, 0, 0))
    canvas.paste(img.convert("RGB"), (pad, pad))
    crop = canvas.crop(tuple(round(v + pad) for v in box)).resize((size * 2, size * 2), Image.LANCZOS)
    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, crop.width - 1, crop.height - 1), radius=int(crop.width * 0.22), fill=255)
    out = crop.convert("RGBA")
    out.putalpha(mask)
    return out.resize((size, size), Image.LANCZOS)


def gradient_text(text, height, colors, tracking=0.08):
    """`text` in Inter Bold with capitals `height` px tall, filled with a left-to-right gradient
    through `colors`, on transparency."""
    font = ImageFont.truetype(str(FONT), int(height / 0.727))  # Inter's cap height is 0.727 em
    widths = [font.getlength(ch) for ch in text]
    gap = height * tracking
    w = int(sum(widths) + gap * (len(text) - 1)) + 4
    top = font.getbbox("V")[1]
    mask = Image.new("L", (w, int(height) + 4), 0)
    d = ImageDraw.Draw(mask)
    x = 0.0
    for ch, cw in zip(text, widths):
        d.text((x, -top), ch, font=font, fill=255)
        x += cw + gap
    grad = Image.new("RGBA", (w, 1))
    stops = len(colors) - 1
    for i in range(w):
        t = i / max(w - 1, 1) * stops
        k = min(int(t), stops - 1)
        f = t - k
        c0, c1 = colors[k], colors[k + 1]
        grad.putpixel((i, 0), tuple(round(c0[j] + (c1[j] - c0[j]) * f) for j in range(3)) + (255,))
    grad = grad.resize(mask.size)
    grad.putalpha(ImageChops.multiply(grad.getchannel("A"), mask))
    return grad


def wordmark(img, colors, height=256):
    icon = tile(img, 0.8, height)
    text = gradient_text("VIDORA", height * 0.46, colors)
    gap = int(height * 0.22)
    out = Image.new("RGBA", (icon.width + gap + text.width, height), (0, 0, 0, 0))
    out.alpha_composite(icon, (0, 0))
    out.alpha_composite(text, (icon.width + gap, (height - text.height) // 2 + 2))
    return out


def main():
    logo = Image.open(LOGO).convert("RGB")
    big = tile(logo, 0.74, 1024)
    small = tile(logo, 0.9, 256)
    big.save(HERE / "logo/vidora-icon.png")
    small.save(HERE / "logo/vidora-icon-small.png")
    # light lettering for dark themes: pale cyan to lavender, like the symbol's highlights
    wordmark(logo, [(186, 236, 255), (150, 190, 255), (222, 206, 255)]).save(ROOT / "assets/app-icon/vidora-wordmark-light.png")
    # dark lettering for light themes: the symbol's deep blue to violet
    wordmark(logo, [(10, 70, 210), (20, 40, 160), (88, 40, 200)]).save(ROOT / "assets/app-icon/vidora-wordmark-dark.png")
    sys.path.insert(0, str(HERE))
    import make_icons  # noqa: E402

    make_icons.main([str(HERE / "logo/vidora-icon.png"), "--small", str(HERE / "logo/vidora-icon-small.png")])


if __name__ == "__main__":
    main()
