#!/usr/bin/env python3
"""Reusable App Store screenshot compositor for CheatSheet.

Implements the approved Brand Gradient style (see
AppStoreScreenshots/planning/style-direction.md): full-bleed gradient
canvas, eyebrow + headline caption in the top zone, a real device
screenshot inside a drawn bezel, cropped at the bottom edge.

Usage:
    python3 compose_screenshot.py \
        --screenshot /path/to/real-capture.png \
        --eyebrow "AUTO-FORMATTING" \
        --headline "It's already a checklist." \
        --canvas-size 1320x2868 \
        --out /path/to/final.png
"""
import argparse
import math
from PIL import Image, ImageDraw, ImageFont

GRADIENT_STOPS = [
    (0.00, (0x14, 0x19, 0x23)),
    (0.55, (0x1A, 0x21, 0x30)),
    (1.00, (0x0D, 0x11, 0x1C)),
]
EYEBROW_COLOR = (0x7F, 0xA6, 0xFF)
HEADLINE_COLOR = (0xFF, 0xFF, 0xFF)
BEZEL_TOP = (0x3A, 0x3F, 0x47)
BEZEL_MID = (0x1C, 0x1F, 0x24)
BEZEL_BOTTOM = (0x0B, 0x0C, 0x0E)

SF = "/System/Library/Fonts/SFNS.ttf"


def sf_font(size, weight):
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_name(weight)
    return f


def diagonal_gradient(w, h, angle_deg, stops):
    """Render a linear gradient at angle_deg (CSS-style, 0=up, 90=right) with multiple stops."""
    img = Image.new("RGB", (w, h))
    px = img.load()
    theta = math.radians(angle_deg - 90)
    dx, dy = math.cos(theta), math.sin(theta)
    # project all four corners onto the gradient axis to find [tmin, tmax]
    corners = [(0, 0), (w, 0), (0, h), (w, h)]
    projs = [cx * dx + cy * dy for cx, cy in corners]
    tmin, tmax = min(projs), max(projs)

    def color_at(t):
        if t <= stops[0][0]:
            return stops[0][1]
        if t >= stops[-1][0]:
            return stops[-1][1]
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                f = (t - t0) / (t1 - t0)
                return tuple(int(c0[k] + (c1[k] - c0[k]) * f) for k in range(3))

    # Precompute a 1D ramp for speed, sampled along the projection range.
    ramp_n = 512
    ramp = [color_at(i / (ramp_n - 1)) for i in range(ramp_n)]
    for y in range(h):
        for x in range(0, w, 2):  # sample every 2px, fill pairs — smooth enough, faster
            t = (x * dx + y * dy - tmin) / (tmax - tmin)
            t = min(max(t, 0.0), 1.0)
            c = ramp[int(t * (ramp_n - 1))]
            px[x, y] = c
            if x + 1 < w:
                px[x + 1, y] = c
    return img


def rounded_mask(size, radius):
    w, h = size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    return mask


def wrap_text(draw, text, font, max_width):
    words = text.split()
    lines, cur = [], ""
    for word in words:
        trial = (cur + " " + word).strip()
        if draw.textlength(trial, font=font) <= max_width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def compose(screenshot_path, eyebrow, headline, canvas_w, canvas_h, out_path,
            device="iphone"):
    W, H = canvas_w, canvas_h
    canvas = diagonal_gradient(W, H, 165, GRADIENT_STOPS)
    draw = ImageDraw.Draw(canvas)

    pad_x = int(W * 0.08)
    cap_top = int(H * 0.11)

    eyebrow_size = max(1, int(W * 0.032))
    headline_size = int(W * 0.088)
    eyebrow_font = sf_font(eyebrow_size, "Semibold")
    headline_font = sf_font(headline_size, "Bold")

    y = cap_top
    if eyebrow:
        eyebrow_up = eyebrow.upper()
        # manual letter-spacing: draw glyph by glyph with a tracking gap
        tracking = int(eyebrow_size * 0.09)
        cx = pad_x
        for ch in eyebrow_up:
            draw.text((cx, y), ch, font=eyebrow_font, fill=EYEBROW_COLOR)
            cx += draw.textlength(ch, font=eyebrow_font) + tracking
        y += int(eyebrow_size * 1.3) + int(W * 0.028)

    max_text_w = W - 2 * pad_x
    lines = wrap_text(draw, headline, headline_font, max_text_w)
    line_h = int(headline_size * 1.08)
    for line in lines:
        draw.text((pad_x, y), line, font=headline_font, fill=HEADLINE_COLOR)
        y += line_h
    caption_bottom = y + int(W * 0.02)

    # --- device frame ---
    phone_w = int(W * 0.92)
    phone_h = int(phone_w * (H / W))  # same aspect as the canvas/device
    phone_top = H - int(phone_h * 0.91)  # crops ~9% of the phone below the canvas edge
    phone_top = max(phone_top, caption_bottom)
    phone_left = (W - phone_w) // 2

    bezel_radius = int(phone_w * 0.115)
    bezel = diagonal_gradient(phone_w, phone_h, 180,
                               [(0.0, BEZEL_TOP), (0.22, BEZEL_MID), (0.78, BEZEL_MID), (1.0, BEZEL_BOTTOM)])
    bezel_mask = rounded_mask((phone_w, phone_h), bezel_radius)

    bezel_pad = max(2, int(phone_w * 0.011))
    screen_w = phone_w - 2 * bezel_pad
    screen_h = phone_h - 2 * bezel_pad
    screen_radius = int(screen_w * 0.10)

    shot = Image.open(screenshot_path).convert("RGB")
    shot_ratio = screen_w / screen_h
    src_ratio = shot.width / shot.height
    if src_ratio > shot_ratio:
        new_h = shot.height
        new_w = int(new_h * shot_ratio)
        left = (shot.width - new_w) // 2
        shot_cropped = shot.crop((left, 0, left + new_w, new_h))
    else:
        new_w = shot.width
        new_h = int(new_w / shot_ratio)
        shot_cropped = shot.crop((0, 0, new_w, min(new_h, shot.height)))
    shot_resized = shot_cropped.resize((screen_w, screen_h), Image.LANCZOS)
    screen_mask = rounded_mask((screen_w, screen_h), screen_radius)

    phone_img = Image.new("RGB", (phone_w, phone_h), BEZEL_MID)
    phone_img.paste(bezel, (0, 0), bezel_mask)
    phone_img.paste(shot_resized, (bezel_pad, bezel_pad), screen_mask)

    # dynamic island
    pd = ImageDraw.Draw(phone_img)
    isl_w = int(phone_w * 0.27)
    isl_h = int(phone_w * 0.025)
    isl_x = (phone_w - isl_w) // 2
    isl_y = int(phone_h * 0.034)
    pd.rounded_rectangle([isl_x, isl_y, isl_x + isl_w, isl_y + isl_h],
                          radius=isl_h // 2, fill=(0, 0, 0))

    phone_mask = rounded_mask((phone_w, phone_h), bezel_radius)
    canvas.paste(phone_img, (phone_left, phone_top), phone_mask)

    canvas.save(out_path, "PNG")
    return out_path


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--screenshot", required=True)
    p.add_argument("--eyebrow", default="")
    p.add_argument("--headline", required=True)
    p.add_argument("--canvas-size", default="1320x2868")
    p.add_argument("--out", required=True)
    p.add_argument("--device", default="iphone")
    args = p.parse_args()
    w, h = (int(v) for v in args.canvas_size.split("x"))
    out = compose(args.screenshot, args.eyebrow, args.headline, w, h, args.out, args.device)
    print("wrote", out)
