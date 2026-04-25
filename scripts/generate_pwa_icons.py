"""Generate simple PWA icons (green bolt on dark background) at several sizes."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "charging-log" / "icons"
OUT.mkdir(parents=True, exist_ok=True)

BG = (24, 27, 34, 255)       # --surface
BOLT = (76, 195, 138, 255)   # --accent

# Normalized bolt polygon (0..1 coordinate space)
BOLT_POINTS = [
    (0.55, 0.08),
    (0.20, 0.52),
    (0.44, 0.52),
    (0.35, 0.92),
    (0.78, 0.40),
    (0.50, 0.40),
    (0.62, 0.08),
]


def make(size: int, path: Path, radius_ratio: float = 0.20) -> None:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    r = int(size * radius_ratio)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=r, fill=BG)
    pts = [(int(x * size), int(y * size)) for (x, y) in BOLT_POINTS]
    draw.polygon(pts, fill=BOLT)
    img.save(path, "PNG")
    print(f"  → {path.name}")


if __name__ == "__main__":
    for sz in (192, 512):
        make(sz, OUT / f"icon-{sz}.png")
    make(180, OUT / "apple-touch-icon.png", radius_ratio=0.0)
    make(32, OUT / "favicon-32.png", radius_ratio=0.0)
    print("Done.")
