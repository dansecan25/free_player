"""Generates every app icon: a pink pair of beamed music notes on white, over a
faded portrait (scripts/icon-art.jpg).

Run from the free_music_player folder:  python3 scripts/generate_app_icons.py
Needs Pillow (pip install pillow). Edit the shapes or colors here and run it
again instead of editing the PNGs. Without icon-art.jpg the background is plain
white.
"""

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

APP_DIR = Path(__file__).resolve().parent.parent
ANDROID_RES = APP_DIR / "android/app/src/main/res"
IOS_ICONSET = APP_DIR / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
MACOS_ICONSET = APP_DIR / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
WEB_DIR = APP_DIR / "web"
WINDOWS_ICO = APP_DIR / "windows/runner/resources/app_icon.ico"
DOCS_ICON = APP_DIR / "docs/app-icon.png"
ART = APP_DIR / "scripts/icon-art.jpg"

# Square crop of the artwork (left, top, side) in its own pixels, centered on the face.
ART_CROP = (60, 90, 600)
ART_STRENGTH = 0.40  # 0 = plain white, 1 = the artwork at full strength

WHITE = (255, 255, 255, 255)
HAIR_PINK = (0xF4, 0xAB, 0xD5, 255)  # also AppTheme.seed
SHADOW_PINK = (0xB0, 0x5E, 0x8E, 255)  # the hair's shadow tone, used as linework
SHINE = (255, 255, 255, 150)
CLEAR = (0, 0, 0, 0)

FULL_COLOR = {"bg": WHITE, "fill": HAIR_PINK, "line": SHADOW_PINK, "shine": SHINE}
# Android 13 themed icons tint one silhouette.
MONOCHROME = {"bg": CLEAR, "fill": WHITE, "line": WHITE, "shine": None}

SUPERSAMPLE = 4
LEGACY_SCALE = 0.36    # glyph scale as a fraction of the canvas
ADAPTIVE_SCALE = 0.27  # adaptive foregrounds must stay inside the central 66dp of 108dp
MASKABLE_SCALE = 0.30  # web maskable icons keep a 10% safe margin

ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def note_shapes():
    """Polygons for ♫ in unit coordinates (about -1..1, y down)."""

    def head(cx, cy, rx=0.27, ry=0.19, tilt=-22):
        angle = math.radians(tilt)
        return [
            (cx + rx * math.cos(t) * math.cos(angle) - ry * math.sin(t) * math.sin(angle),
             cy + rx * math.cos(t) * math.sin(angle) + ry * math.sin(t) * math.cos(angle))
            for t in (2 * math.pi * i / 64 for i in range(64))
        ]

    def rect(x0, y0, x1, y1):
        return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]

    stem = 0.13
    left_stem_x, right_stem_x = -0.17, 0.66
    return [
        head(-0.42, 0.56),
        head(0.41, 0.40),
        rect(left_stem_x - stem, -0.52, left_stem_x, 0.54),
        rect(right_stem_x - stem, -0.70, right_stem_x, 0.38),
        # Beam, rising to the right.
        [(left_stem_x - stem, -0.46), (right_stem_x, -0.66),
         (right_stem_x, -0.90), (left_stem_x - stem, -0.70)],
    ]


def draw_glyph(image, scale, colors):
    size = image.width
    unit = size * scale
    cx, cy = size / 2 + 0.01 * unit, size / 2 + 0.08 * unit  # center the glyph's bounds
    draw = ImageDraw.Draw(image)

    def to_canvas(points):
        return [(cx + x * unit, cy + y * unit) for x, y in points]

    shapes = [to_canvas(shape) for shape in note_shapes()]
    line = max(1, round(0.10 * unit))
    # Centered strokes on every shape first, then the fills on top, so only
    # the outer edge of the combined shape shows the darker line.
    for shape in shapes:
        draw.line(shape + shape[:1], fill=colors["line"], width=line, joint="curve")
        radius = line / 2
        for x, y in shape:
            draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=colors["line"])
    for shape in shapes:
        draw.polygon(shape, fill=colors["fill"])

    if colors["shine"]:
        # Drawn on its own layer: ImageDraw replaces pixels instead of blending.
        layer = Image.new("RGBA", image.size, CLEAR)
        shine = ImageDraw.Draw(layer)
        for hx, hy in ((-0.50, 0.50), (0.33, 0.34)):
            x, y = cx + hx * unit, cy + hy * unit
            shine.ellipse([x - 0.08 * unit, y - 0.045 * unit, x + 0.08 * unit, y + 0.045 * unit],
                          fill=colors["shine"])
        image.alpha_composite(layer)


def faded_art(size, zoom=1.0):
    """The cropped artwork blended toward white, or plain white without it.

    zoom > 1 shows more around the crop, for layers the launcher masks."""
    if not ART.exists():
        return Image.new("RGBA", (size, size), WHITE)
    left, top, side = ART_CROP
    art = Image.open(ART).convert("RGB")
    grow = side * (zoom - 1) / 2
    box = (left - grow, top - grow, left + side + grow, top + side + grow)
    # Areas past the artwork's edges are white, like its own background.
    padded = Image.new("RGB", (art.width + 2 * side, art.height + 2 * side), "white")
    padded.paste(art, (side, side))
    crop = padded.crop(tuple(round(v + side) for v in box)).resize((size, size), Image.LANCZOS)
    white = Image.new("RGB", (size, size), "white")
    return Image.blend(white, crop, ART_STRENGTH).convert("RGBA")


def render(size, scale, colors, background=None, art_zoom=1.0):
    """Renders larger and scales down, for smooth edges at every size."""
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), CLEAR)
    inset = big * 0.04
    border = {"outline": (0xEE, 0xD7, 0xE5, 255), "width": max(1, big // 96)}
    if background:
        mask = Image.new("L", (big, big), 0)
        shape = ImageDraw.Draw(mask)
        if background == "square":
            shape.rectangle([0, 0, big, big], fill=255)
        elif background == "rounded":
            shape.rounded_rectangle([inset, inset, big - inset, big - inset],
                                    radius=big * 0.22, fill=255)
        elif background == "circle":
            shape.ellipse([inset, inset, big - inset, big - inset], fill=255)
        fill = faded_art(big, art_zoom) if colors is FULL_COLOR else colors["bg"]
        if isinstance(fill, tuple):
            fill = Image.new("RGBA", (big, big), fill)
        image.paste(fill, (0, 0), mask)
        draw = ImageDraw.Draw(image)
        if background == "rounded":
            draw.rounded_rectangle([inset, inset, big - inset, big - inset],
                                   radius=big * 0.22, **border)
        elif background == "circle":
            draw.ellipse([inset, inset, big - inset, big - inset], **border)
    if scale:
        draw_glyph(image, scale, colors)
    return image.resize((size, size), Image.LANCZOS)


def write_android():
    for density, factor in ANDROID_DENSITIES.items():
        folder = ANDROID_RES / f"mipmap-{density}"
        folder.mkdir(exist_ok=True)
        legacy, adaptive = round(48 * factor), round(108 * factor)
        render(legacy, LEGACY_SCALE, FULL_COLOR, "rounded").save(folder / "ic_launcher.png")
        render(legacy, LEGACY_SCALE, FULL_COLOR, "circle").save(folder / "ic_launcher_round.png")
        render(adaptive, ADAPTIVE_SCALE, FULL_COLOR).save(folder / "ic_launcher_foreground.png")
        # The launcher shows only the middle 72dp of the 108dp layer, so the crop is widened
        # to keep the same framing as the other icons.
        render(adaptive, 0, FULL_COLOR, "square", art_zoom=108 / 72).convert("RGB").save(
            folder / "ic_launcher_background.png")
        render(adaptive, ADAPTIVE_SCALE, MONOCHROME).save(folder / "ic_launcher_monochrome.png")

    (ANDROID_RES / "values/ic_launcher_background.xml").unlink(missing_ok=True)
    adaptive_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        '</adaptive-icon>\n'
    )
    anydpi = ANDROID_RES / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (anydpi / name).write_text(adaptive_xml)


def write_iconset(iconset, rounded):
    """Fills an Xcode icon set using the file names in its Contents.json."""
    contents = json.loads((iconset / "Contents.json").read_text())
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        pixels = round(points * int(entry["scale"].rstrip("x")))
        image = render(pixels, LEGACY_SCALE, FULL_COLOR, "rounded" if rounded else "square")
        # iOS rounds corners itself and rejects icons with transparency.
        (image if rounded else image.convert("RGB")).save(iconset / entry["filename"])


def write_web():
    render(16, LEGACY_SCALE, FULL_COLOR, "rounded").save(WEB_DIR / "favicon.png")
    for size in (192, 512):
        render(size, LEGACY_SCALE, FULL_COLOR, "square").convert("RGB").save(
            WEB_DIR / f"icons/Icon-{size}.png")
        render(size, MASKABLE_SCALE, FULL_COLOR, "square").save(
            WEB_DIR / f"icons/Icon-maskable-{size}.png")


def write_windows():
    render(256, LEGACY_SCALE, FULL_COLOR, "rounded").save(
        WINDOWS_ICO, sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])


if __name__ == "__main__":
    write_android()
    write_iconset(IOS_ICONSET, rounded=False)
    write_iconset(MACOS_ICONSET, rounded=True)
    write_web()
    write_windows()
    DOCS_ICON.parent.mkdir(exist_ok=True)
    render(512, LEGACY_SCALE, FULL_COLOR, "rounded").save(DOCS_ICON)
    print("Icons written.")
