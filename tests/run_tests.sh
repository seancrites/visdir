#!/usr/bin/env bash
# =============================================================================
# run_tests.sh — Unit test suite for deploy.sh
#
# Tests all CAPTCHA activation paths, general configuration sed operations,
# and script integrity (syntax, non-interactive guard, settings round-trip).
# AUTHOR: Sean Crites
# VERSION: 1.5.0
# DATE: 2026-05-11

# Usage:  bash tests/run_tests.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Test key generation — synthetic, not real keys
# ---------------------------------------------------------------------------
urn_random() {
   # Portable random hex: use openssl if available, fall back to /dev/urandom
   local len="${1:-16}"
   if command -v openssl &>/dev/null; then
      openssl rand -hex "$((len / 2))" 2>/dev/null
   else
      tr -dc 'a-f0-9' < /dev/urandom | head -c "$len"
   fi
}

TURNSTILE_TEST_SITE_KEY="tst-sk-$(urn_random 12)"
TURNSTILE_TEST_SECRET_KEY="tst-sc-$(urn_random 16)"
RECAPTCHA_TEST_SITE_KEY="rec-sk-$(urn_random 12)"
RECAPTCHA_TEST_SECRET_KEY="rec-sc-$(urn_random 16)"
HCAPTCHA_TEST_SITE_KEY="hca-sk-$(urn_random 12)"
HCAPTCHA_TEST_SECRET_KEY="hca-sc-$(urn_random 16)"

# ---------------------------------------------------------------------------
# Test fixture helpers
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
REPO_DIR="$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd -P)"
DEPLOY_SCRIPT="${REPO_DIR}/deploy.sh"
PASS=0
FAIL=0
FAIL_MSGS=()

setup() {
   mktemp -d /tmp/visdir-test-XXXXXX
}

teardown() {
   local dir="$1"
   rm -rf "$dir"
}

assert_contains() {
   local file="$1" pattern="$2" label="$3"
   if grep -q "$pattern" "$file"; then
      echo "  PASS  $label"
      ((PASS++)) || true
   else
      echo "  FAIL  $label"
      echo "        Expected pattern not found: $pattern"
      ((FAIL++)) || true
      FAIL_MSGS+=("FAIL: $label — expected pattern not found: $pattern")
   fi
}

assert_not_contains() {
   local file="$1" pattern="$2" label="$3"
   if grep -q "$pattern" "$file"; then
      echo "  FAIL  $label"
      echo "        Forbidden pattern found: $pattern"
      ((FAIL++)) || true
      FAIL_MSGS+=("FAIL: $label — forbidden pattern found: $pattern")
   else
      echo "  PASS  $label"
      ((PASS++)) || true
   fi
}

# ---------------------------------------------------------------------------
# Suite A: CAPTCHA Activation
# ---------------------------------------------------------------------------
test_captcha_activation() {
   local td
   td="$(setup)"

   echo ""
   echo "--- CAPTCHA Activation ---"

   # ---- Turnstile ----
   cp "${REPO_DIR}/public_html/contact.html" "${td}/contact.html"
   cp "${REPO_DIR}/public_html/contact.php"  "${td}/contact.php"

   local MARKER="TURNSTILE"
   local SITE_KEY="$TURNSTILE_TEST_SITE_KEY"
   local SECRET_KEY="$TURNSTILE_TEST_SECRET_KEY"

   # Run the exact sed commands from deploy.sh (CAPTCHA block)
   sed -i "s|${MARKER}-BEGIN|${MARKER}-BEGIN -->|" "${td}/contact.html"
   sed -i "s|${MARKER}-END|<!-- ${MARKER}-END|"    "${td}/contact.html"
   sed -i "s|${MARKER}-BEGIN|${MARKER}-BEGIN */|"  "${td}/contact.php"
   sed -i "s|${MARKER}-END|/* ${MARKER}-END|"      "${td}/contact.php"
   # Test both naming variants (templates are inconsistent)
   sed -i "s|${MARKER}_SITE_KEY|${SITE_KEY}|g"  "${td}/contact.html" "${td}/contact.php"
   sed -i "s|${MARKER}_SECRET_KEY|${SECRET_KEY}|g" "${td}/contact.php"

   assert_contains "${td}/contact.html" "TURNSTILE-BEGIN -->" \
      "Turnstile HTML BEGIN marker uncommented"
   assert_contains "${td}/contact.html" "<!-- TURNSTILE-END" \
      "Turnstile HTML END marker uncommented"
   assert_contains "${td}/contact.html" "$SITE_KEY" \
      "Turnstile sitekey injected in HTML"
   assert_contains "${td}/contact.php"  "TURNSTILE-BEGIN \*/" \
      "Turnstile PHP BEGIN marker uncommented"
   assert_contains "${td}/contact.php"  "/\* TURNSTILE-END" \
      "Turnstile PHP END marker uncommented"
   # Turnstile PHP template only has SECRET_KEY, not SITE_KEY
   assert_contains "${td}/contact.php"  "$SECRET_KEY" \
      "Turnstile secret injected in PHP"

   # Other providers must remain commented
   assert_contains "${td}/contact.html" "<!-- RECAPTCHA-BEGIN" \
      "reCAPTCHA HTML still commented (Turnstile test)"
   assert_contains "${td}/contact.html" "<!-- HCAPTCHA-BEGIN" \
      "hCaptcha HTML still commented (Turnstile test)"

   teardown "$td"

   # ---- reCAPTCHA ----
   td="$(setup)"
   cp "${REPO_DIR}/public_html/contact.html" "${td}/contact.html"
   cp "${REPO_DIR}/public_html/contact.php"  "${td}/contact.php"

   MARKER="RECAPTCHA"
   SITE_KEY="$RECAPTCHA_TEST_SITE_KEY"
   SECRET_KEY="$RECAPTCHA_TEST_SECRET_KEY"

   sed -i "s|${MARKER}-BEGIN|${MARKER}-BEGIN -->|" "${td}/contact.html"
   sed -i "s|${MARKER}-END|<!-- ${MARKER}-END|"    "${td}/contact.html"
   sed -i "s|${MARKER}-BEGIN|${MARKER}-BEGIN */|"  "${td}/contact.php"
   sed -i "s|${MARKER}-END|/* ${MARKER}-END|"      "${td}/contact.php"
   # Test both naming variants (templates are inconsistent)
   sed -i "s|${MARKER}_SITE_KEY|${SITE_KEY}|g"  "${td}/contact.html" "${td}/contact.php"
   sed -i "s|${MARKER}_SECRET_KEY|${SECRET_KEY}|g" "${td}/contact.php"

   assert_contains "${td}/contact.html" "RECAPTCHA-BEGIN -->" \
      "reCAPTCHA HTML BEGIN marker uncommented"
   assert_contains "${td}/contact.html" "<!-- RECAPTCHA-END" \
      "reCAPTCHA HTML END marker uncommented"
   assert_contains "${td}/contact.html" "$SITE_KEY" \
      "reCAPTCHA sitekey injected in HTML"
   assert_contains "${td}/contact.php"  "RECAPTCHA-BEGIN \*/" \
      "reCAPTCHA PHP BEGIN marker uncommented"
   assert_contains "${td}/contact.php"  "$SECRET_KEY" \
      "reCAPTCHA secret injected in PHP"

   assert_contains "${td}/contact.html" "<!-- TURNSTILE-BEGIN" \
      "Turnstile HTML still commented (reCAPTCHA test)"

   teardown "$td"

   # ---- hCaptcha ----
   td="$(setup)"
   cp "${REPO_DIR}/public_html/contact.html" "${td}/contact.html"
   cp "${REPO_DIR}/public_html/contact.php"  "${td}/contact.php"

   MARKER="HCAPTCHA"
   SITE_KEY="$HCAPTCHA_TEST_SITE_KEY"
   SECRET_KEY="$HCAPTCHA_TEST_SECRET_KEY"

   sed -i "s|${MARKER}-BEGIN|${MARKER}-BEGIN -->|" "${td}/contact.html"
   sed -i "s|${MARKER}-END|<!-- ${MARKER}-END|"    "${td}/contact.html"
   sed -i "s|${MARKER}-BEGIN|${MARKER}-BEGIN */|"  "${td}/contact.php"
   sed -i "s|${MARKER}-END|/* ${MARKER}-END|"      "${td}/contact.php"
   # Test both naming variants (templates are inconsistent)
   sed -i "s|${MARKER}_SITE_KEY|${SITE_KEY}|g"  "${td}/contact.html" "${td}/contact.php"
   sed -i "s|${MARKER}_SECRET_KEY|${SECRET_KEY}|g" "${td}/contact.php"

   assert_contains "${td}/contact.html" "HCAPTCHA-BEGIN -->" \
      "hCaptcha HTML BEGIN marker uncommented"
   assert_contains "${td}/contact.html" "<!-- HCAPTCHA-END" \
      "hCaptcha HTML END marker uncommented"
   assert_contains "${td}/contact.html" "$SITE_KEY" \
      "hCaptcha sitekey injected in HTML"
   assert_contains "${td}/contact.php"  "HCAPTCHA-BEGIN \*/" \
      "hCaptcha PHP BEGIN marker uncommented"
   assert_contains "${td}/contact.php"  "$SECRET_KEY" \
      "hCaptcha secret injected in PHP"

   assert_contains "${td}/contact.html" "<!-- TURNSTILE-BEGIN" \
      "Turnstile HTML still commented (hCaptcha test)"

   teardown "$td"

   # ---- No provider selected ----
   assert_not_contains "${REPO_DIR}/public_html/contact.html" "TURNSTILE-BEGIN -->" \
      "No provider: Turnstile remains commented in source"
}

# ---------------------------------------------------------------------------
# Suite B: General Configuration
# ---------------------------------------------------------------------------
test_general_config() {
   local td
   td="$(setup)"
   local TEST_URL="https://test.example.com"
   local TEST_TITLE="Test Directory"
   local TEST_META="Test meta description"
   local TEST_OG="Test OG description"
   local TEST_TO_EMAIL="admin@test.example.com"
   local TEST_FROM_EMAIL="no-reply@test.example.com"
   local TEST_MIN_SECONDS="10"
   local TEST_ENFORCE_REFERER="true"

   echo ""
   echo "--- General Configuration ---"

   # Copy all template files
   cp "${REPO_DIR}/public_html/index.html"   "${td}/index.html"
   cp "${REPO_DIR}/public_html/map.html"     "${td}/map.html"
   cp "${REPO_DIR}/public_html/contact.html" "${td}/contact.html"
   cp "${REPO_DIR}/public_html/contact.php"  "${td}/contact.php"
   cp "${REPO_DIR}/public_html/robots.txt"   "${td}/robots.txt"
   cp "${REPO_DIR}/public_html/sitemap.xml"  "${td}/sitemap.xml"

   # Run the exact sed commands from deploy.sh (lines 355-362)
   sed -i "s|https://yourdomain.com|${TEST_URL}|g" "${td}/"*.html "${td}/sitemap.xml" "${td}/robots.txt"
   sed -i "s|Visual Directory|${TEST_TITLE}|g" "${td}/"*.html
   # Multi-line meta tags — same pattern as deploy.sh
   sed -i '/<meta name="description"/{N;s|<meta name="description"\n[[:space:]]*content="[^"]*">|<meta name="description" content="'"${TEST_META}"'">|;}' "${td}/index.html"
   # Single-line fallback (same as deploy.sh)
   sed -i "s|<meta name=\"description\" content=\"[^\"]*\">|<meta name=\"description\" content=\"${TEST_META}\">|" "${td}/index.html"
   # Multi-line OG description
   sed -i '/<meta property="og:description"/{N;s|<meta property="og:description"\n[[:space:]]*content="[^"]*">|<meta property="og:description" content="'"${TEST_OG}"'">|;}' "${td}/index.html"
   # Single-line OG description fallback
   sed -i "s|<meta property=\"og:description\" content=\"[^\"]*\">|<meta property=\"og:description\" content=\"${TEST_OG}\">|" "${td}/index.html"
   sed -i "s|\$to[[:space:]]*= .*;|\$to = \"${TEST_TO_EMAIL}\";|" "${td}/contact.php"
   sed -i "s|no-reply@yourdomain.com|${TEST_FROM_EMAIL}|" "${td}/contact.php"
   sed -i "s|\$MINIMUM_SUBMIT_SECONDS = .*;|\$MINIMUM_SUBMIT_SECONDS = ${TEST_MIN_SECONDS};|" "${td}/contact.php"
   sed -i "s|\$ENFORCE_REFERER_CHECK = .*;|\$ENFORCE_REFERER_CHECK = ${TEST_ENFORCE_REFERER};|" "${td}/contact.php"

   # Assertions
   assert_contains "${td}/index.html"     "$TEST_URL" \
      "URL replaced in index.html"
   assert_contains "${td}/map.html"       "$TEST_URL" \
      "URL replaced in map.html"
   assert_contains "${td}/robots.txt"     "$TEST_URL" \
      "URL replaced in robots.txt"
   assert_contains "${td}/sitemap.xml"    "$TEST_URL" \
      "URL replaced in sitemap.xml"
   assert_contains "${td}/index.html"     "$TEST_TITLE" \
      "Site title replaced in index.html"
   assert_contains "${td}/contact.html"   "$TEST_TITLE" \
      "Site title replaced in contact.html"
   assert_contains "${td}/index.html"     "content=\"${TEST_META}\"" \
      "Meta description replaced"
   assert_contains "${td}/index.html"     "content=\"${TEST_OG}\"" \
      "OG description replaced"
   assert_contains "${td}/contact.php"    "\$to = \"${TEST_TO_EMAIL}\"" \
      "To email replaced"
   assert_contains "${td}/contact.php"    "${TEST_FROM_EMAIL}" \
      "From email replaced"
   assert_contains "${td}/contact.php"    "\$MINIMUM_SUBMIT_SECONDS = ${TEST_MIN_SECONDS}" \
      "Min submit seconds replaced"
   assert_contains "${td}/contact.php"    "\$ENFORCE_REFERER_CHECK = ${TEST_ENFORCE_REFERER}" \
      "Enforce referer check replaced"

   # Verify original template patterns are gone
   assert_not_contains "${td}/robots.txt" "https://yourdomain.com" \
      "Template URL removed from robots.txt"
   assert_not_contains "${td}/contact.php" "no-reply@yourdomain.com" \
      "Template email removed from contact.php"

   teardown "$td"
}

# ---------------------------------------------------------------------------
# Suite C: Script Integrity
# ---------------------------------------------------------------------------
test_script_integrity() {
   echo ""
   echo "--- Script Integrity ---"

   # C1: bash -n syntax check
   if bash -n "$DEPLOY_SCRIPT" 2>/dev/null; then
      echo "  PASS  bash -n syntax check"
      ((PASS++)) || true
   else
      echo "  FAIL  bash -n syntax check"
      ((FAIL++)) || true
      FAIL_MSGS+=("FAIL: bash -n syntax check")
   fi

   # C2: Non-interactive guard
   local output
   output=$(echo "" | bash "$DEPLOY_SCRIPT" 2>&1 || true)
   if echo "$output" | grep -q "must be run interactively"; then
      echo "  PASS  Non-interactive guard"
      ((PASS++)) || true
   else
      echo "  FAIL  Non-interactive guard"
      ((FAIL++)) || true
      FAIL_MSGS+=("FAIL: non-interactive guard — expected error not found")
   fi

   # C3: Settings JSON round-trip — verify jq can parse the same structure
   local td
   td="$(setup)"
   local test_json='{
     "web_root": "/tmp/test",
     "scripts_dir": "/tmp/test/scripts",
     "site_title": "Test",
     "url": "https://test.com",
     "meta_description": "desc",
     "og_description": "desc",
     "captcha": {
       "type": "turnstile",
       "last_choice": 1,
       "turnstile": {"sitekey": "sk", "secret": "sc"},
       "recaptcha": {"sitekey": "", "secret": ""},
       "hcaptcha": {"sitekey": "", "secret": ""}
     },
     "contact": {
       "to": "a@b.com",
       "from": "noreply@b.com",
       "min_seconds": 3,
       "enforce_referer_check": true
     },
     "version": "1.5.0"
   }'

   printf '%s\n' "$test_json" > "${td}/test-settings.json"

   # Test that jq can extract each field (same pattern as deploy.sh)
   local extracted
   extracted=$(jq -r '.web_root // empty' < "${td}/test-settings.json")
   if [ "$extracted" = "/tmp/test" ]; then
      echo "  PASS  Settings JSON: web_root round-trip"
      ((PASS++)) || true
   else
      echo "  FAIL  Settings JSON: web_root round-trip"
      ((FAIL++)) || true
      FAIL_MSGS+=("FAIL: settings JSON web_root round-trip")
   fi

   extracted=$(jq -r '.captcha.type // "none"' < "${td}/test-settings.json")
   if [ "$extracted" = "turnstile" ]; then
      echo "  PASS  Settings JSON: captcha.type round-trip"
      ((PASS++)) || true
   else
      echo "  FAIL  Settings JSON: captcha.type round-trip"
      ((FAIL++)) || true
      FAIL_MSGS+=("FAIL: settings JSON captcha.type round-trip")
   fi

   extracted=$(jq -r '.captcha.last_choice // 4' < "${td}/test-settings.json")
   if [ "$extracted" = "1" ]; then
      echo "  PASS  Settings JSON: last_choice round-trip"
      ((PASS++)) || true
   else
      echo "  FAIL  Settings JSON: last_choice round-trip"
      ((FAIL++)) || true
      FAIL_MSGS+=("FAIL: settings JSON last_choice round-trip")
   fi

   teardown "$td"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
   local start total
   start=$(date +%s%N)

   echo "=== VisDir Deploy Test Suite ==="
   echo "Repository: ${REPO_DIR}"
   echo "Script:     ${DEPLOY_SCRIPT}"
   echo "Keys:       turnstile=${TURNSTILE_TEST_SITE_KEY:0:20}..."
   echo "            recaptcha=${RECAPTCHA_TEST_SITE_KEY:0:20}..."
   echo "            hcaptcha=${HCAPTCHA_TEST_SITE_KEY:0:20}..."

   test_captcha_activation
   test_general_config
   test_script_integrity

   total=$(( ( $(date +%s%N) - start ) / 1000000 ))

   echo ""
   echo "============================"
   if [ "$FAIL" -eq 0 ]; then
      echo "Result: ${PASS}/${PASS} tests PASSED (${total}ms)"
   else
      echo "Result: ${PASS} PASSED, ${FAIL} FAILED (${total}ms)"
      echo ""
      echo "Failure details:"
      local msg
      for msg in "${FAIL_MSGS[@]}"; do
         echo "  $msg"
      done
   fi
   echo "============================"
   [ "$FAIL" -eq 0 ]
}

main "$@"
