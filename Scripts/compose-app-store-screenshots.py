#!/usr/bin/env python3
"""Composites App Store marketing screenshots from raw simulator captures.

Each output is drawn on a canvas whose pixel size is exactly what App Store
Connect requires for that device class, so nothing is ever rescaled on upload.
The raw capture is the real app; everything around it (background, device
bezel, caption) is marketing chrome.

Captions are written for OCR: since Apple began indexing screenshot text in
June 2025, each slide carries a short, high-contrast, keyword-bearing line
rather than a clever one. Keep them 3-7 words.

    Scripts/compose-app-store-screenshots.py

Reads  Docs/AppStoreScreenshots/raw/<device-class>/
Writes Docs/AppStoreScreenshots/final/<device-class>/
"""

from __future__ import annotations

import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO_ROOT = Path(__file__).resolve().parent.parent
SCREENSHOT_ROOT = REPO_ROOT / "Docs" / "AppStoreScreenshots"
RAW_ROOT = SCREENSHOT_ROOT / "raw"
FINAL_ROOT = SCREENSHOT_ROOT / "final"

# Brand anchor: the app's AccentColor asset, which is also CheatSheetPalette.blue.
BRAND = (0x4B, 0x88, 0xFF)
GRADIENT_TOP = (0x0F, 0x1A, 0x30)
GRADIENT_BOTTOM = (0x04, 0x07, 0x0D)
HEADLINE_COLOR = (0xFF, 0xFF, 0xFF)
SUBHEAD_COLOR = (0xC2, 0xD5, 0xF2)
BEZEL_COLOR = (0x12, 0x13, 0x16)
BEZEL_EDGE = (0x3A, 0x42, 0x55)


@dataclass(frozen=True)
class Slot:
    """One screenshot in the narrative.

    `headline` is the line the store indexes and the eye reads first;
    `subhead` adds a second keyword pass without crowding the headline.
    """

    key: str
    headline: str
    subhead: str


SLOTS: dict[str, Slot] = {
    slot.key: slot
    for slot in [
        Slot(
            "hero",
            "Save The Commands You Forget",
            "Code snippets, always one tap away",
        ),
        Slot(
            "widget",
            "Pin Notes To Your Home Screen",
            "The widget keeps one note in view",
        ),
        Slot(
            "list",
            "A Cheat Sheet For Every Tool",
            "Git, Docker, Vim, Xcode, HTTP codes",
        ),
        Slot(
            "checklist",
            "Turn Notes Into Checklists",
            "Check off release steps as you ship",
        ),
        Slot(
            "style",
            "Ten Colors, Four Code Fonts",
            "Monospace, rounded, serif, or system",
        ),
        Slot(
            "search",
            "Search Every Note Instantly",
            "Light and dark mode included",
        ),
        Slot(
            "light",
            "Light Mode And Dark Mode",
            "Follows your system appearance",
        ),
        Slot(
            "open-source",
            "Free, Offline, Open Source",
            "No account, no ads, no tracking",
        ),
    ]
}


@dataclass(frozen=True)
class DeviceClass:
    """A device class and the exact canvas App Store Connect expects for it."""

    name: str
    canvas: tuple[int, int]
    order: list[str]
    headline_size: int
    subhead_size: int
    screen_width_ratio: float
    device_top_ratio: float
    side_margin_ratio: float
    top_margin_ratio: float
    # Display corner rounding, as a fraction of screen width. iPads round far
    # less than iPhones; overshooting here clips the status bar.
    screen_radius_ratio: float


DEVICE_CLASSES = [
    DeviceClass(
        name="iphone-6.9",
        canvas=(1320, 2868),
        order=["hero", "widget", "list", "checklist", "style", "search", "open-source"],
        headline_size=100,
        subhead_size=46,
        screen_width_ratio=0.88,
        device_top_ratio=0.230,
        side_margin_ratio=0.075,
        top_margin_ratio=0.050,
        screen_radius_ratio=0.085,
    ),
    DeviceClass(
        name="ipad-13",
        canvas=(2064, 2752),
        order=["hero", "checklist", "style", "light", "open-source"],
        headline_size=132,
        subhead_size=60,
        screen_width_ratio=0.82,
        device_top_ratio=0.225,
        side_margin_ratio=0.075,
        top_margin_ratio=0.050,
        screen_radius_ratio=0.035,
    ),
]

# Raw capture filenames are the narrative slots they were shot for.
RAW_FILENAMES = {
    "hero": "01-hero.png",
    "widget": "02-widget.png",
    "list": "03-list.png",
    "checklist": "04-checklist.png",
    "style": "05-style.png",
    "search": "06-search.png",
    "light": "06-light.png",
    "open-source": "07-open-source.png",
}

FONT_CANDIDATES = [
    ("/System/Library/Fonts/SFNS.ttf", True),
    ("/System/Library/Fonts/HelveticaNeue.ttc", False),
    ("/Library/Fonts/Arial.ttf", False),
]


def load_font(size: int, bold: bool) -> ImageFont.FreeTypeFont:
    """San Francisco where available, with graceful fallbacks."""
    for path, variable in FONT_CANDIDATES:
        if not Path(path).exists():
            continue
        try:
            font = ImageFont.truetype(path, size)
        except OSError:
            continue
        if variable:
            try:
                font.set_variation_by_name("Bold" if bold else "Regular")
            except (OSError, AttributeError):
                pass
        return font
    return ImageFont.load_default(size)


def background(size: tuple[int, int]) -> Image.Image:
    """One gradient plus one brand glow, reused across the whole set.

    The glow sits behind the device rather than behind the caption: it lifts
    the dark screenshot off the background while leaving the headline on the
    darkest ground, which is what keeps the text legible at thumbnail size.
    """
    width, height = size
    canvas = Image.new("RGB", size, GRADIENT_BOTTOM)
    draw = ImageDraw.Draw(canvas)

    for y in range(height):
        blend = y / max(height - 1, 1)
        # Ease the gradient so the top stays rich instead of washing out.
        eased = blend ** 0.85
        draw.line(
            [(0, y), (width, y)],
            fill=tuple(
                round(top + (bottom - top) * eased)
                for top, bottom in zip(GRADIENT_TOP, GRADIENT_BOTTOM)
            ),
        )

    glow = Image.new("L", size, 0)
    radius = int(width * 0.62)
    center = (width // 2, int(height * 0.45))
    ImageDraw.Draw(glow).ellipse(
        [center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius],
        fill=115,
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius * 0.45))
    canvas.paste(Image.new("RGB", size, BRAND), (0, 0), glow)
    return canvas


def wrap(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""

    for word in words:
        candidate = f"{current} {word}".strip()
        if font.getlength(candidate) <= max_width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word

    if current:
        lines.append(current)
    return lines


def wrap_balanced(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    """Wraps to the same line count as a greedy wrap, but with even lines.

    Greedy wrapping leaves orphans — "A Cheat Sheet For Every / Tool" — which
    look like a mistake at store size. Narrowing the measure to the tightest
    width that still fits the same number of lines balances them.
    """
    lines = wrap(text, font, max_width)
    if len(lines) < 2:
        return lines

    target = len(lines)
    low, high = 1, max_width
    best = lines

    while low < high:
        middle = (low + high) // 2
        candidate = wrap(text, font, middle)
        if len(candidate) <= target and max(font.getlength(l) for l in candidate) <= max_width:
            best = candidate
            high = middle
        else:
            low = middle + 1

    return best


def fit_headline(
    text: str, size: int, max_width: int, max_lines: int = 2
) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    """Shrinks the headline until it fits in `max_lines`, then balances it."""
    for candidate_size in (size, size - 8, size - 16, size - 24):
        font = load_font(candidate_size, bold=True)
        lines = wrap_balanced(text, font, max_width)
        if len(lines) <= max_lines:
            return font, lines

    font = load_font(size - 24, bold=True)
    return font, wrap_balanced(text, font, max_width)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return mask


def draw_device(canvas: Image.Image, capture: Image.Image, spec: DeviceClass) -> int:
    """Places the capture inside a bezel, bleeding off the bottom edge.

    Returns the top edge of the device so the caption can be centred in the
    space above it. The bleed is deliberate: it crops the empty tail of a
    mostly-scrolled screen and makes the device read as larger than the canvas.
    """
    canvas_width, canvas_height = canvas.size
    screen_width = round(canvas_width * spec.screen_width_ratio)
    scale = screen_width / capture.width
    screen_height = round(capture.height * scale)

    bezel = max(round(canvas_width * 0.014), 10)
    screen_radius = round(screen_width * spec.screen_radius_ratio)
    body_radius = screen_radius + bezel

    body_width = screen_width + bezel * 2
    body_height = screen_height + bezel * 2
    body_x = (canvas_width - body_width) // 2
    body_y = round(canvas_height * spec.device_top_ratio)

    shadow = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [body_x, body_y + bezel * 2, body_x + body_width, body_y + body_height + bezel * 4],
        body_radius,
        fill=170,
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(bezel * 2.5))
    canvas.paste(Image.new("RGB", canvas.size, (0, 0, 0)), (0, 0), shadow)

    body = Image.new("RGB", (body_width, body_height), BEZEL_COLOR)
    ImageDraw.Draw(body).rounded_rectangle(
        [0, 0, body_width - 1, body_height - 1],
        body_radius,
        outline=BEZEL_EDGE,
        width=max(bezel // 5, 2),
    )
    canvas.paste(body, (body_x, body_y), rounded_mask((body_width, body_height), body_radius))

    screen = capture.resize((screen_width, screen_height), Image.LANCZOS).convert("RGB")
    canvas.paste(
        screen,
        (body_x + bezel, body_y + bezel),
        rounded_mask((screen_width, screen_height), screen_radius),
    )

    return body_y


def compose(spec: DeviceClass, slot: Slot, capture_path: Path, destination: Path) -> None:
    canvas = background(spec.canvas)
    capture = Image.open(capture_path)

    if capture.size != spec.canvas:
        raise SystemExit(
            f"{capture_path} is {capture.size}, expected {spec.canvas} for {spec.name}"
        )

    device_top = draw_device(canvas, capture, spec)

    canvas_width, canvas_height = spec.canvas
    margin = round(canvas_width * spec.side_margin_ratio)
    text_width = canvas_width - margin * 2

    headline_font, headline_lines = fit_headline(slot.headline, spec.headline_size, text_width)
    subhead_font = load_font(spec.subhead_size, bold=False)
    subhead_lines = wrap_balanced(slot.subhead, subhead_font, text_width)

    headline_leading = round(headline_font.size * 1.08)
    subhead_leading = round(spec.subhead_size * 1.24)
    gap = round(spec.headline_size * 0.34)

    block_height = (
        len(headline_lines) * headline_leading + gap + len(subhead_lines) * subhead_leading
    )

    # Centre the caption in the band above the device so one- and two-line
    # headlines both sit optically right, with no dead gap under the text.
    band_top = round(canvas_height * spec.top_margin_ratio)
    band_bottom = device_top - round(canvas_height * 0.035)
    y = band_top + max((band_bottom - band_top - block_height) // 2, 0)

    draw = ImageDraw.Draw(canvas)
    for line in headline_lines:
        draw.text((canvas_width // 2, y), line, font=headline_font, fill=HEADLINE_COLOR, anchor="ma")
        y += headline_leading

    y += gap
    for line in subhead_lines:
        draw.text((canvas_width // 2, y), line, font=subhead_font, fill=SUBHEAD_COLOR, anchor="ma")
        y += subhead_leading

    destination.parent.mkdir(parents=True, exist_ok=True)
    # Flatten to RGB: App Store Connect rejects any alpha channel.
    canvas.convert("RGB").save(destination, "PNG")


def main() -> int:
    missing: list[str] = []

    for spec in DEVICE_CLASSES:
        raw_dir = RAW_ROOT / spec.name
        if not raw_dir.is_dir():
            missing.append(f"{spec.name}: no raw captures at {raw_dir}")
            continue

        for key in spec.order:
            capture_path = raw_dir / RAW_FILENAMES[key]
            if not capture_path.exists():
                missing.append(f"{spec.name}: missing {capture_path.name}")

    if missing:
        for note in missing:
            print(f"error — {note}", file=sys.stderr)
        print("Existing final screenshots were left unchanged.", file=sys.stderr)
        return 1

    FINAL_ROOT.parent.mkdir(parents=True, exist_ok=True)
    staging_root = Path(tempfile.mkdtemp(prefix=".final-", dir=FINAL_ROOT.parent))
    produced = 0

    try:
        for spec in DEVICE_CLASSES:
            raw_dir = RAW_ROOT / spec.name
            destination_dir = staging_root / spec.name

            for position, key in enumerate(spec.order, start=1):
                capture_path = raw_dir / RAW_FILENAMES[key]
                destination = destination_dir / f"{position:02d}-{key}.png"
                compose(spec, SLOTS[key], capture_path, destination)
                print(f"{FINAL_ROOT.relative_to(REPO_ROOT)}/{spec.name}/{destination.name}")
                produced += 1

        if FINAL_ROOT.exists():
            shutil.rmtree(FINAL_ROOT)
        staging_root.rename(FINAL_ROOT)
    finally:
        if staging_root.exists():
            shutil.rmtree(staging_root)

    print(f"\n{produced} screenshots written to {FINAL_ROOT.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
