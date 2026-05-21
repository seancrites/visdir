#!/usr/bin/env python3
# =============================================================================
# resize-thumbnail.py
#
# PURPOSE: Convert large PNGs (e.g. manual Google Street View screenshots)
#          to VisDir 480x300 thumbnails.
#          - Center-crops to exact 480:300 aspect ratio (fills the frame,
#            no skewing or distortion)
#          - High-quality resize using LANCZOS
#          - Always creates a timestamped backup of the original
#            (filename-orig-YYYYMMDDHHMMSS.png) — never overwrites backups
#
# USAGE:
#   ./scripts/resize-thumbnail.sh large-screenshot.png
#   ./scripts/resize-thumbnail.sh sv1.png sv2.png sv3.png
#
# REQUIREMENTS:
#   Uses the same Python virtual environment as update-thumbnails.py:
#     ~/visdir-env
#
#   Pillow is already installed in this environment (no new modules needed).
#   If the environment is missing, run the following once:
#     python3 -m venv ~/visdir-env
#     source ~/visdir-env/bin/activate
#     pip install --upgrade pip
#     pip install pillow
#
# NOTES FOR FUTURE README.md MERGE:
#   Add a new section "Manual Thumbnail Resizer" with the above venv
#   instructions and usage examples.
#
# AUTHOR: Sean Crites
# VERSION: v2.0.1
# DATE: 2026-05-15
# =============================================================================

import argparse
import sys
from datetime import datetime
from pathlib import Path

from PIL import Image

# ========================== CONFIGURATION ==================================
THUMB_WIDTH = 480
THUMB_HEIGHT = 300


def get_unique_backup_path(original_path: Path) -> Path:
    """Generate a unique backup filename with timestamp.
    Never overwrites an existing backup file.
    """
    ts = datetime.now().strftime("%Y%m%d%H%M%S")
    backup = original_path.with_name(
        f"{original_path.stem}-orig-{ts}{original_path.suffix}"
    )
    counter = 1
    while backup.exists():
        backup = original_path.with_name(
            f"{original_path.stem}-orig-{ts}-{counter}{original_path.suffix}"
        )
        counter += 1
    return backup


def process_image(input_path: Path) -> bool:
    """Process one image: center-crop to ratio, resize, backup original, save thumbnail."""
    if not input_path.exists():
        print(f"ERROR: File not found: {input_path}")
        return False

    try:
        with Image.open(input_path) as img:
            orig_w, orig_h = img.size
            print(f"Processing {input_path.name} ({orig_w}x{orig_h})...")

            # Center-crop to exact 480:300 ratio (fills the frame)
            target_ratio = THUMB_WIDTH / THUMB_HEIGHT
            orig_ratio = orig_w / orig_h

            if orig_ratio > target_ratio:
                new_w = int(orig_h * target_ratio)
                left = (orig_w - new_w) // 2
                img = img.crop((left, 0, left + new_w, orig_h))
            else:
                new_h = int(orig_w / target_ratio)
                top = (orig_h - new_h) // 2
                img = img.crop((0, top, orig_w, top + new_h))

            # High-quality resize
            img = img.resize((THUMB_WIDTH, THUMB_HEIGHT), Image.Resampling.LANCZOS)

            if img.mode != "RGB":
                img = img.convert("RGB")

            # Create backup (never overwrites existing backups)
            backup_path = get_unique_backup_path(input_path)
            input_path.rename(backup_path)
            print(f"   → Backed up original → {backup_path.name}")

            # Save processed thumbnail to original filename
            img.save(input_path, "PNG", optimize=True, quality=85)
            print(f"✓ Thumbnail ready: {input_path.name}")

            return True

    except Exception as e:
        print(f"ERROR processing {input_path.name}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Convert large PNGs to VisDir 480×300 thumbnails "
                    "(center-crop + high-quality resize). "
                    "Always creates timestamped backup of the original."
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        metavar="IMAGE.png",
        help="One or more PNG files to process"
    )

    args = parser.parse_args()

    success = 0
    for input_str in args.inputs:
        path = Path(input_str).resolve()
        if process_image(path):
            success += 1

    print(f"\nCompleted: {success}/{len(args.inputs)} images processed successfully.")


if __name__ == "__main__":
    main()
