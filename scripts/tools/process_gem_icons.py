from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ICON_DIR = Path(__file__).resolve().parents[2] / "assets" / "ui" / "gem_icons"
SENTINEL = (255, 0, 255)


def remove_connected_dark_background(path: Path) -> None:
    source = Image.open(path).convert("RGB")
    working = source.copy()
    width, height = working.size
    points = []
    step = max(16, min(width, height) // 20)
    for x in range(0, width, step):
        points.extend(((x, 0), (x, height - 1)))
    for y in range(0, height, step):
        points.extend(((0, y), (width - 1, y)))

    for point in points:
        pixel = working.getpixel(point)
        if pixel != SENTINEL and max(pixel) < 105:
            ImageDraw.floodfill(working, point, SENTINEL, thresh=72)

    alpha = Image.new("L", working.size, 255)
    alpha_pixels = alpha.load()
    working_pixels = working.load()
    for y in range(height):
        for x in range(width):
            if working_pixels[x, y] == SENTINEL:
                alpha_pixels[x, y] = 0

    alpha = alpha.filter(ImageFilter.GaussianBlur(1.15))
    result = source.convert("RGBA")
    result.putalpha(alpha)
    result.save(path, "PNG", optimize=True)

    inventory = result.resize((152, 152), Image.Resampling.LANCZOS)
    inventory.save(path.with_name(path.stem + "_inventory.png"), "PNG", optimize=True)


def main() -> None:
    for path in sorted(ICON_DIR.glob("*.png")):
        if not path.stem.endswith("_inventory"):
            remove_connected_dark_background(path)
            print(path.name)


if __name__ == "__main__":
    main()
