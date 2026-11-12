# Adds a crossed-out ".ru" badge to the TrustTunnel launcher icons (Android).
# Uses the system-wide Pillow (no installs). Run once; idempotency is not guaranteed
# (re-running doubles the badge) - regenerate from git if needed.
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RES = Path(r"D:\ytprofile\projects\AI_projects\trusttunnel\TrustTunnelFlutterClient\android\app\src\main\res")
RED = (210, 47, 47, 255)  # badge background
WHITE = (255, 255, 255, 255)
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\segoeuib.ttf",
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\arial.ttf",
]


def load_font(px: int) -> ImageFont.FreeTypeFont:
    for candidate in FONT_CANDIDATES:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, px)
    raise RuntimeError("No font found")


def draw_badge(image: Image.Image, center: tuple[float, float], diameter: float) -> Image.Image:
    """Draws a red circle with white '.ru' text and a strikethrough (bg-colored line)."""
    image = image.copy()
    draw = ImageDraw.Draw(image)
    cx, cy = center
    r = diameter / 2

    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=RED)

    text = ".ru"
    font = load_font(int(diameter * 0.52))
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    text_w, text_h = right - left, bottom - top
    tx = cx - text_w / 2 - left
    ty = cy - text_h / 2 - top
    draw.text((tx, ty), text, font=font, fill=WHITE)

    # Strikethrough: badge-colored line across the text middle (visible only over the glyphs),
    # slightly wider than the text.
    line_w = max(2, int(diameter * 0.045))
    strike_y = cy - text_h * 0.08
    draw.line((cx - text_w / 2 - diameter * 0.04, strike_y, cx + text_w / 2 + diameter * 0.04, strike_y), fill=RED, width=line_w)

    return image


def process_legacy(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    w = image.width
    # Keep the badge inside the round mask: center at 0.56*R toward the corner.
    center = (w * 0.5 + w * 0.5 * 0.56 * 0.7071, w * 0.5 + w * 0.5 * 0.56 * 0.7071)
    diameter = w * 0.42
    draw_badge(image, center, diameter).save(path, lossless=True)


def process_foreground(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    w = image.width
    # Adaptive foreground: safe zone is the central 66/108 circle; badge at its bottom-right edge.
    safe_r = w * 66 / 108 / 2
    center = (w / 2 + safe_r * 0.58 * 0.7071, w / 2 + safe_r * 0.58 * 0.7071)
    diameter = safe_r * 0.78
    draw_badge(image, center, diameter).save(path, lossless=True)


for density in ["ldpi", "mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
    folder = RES / f"mipmap-{density}"
    process_legacy(folder / "ic_launcher.webp")
    process_legacy(folder / "ic_launcher_round.webp")
    foreground = folder / "ic_launcher_foreground.webp"
    if foreground.exists():
        process_foreground(foreground)
    print(f"done {density}")

print("all icons updated")
