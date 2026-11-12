"""
Makes the in-game addon icon (../Icons/logo.tga, 64x64) from the high-res logo
(logo.png, next to this script), for the AddOns list (## IconTexture in the .toc files).

The list shows the icon at about 20 px, so the logo is simplified: the hanger and
armor only (no "CC" letters), on a plain tile in the badge's colors (dark purple
inside a purple rim).

Usage:  python make_icon.py [preview_png]      (needs Pillow: pip install pillow)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Icons", "logo.tga")
ART = (225, 160, 1035, 790)   # hanger + armor, in logo.png pixels (1254x1254)
INNER = (29, 4, 45)           # badge fill
RIM = (128, 44, 182)          # badge rim
WORK = 1024                   # tile size before the downscale
RIM_WIDTH = 0.075             # rim width, fraction of the tile
CORNER = 0.16                 # corner radius, fraction of the tile
ART_WIDTH = 0.80              # width of the hanger + armor, fraction of the tile


def finish(img):
    """Downscale to 64x64 and restore some contrast and edge sharpness lost in the shrink."""
    icon = img.resize((64, 64), Image.LANCZOS)
    icon = ImageEnhance.Contrast(icon).enhance(1.1)
    return icon.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))


def main():
    logo = Image.open(os.path.join(HERE, "logo.png")).convert("RGB")

    # The hanger (gold) and armor (cream) are the bright parts; the purple rim is darker.
    # Grow the shape a little to keep their dark outline.
    art = logo.crop(ART)
    shape = art.convert("L").point(lambda v: 255 if v > 110 else 0)
    mask = shape.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(2))

    # The tile: rim, then the dark inside.
    tile = Image.new("RGB", (WORK, WORK), (0, 0, 0))
    draw = ImageDraw.Draw(tile)
    draw.rounded_rectangle((0, 0, WORK - 1, WORK - 1), radius=int(WORK * CORNER), fill=RIM)
    inset = int(WORK * RIM_WIDTH)
    draw.rounded_rectangle((inset, inset, WORK - 1 - inset, WORK - 1 - inset),
                           radius=int(WORK * (CORNER - RIM_WIDTH)), fill=INNER)

    # Hanger + armor, centered.
    scale = WORK * ART_WIDTH / art.width
    size = (int(art.width * scale), int(art.height * scale))
    art, mask = art.resize(size, Image.LANCZOS), mask.resize(size, Image.LANCZOS)
    tile.paste(art, ((WORK - size[0]) // 2, (WORK - size[1]) // 2), mask)

    # Transparent outside the rounded corners.
    alpha = Image.new("L", (WORK, WORK), 0)
    ImageDraw.Draw(alpha).rounded_rectangle((0, 0, WORK - 1, WORK - 1), radius=int(WORK * CORNER), fill=255)
    icon = finish(tile).convert("RGBA")
    icon.putalpha(alpha.resize((64, 64), Image.LANCZOS))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.save(OUT)
    print("wrote", os.path.normpath(OUT))
    if len(sys.argv) > 1:
        icon.resize((256, 256), Image.NEAREST).save(sys.argv[1])


if __name__ == "__main__":
    main()
