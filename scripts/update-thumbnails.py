#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# =============================================================================
# update-thumbnails.py
#
# PURPOSE: Reliable screenshot capture using Playwright for VisDir.
#          Takes live screenshots of entity websites and creates thumbnails.
# AUTHOR: Generated for the visdir project
# VERSION: 1.5.0 (Python 3.7 compatible)
# DATE: 2026-04-25
# =============================================================================

import json
import sys

# Fail fast with a helpful message on Python 2 or < 3.7
if sys.version_info < (3, 7):
    py_ver = "{}.{}.{}".format(sys.version_info.major, sys.version_info.minor, sys.version_info.micro)
    sys.stderr.write("ERROR: Python 3.7+ is required. Detected: {}\n".format(py_ver))
    sys.stderr.write("Please recreate your virtualenv with: python3 -m venv ~/visdir-env\n")
    sys.stderr.write("Then install dependencies: pip install playwright Pillow\n")
    sys.stderr.write("Finally install browsers:   playwright install chromium\n")
    sys.exit(1)

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

# ========================== COOKIE DISMISSAL ===============================

def dismiss_cookie_banner(page):
    """
    Multi-layered strategy to dismiss or hide cookie consent banners.
    Returns True if a banner was found and handled, False otherwise.
    """
    print("   → Waiting for cookie popup (6 seconds)...")
    page.wait_for_timeout(6000)

    # -----------------------------------------------------------------
    # LAYER 1: Expanded CSS selectors (buttons, spans, divs, .btn, etc.)
    # -----------------------------------------------------------------
    reject_texts = [
        "REJECT", "Reject", "Decline", "Refuse", "Deny", "No thanks",
        "Reject all", "Decline all", "I do not consent",
        "Only necessary", "Necessary only", "Essential only",
        "Disagree", "Opt out", "Opt-out",
    ]

    accept_texts = [
        "Accept", "Accept all", "Accept Cookies", "Allow", "Allow all",
        "Agree", "I agree", "OK", "Got it", "Continue", "Yes", "Close",
    ]

    # Build selectors for any element type (button, span, div, a, input)
    # that contains reject/decline text
    all_texts = reject_texts + accept_texts
    tag_types = ["button", "span", "div", "a", "input", "[role='button']"]

    selectors = []
    for text in all_texts:
        for tag in tag_types:
            selectors.append('{}:has-text("{}")'.format(tag, text))

    # Add class-based selectors for common cookie banner patterns
    selectors.extend([
        '[class*="cookie"] .btn',
        '[id*="cookie"] .btn',
        '[class*="consent"] .btn',
        '[id*="consent"] .btn',
        '[class*="gdpr"] .btn',
        '.cookie-prompt .btn',
        '.cookie-banner .btn',
        '.cookie-consent .btn',
        '.cookie-notice .btn',
        '.cc-window .btn',
        '.cc-banner .btn',
        '#CybotCookiebotDialogBodyButtonDecline',
        '#onetrust-reject-all-handler',
        '#onetrust-accept-btn-handler',
        '.ot-pc-refuse-all-handler',
        '.js-reject-cookies',
        '.js-decline-cookies',
        '[data-cookie-reject]',
        '[data-action="reject"]',
        '[data-action="decline"]',
        '[aria-label*="reject" i]',
        '[aria-label*="decline" i]',
        '[aria-label*="deny" i]',
        '[title*="reject" i]',
        '[title*="decline" i]',
        '[id*="reject"]',
        '[id*="decline"]',
        '[id*="deny"]',
        '[class*="reject"]',
        '[class*="decline"]',
        '[class*="deny"]',
    ])

    clicked = False
    clicked_selector = None

    for selector in selectors:
        try:
            elements = page.locator(selector)
            count = elements.count()
            for i in range(count):
                el = elements.nth(i)
                if el.is_visible(timeout=1500):
                    # Try standard click
                    try:
                        el.scroll_into_view_if_needed()
                        el.click(timeout=3000)
                    except Exception:
                        # Fallback to JavaScript click
                        try:
                            el.evaluate("e => e.click()")
                        except Exception:
                            continue
                    clicked = True
                    clicked_selector = selector
                    print("   → SUCCESS: Clicked '{}'".format(selector))
                    page.wait_for_timeout(1500)
                    break
            if clicked:
                break
        except Exception:
            continue

    # -----------------------------------------------------------------
    # LAYER 2: Container-first detection
    # Find known cookie banner containers, then scan children for buttons
    # -----------------------------------------------------------------
    if not clicked:
        container_selectors = [
            '.cookie-prompt',
            '.cookie-banner',
            '.cookie-consent',
            '.cookie-notice',
            '.cookie-popup',
            '.cookie-overlay',
            '.cookie-modal',
            '.cookie-dialog',
            '.cc-window',
            '.cc-banner',
            '.cc-consent',
            '#cookie-banner',
            '#cookie-consent',
            '#cookie-notice',
            '#cookie-popup',
            '#cookie-overlay',
            '#cookie-modal',
            '#cookie-dialog',
            '#CybotCookiebotDialog',
            '#onetrust-banner-sdk',
            '#onetrust-consent-sdk',
            '.ot-sdk-show',
            '.modal-cookie',
            '.gdpr-banner',
            '.gdpr-consent',
            '.privacy-banner',
            '.privacy-popup',
            '[class*="cookie-prompt"]',
            '[class*="cookie-banner"]',
            '[class*="cookie-consent"]',
            '[class*="cookie-notice"]',
            '[class*="cookie-popup"]',
            '[id*="cookie-banner"]',
            '[id*="cookie-consent"]',
            '[id*="cookie-notice"]',
        ]

        for container_sel in container_selectors:
            try:
                containers = page.locator(container_sel)
                count = containers.count()
                for i in range(count):
                    container = containers.nth(i)
                    if not container.is_visible(timeout=1000):
                        continue

                    # Look for any button-like child inside this container
                    child_selectors = [
                        'button',
                        'a',
                        'span',
                        'div',
                        'input[type="button"]',
                        'input[type="submit"]',
                        '.btn',
                        '[role="button"]',
                    ]
                    for child_sel in child_selectors:
                        try:
                            children = container.locator(child_sel)
                            child_count = children.count()
                            for j in range(child_count):
                                child = children.nth(j)
                                if not child.is_visible(timeout=1000):
                                    continue
                                text = (child.inner_text() or "").strip().lower()
                                # Prefer reject/deny/decline, but accept any interaction
                                is_reject = any(t.lower() in text for t in reject_texts)
                                is_accept = any(t.lower() in text for t in accept_texts)
                                if is_reject or is_accept or len(text) < 30:
                                    try:
                                        child.scroll_into_view_if_needed()
                                        child.click(timeout=3000)
                                    except Exception:
                                        child.evaluate("e => e.click()")
                                    clicked = True
                                    clicked_selector = "{} -> {} (text: '{}')".format(container_sel, child_sel, text)
                                    print("   → SUCCESS: Clicked inside cookie container '{}'".format(clicked_selector))
                                    page.wait_for_timeout(1500)
                                    break
                            if clicked:
                                break
                        except Exception:
                            continue
                    if clicked:
                        break
            except Exception:
                continue
            if clicked:
                break

    # -----------------------------------------------------------------
    # LAYER 3: JavaScript text-based fallback
    # Scan entire DOM for any element whose text matches cookie keywords
    # -----------------------------------------------------------------
    if not clicked:
        try:
            js_result = page.evaluate("""
                () => {
                    const rejectTexts = [
                        "reject", "decline", "refuse", "deny", "no thanks",
                        "reject all", "decline all", "i do not consent",
                        "only necessary", "necessary only", "essential only",
                        "disagree", "opt out", "opt-out"
                    ];
                    const acceptTexts = [
                        "accept", "accept all", "accept cookies", "allow", "allow all",
                        "agree", "i agree", "ok", "got it", "continue", "yes", "close"
                    ];
                    const allTexts = rejectTexts.concat(acceptTexts);

                    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT);
                    const candidates = [];
                    let node;
                    while (node = walker.nextNode()) {
                        const style = window.getComputedStyle(node);
                        if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
                            continue;
                        }
                        const text = (node.innerText || node.textContent || "").trim().toLowerCase();
                        for (const t of allTexts) {
                            if (text === t.toLowerCase() || text.startsWith(t.toLowerCase() + " ") || text.endsWith(" " + t.toLowerCase())) {
                                // Check if element is reasonably clickable (has click handler, pointer cursor, or common tag)
                                const tag = node.tagName.toLowerCase();
                                const isClickable = tag === 'button' || tag === 'a' || tag === 'input' ||
                                    tag === 'span' || tag === 'div' ||
                                    node.onclick || node.getAttribute('onclick') ||
                                    node.getAttribute('role') === 'button' ||
                                    style.cursor === 'pointer' ||
                                    node.className.toLowerCase().includes('btn') ||
                                    node.className.toLowerCase().includes('button');
                                if (isClickable) {
                                    candidates.push({tag: tag, text: text, class: node.className, id: node.id, isReject: rejectTexts.some(rt => text.includes(rt.toLowerCase()))});
                                }
                                break;
                            }
                        }
                    }
                    // Sort: prefer reject options over accept options
                    candidates.sort((a, b) => (b.isReject ? 1 : 0) - (a.isReject ? 1 : 0));
                    return candidates.slice(0, 10);
                }
            """)

            if js_result and len(js_result) > 0:
                best = js_result[0]
                print("   → JS fallback found candidate: <{}> text='{}' class='{}' id='{}'".format(best['tag'], best['text'], best['class'], best['id']))
                # Try to click via JS
                clicked_via_js = page.evaluate("""
                    () => {
                        const rejectTexts = [
                            "reject", "decline", "refuse", "deny", "no thanks",
                            "reject all", "decline all", "i do not consent",
                            "only necessary", "necessary only", "essential only",
                            "disagree", "opt out", "opt-out"
                        ];
                        const acceptTexts = [
                            "accept", "accept all", "accept cookies", "allow", "allow all",
                            "agree", "i agree", "ok", "got it", "continue", "yes", "close"
                        ];
                        const allTexts = rejectTexts.concat(acceptTexts);

                        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT);
                        let node;
                        while (node = walker.nextNode()) {
                            const style = window.getComputedStyle(node);
                            if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
                                continue;
                            }
                            const text = (node.innerText || node.textContent || "").trim().toLowerCase();
                            for (const t of allTexts) {
                                if (text === t.toLowerCase() || text.startsWith(t.toLowerCase() + " ") || text.endsWith(" " + t.toLowerCase())) {
                                    const tag = node.tagName.toLowerCase();
                                    const isClickable = tag === 'button' || tag === 'a' || tag === 'input' ||
                                        tag === 'span' || tag === 'div' ||
                                        node.onclick || node.getAttribute('onclick') ||
                                        node.getAttribute('role') === 'button' ||
                                        style.cursor === 'pointer' ||
                                        node.className.toLowerCase().includes('btn') ||
                                        node.className.toLowerCase().includes('button');
                                    if (isClickable) {
                                        node.click();
                                        node.dispatchEvent(new MouseEvent('click', { bubbles: true }));
                                        return true;
                                    }
                                    break;
                                }
                            }
                        }
                        return false;
                    }
                """)
                if clicked_via_js:
                    clicked = True
                    clicked_selector = "JS text fallback (found: {})".format(best['text'])
                    print("   → SUCCESS: Clicked via JS text fallback")
                    page.wait_for_timeout(1500)
        except Exception as e:
            print("   → JS fallback error: {}".format(e))

    # -----------------------------------------------------------------
    # LAYER 4: CSS injection hide (last resort)
    # Force-hide known cookie banner selectors
    # -----------------------------------------------------------------
    if not clicked:
        print("   → No clickable button found, attempting CSS hide...")

    # Always try to hide known cookie banners via CSS, even if we clicked something
    # (some banners have animations or delayed appearance)
    try:
        page.add_style_tag(content="""
            .cookie-prompt, .cookie-banner, .cookie-consent, .cookie-notice,
            .cookie-popup, .cookie-overlay, .cookie-modal, .cookie-dialog,
            .cc-window, .cc-banner, .cc-consent, .cc-overlay, .cc-modal,
            #cookie-banner, #cookie-consent, #cookie-notice, #cookie-popup,
            #cookie-overlay, #cookie-modal, #cookie-dialog,
            #CybotCookiebotDialog, #onetrust-banner-sdk, #onetrust-consent-sdk,
            .ot-sdk-show, .modal-cookie, .gdpr-banner, .gdpr-consent,
            .privacy-banner, .privacy-popup, .privacy-notice,
            [class*="cookie-prompt"], [class*="cookie-banner"],
            [class*="cookie-consent"], [class*="cookie-notice"],
            [class*="cookie-popup"], [class*="cookie-overlay"],
            [id*="cookie-banner"], [id*="cookie-consent"],
            [id*="cookie-notice"], [id*="cookie-popup"]
            { display: none !important; visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; }
        """)
        print("   → Injected CSS to hide cookie banners")
        page.wait_for_timeout(800)
    except Exception as e:
        print("   → CSS hide error: {}".format(e))

    # -----------------------------------------------------------------
    # Verification: Check if any cookie banner is still visible
    # -----------------------------------------------------------------
    verification_selectors = [
        '.cookie-prompt', '.cookie-banner', '.cookie-consent', '.cookie-notice',
        '.cookie-popup', '.cookie-overlay', '.cookie-modal', '.cookie-dialog',
        '.cc-window', '.cc-banner', '#cookie-banner', '#cookie-consent',
        '#CybotCookiebotDialog', '#onetrust-banner-sdk',
    ]

    still_visible = []
    for vsel in verification_selectors:
        try:
            vel = page.locator(vsel)
            if vel.count() > 0 and vel.first.is_visible(timeout=1000):
                still_visible.append(vsel)
        except Exception:
            pass

    if still_visible:
        print("   → WARNING: Cookie banners still visible: {}".format(still_visible))
    else:
        print("   → Cookie banner check: clear")

    return clicked or len(still_visible) == 0


# ========================== MAIN ===========================================
print("[{:%Y-%m-%d %H:%M:%S}] Starting VisDir thumbnail update".format(__import__('datetime').datetime.now()))

try:
    with open(DATA_FILE) as f:
        data = json.load(f)
except Exception as e:
    print("ERROR: Failed to read {}: {}".format(DATA_FILE, e))
    sys.exit(1)

entities = data.get("entities", [])

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)

    for entity in entities:
        if not entity.get("website"):
            continue
        if entity.get("take_thumbnail") is False:
            print("Skipping {} (take_thumbnail=false)".format(entity.get('slug', 'unknown')))
            continue

        slug = entity["slug"]
        url = entity["website"]
        print("Processing {} → {}".format(slug, url))

        screenshot_path = THUMBNAILS_DIR / "{}.png".format(slug)
        temp_path = THUMBNAILS_DIR / "{}_temp.png".format(slug)

        try:
            page = browser.new_page(viewport={"width": 1920, "height": 1080})
            page.goto(url, wait_until="networkidle", timeout=45000)

            # Dismiss cookie banner using multi-layered strategy
            dismiss_cookie_banner(page)

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

            print("✓ Updated thumbnail for {}".format(slug))

        except Exception as e:
            print("WARNING: Failed for {}: {}".format(slug, e))
        finally:
            if "page" in locals():
                page.close()

    browser.close()

print("[{:%Y-%m-%d %H:%M:%S}] Thumbnail update completed successfully".format(__import__('datetime').datetime.now()))
