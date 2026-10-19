#!/usr/bin/env python3
"""Make every VIDORA app icon file from one square logo image.

    python3 packaging/vidora/make_icons.py [logo.png] [--small small-logo.png]

logo.png: the full icon artwork, square, ideally 1024 px or larger, transparent where the icon
should be see-through. --small: an optional simpler drawing for 16-32 px (taskbar, title bar),
where fine detail turns to mush. Without a logo the script draws VIDORA's placeholder icon (a
navy-to-blue tile with a white V and film-strip edges).

The files keep FilmCraft's names (assets/app-icon/filmcraft*.{png,ico,icns,svg} and the hicolor
PNGs), because the build and packaging scripts look for those names; only their pictures change.
Needs Pillow (pip install pillow).
"""
import base64
import io
import pathlib
import sys

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
DIR = ROOT / "assets/app-icon"
APP_ID = "ai.storyteller.filmcraft"
NAVY, BLUE = (10, 26, 63), (29, 78, 216)


_PLACEHOLDER = {}


def placeholder(size, detailed=True):
    """VIDORA's placeholder icon: rounded navy-to-blue tile, white V, film-strip perforations."""
    if detailed not in _PLACEHOLDER:
        _PLACEHOLDER[detailed] = _draw_placeholder(detailed)
    return _PLACEHOLDER[detailed].resize((size, size), Image.LANCZOS)


def _draw_placeholder(detailed):
    s = 2048
    column = Image.new("RGBA", (1, s))
    for y in range(s):
        t = y / (s - 1)
        column.putpixel((0, y), tuple(round(NAVY[i] + (BLUE[i] - NAVY[i]) * t) for i in range(3)) + (255,))
    grad = column.resize((s, s))
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s - 1, s - 1), radius=int(s * 0.22), fill=255)
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    if detailed:
        # film-strip perforations along the top and bottom edges
        hole_w, hole_h, gap = s * 0.075, s * 0.055, s * 0.045
        n = 7
        total = n * hole_w + (n - 1) * gap
        x0 = (s - total) / 2
        for row_y in (s * 0.085, s - s * 0.085 - hole_h):
            for i in range(n):
                x = x0 + i * (hole_w + gap)
                d.rounded_rectangle((x, row_y, x + hole_w, row_y + hole_h), radius=hole_h * 0.3, fill=(255, 255, 255, 90))
    # the V: a chevron whose arms are thick strokes
    top, bottom = s * (0.24 if detailed else 0.2), s * (0.76 if detailed else 0.8)
    left, right, arm = s * (0.22 if detailed else 0.16), s * (0.78 if detailed else 0.84), s * (0.17 if detailed else 0.22)
    mid = s / 2
    d.polygon(
        [(left, top), (left + arm, top), (mid, bottom - arm * 1.15), (right - arm, top), (right, top), (mid + arm * 0.42, bottom), (mid - arm * 0.42, bottom)],
        fill=(255, 255, 255, 255),
    )
    return img


def from_logo(logo, size):
    return logo.resize((size, size), Image.LANCZOS)


def svg_wrapping(png_img, size=512):
    buf = io.BytesIO()
    png_img.resize((size, size), Image.LANCZOS).save(buf, "PNG")
    data = base64.b64encode(buf.getvalue()).decode()
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{size}" height="{size}" viewBox="0 0 {size} {size}">'
        f'<image width="{size}" height="{size}" xlink:href="data:image/png;base64,{data}"/></svg>\n'
    )


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    small_path = argv[argv.index("--small") + 1] if "--small" in argv else None
    if small_path in args:
        args.remove(small_path)
    logo = Image.open(args[0]).convert("RGBA") if args else None
    small = Image.open(small_path).convert("RGBA") if small_path else None

    def icon(size):
        if size <= 32:
            if small is not None:
                return from_logo(small, size)
            if logo is None:
                return placeholder(size, detailed=False)
        return from_logo(logo, size) if logo is not None else placeholder(size)

    big = icon(1024)
    big.save(DIR / "filmcraft-1024.png")
    # macOS: Apple's grid puts the 824 px tile body inside a transparent 1024 px canvas
    mac = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    mac.paste(icon(824), (100, 100))
    mac.resize((512, 512), Image.LANCZOS).save(DIR / "filmcraft-macos-512.png")
    mac.save(DIR / "filmcraft.icns", sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])
    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    frames = [icon(n) for n in ico_sizes]
    frames[-1].save(DIR / "filmcraft.ico", sizes=[(n, n) for n in ico_sizes], append_images=frames[:-1])
    for n in (16, 24, 32, 48, 64, 128, 256, 512):
        out = DIR / f"hicolor/{n}x{n}/apps/{APP_ID}.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        icon(n).save(out)
    (DIR / f"hicolor/scalable/apps/{APP_ID}.svg").write_text(svg_wrapping(big))
    (DIR / "filmcraft.svg").write_text(svg_wrapping(big))
    (DIR / "filmcraft-small.svg").write_text(svg_wrapping(icon(32), 32))
    web = ROOT / "apps/filmcraft-web/web/favicon.png"
    if web.parent.exists():
        icon(128).save(web)
    print("icons written to", DIR)


if __name__ == "__main__":
    main(sys.argv[1:])
