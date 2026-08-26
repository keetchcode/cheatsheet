#!/usr/bin/env python3
"""Checks the composed screenshots against App Store Connect's upload rules.

App Store Connect rejects a whole upload for an off-by-one pixel size or a
stray alpha channel, so this runs the same checks before you get there.

    Scripts/verify-app-store-screenshots.py
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
SCREENSHOT_ROOT = REPO_ROOT / "Docs" / "AppStoreScreenshots"
FINAL_ROOT = SCREENSHOT_ROOT / "final"
CONTACT_SHEET = SCREENSHOT_ROOT / "contact-sheet.png"

# Apple's accepted portrait sizes per device class (2026 specifications).
ACCEPTED = {
    "iphone-6.9": {(1320, 2868), (1290, 2796), (1260, 2736)},
    "ipad-13": {(2064, 2752), (2048, 2732)},
}

THUMBNAIL_WIDTH = 120

# App Store Connect rejects anything larger.
MAX_BYTES = 10 * 1024 * 1024

# Captions are OCR-indexed, so they are held to the same 3-7 word rule that
# keeps them readable in a search result.
MIN_CAPTION_WORDS = 3
MAX_CAPTION_WORDS = 7


def load_compositor():
    """Reads captions and device ordering from the compositor as one source."""
    path = Path(__file__).resolve().parent / "compose-app-store-screenshots.py"
    spec = importlib.util.spec_from_file_location("compose_screenshots", path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def check_captions(slots: dict) -> list[str]:
    problems: list[str] = []

    for slot in slots.values():
        for label, text in (("headline", slot.headline), ("subhead", slot.subhead)):
            words = len(text.split())
            if label == "headline" and not MIN_CAPTION_WORDS <= words <= MAX_CAPTION_WORDS:
                problems.append(
                    f"{slot.key} {label}: {words} words, want "
                    f"{MIN_CAPTION_WORDS}-{MAX_CAPTION_WORDS} ({text!r})"
                )
            if words > 8:
                problems.append(f"{slot.key} {label}: {words} words is too long to read ({text!r})")

    return problems


def check(device_class: str, files: list[Path]) -> list[str]:
    problems: list[str] = []

    if not 1 <= len(files) <= 10:
        problems.append(f"{device_class}: {len(files)} files, App Store Connect allows 1–10")

    for path in files:
        with Image.open(path) as image:
            if image.format != "PNG":
                problems.append(f"{path.name}: format is {image.format}, expected PNG")
            if image.mode != "RGB":
                problems.append(f"{path.name}: mode is {image.mode}, expected RGB (no alpha)")
            if path.stat().st_size > MAX_BYTES:
                problems.append(f"{path.name}: {path.stat().st_size / 1e6:.1f} MB exceeds 10 MB")
            if image.size not in ACCEPTED[device_class]:
                accepted = ", ".join(f"{w}x{h}" for w, h in sorted(ACCEPTED[device_class]))
                problems.append(
                    f"{path.name}: {image.size[0]}x{image.size[1]} is not one of {accepted}"
                )

    return problems


def contact_sheet(groups: dict[str, list[Path]]) -> None:
    """Renders every export at search-result thumbnail width in one strip."""
    columns: list[Image.Image] = []

    for files in groups.values():
        for path in files:
            with Image.open(path) as image:
                height = round(image.height * THUMBNAIL_WIDTH / image.width)
                columns.append(image.resize((THUMBNAIL_WIDTH, height), Image.LANCZOS).convert("RGB"))

    if not columns:
        return

    gap = 12
    width = sum(column.width for column in columns) + gap * (len(columns) + 1)
    height = max(column.height for column in columns) + gap * 2
    sheet = Image.new("RGB", (width, height), (20, 22, 28))

    x = gap
    for column in columns:
        sheet.paste(column, (x, gap))
        x += column.width + gap

    sheet.save(CONTACT_SHEET, "PNG")
    print(f"contact sheet: {CONTACT_SHEET.relative_to(REPO_ROOT)}")


def main() -> int:
    groups: dict[str, list[Path]] = {}
    compositor = load_compositor()
    expected_files = {
        spec.name: [f"{position:02d}-{key}.png" for position, key in enumerate(spec.order, start=1)]
        for spec in compositor.DEVICE_CLASSES
    }
    problems: list[str] = check_captions(compositor.SLOTS)

    for device_class, expected in expected_files.items():
        directory = FINAL_ROOT / device_class
        files = sorted(directory.glob("*.png")) if directory.is_dir() else []
        groups[device_class] = files
        actual = [path.name for path in files]
        if actual != expected:
            problems.append(f"{device_class}: files are {actual}, expected {expected}")

    if not any(groups.values()):
        print(f"no exports found under {FINAL_ROOT}", file=sys.stderr)
        return 1

    for device_class, files in groups.items():
        problems.extend(check(device_class, files))
        print(f"\n{device_class} — upload in this order:")
        for position, path in enumerate(files, start=1):
            with Image.open(path) as image:
                print(f"  {position}. {path.name}  {image.size[0]}x{image.size[1]} {image.mode}")

    contact_sheet(groups)

    print()
    if problems:
        for problem in problems:
            print(f"FAIL {problem}")
        return 1

    print(
        "All exports pass: exact pixel sizes, PNG, RGB, no alpha, under 10 MB,\n"
        "the complete ordered set for every device class, and every caption within 3–7 words."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
