#!/usr/bin/env python3
# =============================================================================
# update-thumbnails.py
#
# PURPOSE: Reliable screenshot capture using Playwright for VisDir.
#          Takes live screenshots of entity websites and creates thumbnails.
# AUTHOR: Generated for the visdir project
# VERSION: 1.4.1 (Python 3.7 compatible)
# DATE: 2026-04-23
# =============================================================================

import json
import sys
from pathlib import Path
from playwright.sync_api import sync_playwright
from PIL import Image

# ========================== CONFIGURATION ==================================
PROJECT_DIR = Path("../public_html").resolve()

DATA_FILE = PROJECT_DIR / "data.json"
THUMBNAILS_DIR = PROJECT_DIR / "thumbnails"
THUMB_WIDTH = 480
THUMB_HEIGHT = 300

THUMBNAILS_DIR.mkdir(parents=True, exist_ok=True)

# ========================== MAIN ===========================================
print(f"[{__import__('datetime').datetime.now():%Y-%m-%d %H:%M:%S}] Starting VisDir thumbnail update")

try:
    with open(DATA_FILE) as f:
        data = json.load(f)
except Exception as e:
    print(f"ERROR: Failed to read {DATA_FILE}: {e}")
    sys.exit(1)

entities = data.get("entities", [])

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)

    for entity in entities:
        if not entity.get("website"):
            continue
        if entity.get("take_thumbnail") is False:
            print(f"Skipping {entity.get('slug', 'unknown')} (take_thumbnail=false)")
            continue

        slug = entity["slug"]
        url = entity["website"]
        print(f"Processing {slug} → {url}")

        screenshot_path = THUMBNAILS_DIR / f"{slug}.png"
        temp_path = THUMBNAILS_DIR / f"{slug}_temp.png"

        try:
            page = browser.new_page(viewport={"width": 1920, "height": 1080})
            page.goto(url, wait_until="networkidle", timeout=45000)

            # Strong cookie rejection
            print("   → Waiting for cookie popup (6 seconds)...")
            page.wait_for_timeout(6000)

            reject_selectors = [
                'button:has-text("REJECT")',
                'button:has-text("Reject")',
                'button:has-text("Decline")',
                'button:has-text("Refuse")',
                'button:has-text("Reject all")',
                'button:has-text("Decline all")',
                'button:has-text("I do not consent")',
                'button:has-text("Only necessary")',
                'button:has-text("Necessary only")',
                '[id*="reject"]',
                '[id*="decline"]',
                '[aria-label*="reject" i]',
                '[aria-label*="decline" i]',
            ]

            clicked = False
            for selector in reject_selectors:
                try:
                    buttons = page.locator(selector)
                    count = buttons.count()
                    for i in range(count):
                        btn = buttons.nth(i)
                        if btn.is_visible(timeout=2000):
                            btn.scroll_into_view_if_needed()
                            btn.click()
                            print(f"   → SUCCESS: Clicked '{selector}'")
                            page.wait_for_timeout(1800)
                            clicked = True
                            break
                    if clicked:
                        break
                except Exception:
                    continue

            if not clicked:
                print("   → No Reject button found – proceeding anyway")

            # Take screenshot
            page.screenshot(path=temp_path, full_page=False)

            # Resize + center-crop
            with Image.open(temp_path) as img:
                img = img.convert("RGB")
                img = img.resize((THUMB_WIDTH, THUMB_HEIGHT), Image.Resampling.LANCZOS)
                img.save(screenshot_path, "PNG", optimize=True, quality=85)

            # Python 3.7 compatible cleanup
            if temp_path.exists():
                temp_path.unlink()

            print(f"✓ Updated thumbnail for {slug}")

        except Exception as e:
            print(f"WARNING: Failed for {slug}: {e}")
        finally:
            if "page" in locals():
                page.close()

    browser.close()

print(f"[{__import__('datetime').datetime.now():%Y-%m-%d %H:%M:%S}] Thumbnail update completed successfully")
