#!/usr/bin/env python3
"""Compose App Store marketing screenshots.

Drop raw iPhone screenshots into appstore/raw/ named 01.png, 02.png, …
(the order below), run this script, and upload appstore/framed/*.png
(1320x2868, the required 6.9-inch size) straight to App Store Connect.

    python3 tools/frame_screenshots.py
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 1320, 2868
BG = (16, 18, 22)          # deep charcoal — flat, no gradients
FG = (245, 246, 248)
ACCENT = (255, 149, 0)     # matches the app accent
RADIUS = 56

CAPTIONS = [
    ("Every song's tone,", "dialed in."),
    ("Amp, knobs, pedals —", "the exact recipe."),
    ("Hear it. Identify it.", "Play it."),
    ("AI writes the tone sheet", "for any song."),
    ("Translated to", "YOUR gear."),
    ("Rate and share tones", "with other players."),
]


def font(size, bold=True):
    candidates = [
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def frame(shot_path, caption, out_path):
    canvas = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(canvas)

    f = font(104)
    y = 150
    for i, line in enumerate(caption):
        box = draw.textbbox((0, 0), line, font=f)
        draw.text(((W - (box[2] - box[0])) / 2, y), line, font=f,
                  fill=ACCENT if i == 1 else FG)
        y += 128

    shot = Image.open(shot_path).convert("RGB")
    target_w = 1080
    target_h = round(shot.height * target_w / shot.width)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)
    max_h = H - 560
    if target_h > max_h:
        shot = shot.crop((0, 0, target_w, max_h))
        target_h = max_h

    mask = Image.new("L", (target_w, target_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, target_w, target_h), radius=RADIUS, fill=255
    )
    x = (W - target_w) // 2
    canvas.paste(shot, (x, 470), mask)
    draw.rounded_rectangle(
        (x, 470, x + target_w, 470 + target_h),
        radius=RADIUS, outline=(60, 63, 70), width=4
    )
    canvas.save(out_path, "PNG")
    print("wrote", out_path)


def main():
    raw_dir = sys.argv[1] if len(sys.argv) > 1 else "appstore/raw"
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "appstore/framed"
    if not os.path.isdir(raw_dir):
        sys.exit(f"Put raw screenshots in {raw_dir}/ as 01.png, 02.png, … then rerun.")
    os.makedirs(out_dir, exist_ok=True)
    shots = sorted(
        f for f in os.listdir(raw_dir) if f.lower().endswith(".png")
    )
    if not shots:
        sys.exit(f"No .png files in {raw_dir}/")
    for i, name in enumerate(shots):
        caption = CAPTIONS[i % len(CAPTIONS)]
        frame(os.path.join(raw_dir, name), caption,
              os.path.join(out_dir, f"{i + 1:02d}.png"))


if __name__ == "__main__":
    main()
