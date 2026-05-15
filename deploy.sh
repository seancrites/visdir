#!/usr/bin/env bash
# =============================================================================
# deploy.sh
#
# PURPOSE: One-command deploy and upgrade script for VisDir.
# Handles first-time installation and future upgrades after git pull.
# Saves user customizations in deploy-settings.json (gitignored).
# AUTHOR: Sean Crites
# VERSION: 2.0.0
# DATE: 2026-05-12
# DEPENDENCIES: bash, sed, jq, mkdir, cp, chmod, realpath
#
# ERROR HANDLING: set -euo pipefail is active for strong error protection.
# All read commands use "|| true" to prevent set -e from exiting on EOF/Ctrl+D.
# The two infinite-loop contexts (URL first-time, deploy confirm) use
# "if ! read -r" to detect EOF and abort with a clear message.
# =============================================================================

set -euo pipefail

SETTINGS_FILE="deploy-settings.json"
ARCHIVE_DIR="archive"
PROJECT_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
VERSION_FILE="${PROJECT_ROOT}/VERSION"

# ----------------------------------------------------------------------------
# Minimal helpers (defined early so they can be used below)
# ----------------------------------------------------------------------------
log() { printf '[deploy] %s\n' "$1"; }
error() { printf 'ERROR: %s\n' "$1" >&2; }

# If not running interactively, bail out — this script is interactive-only
if [ ! -t 0 ]; then
    error "This script must be run interactively (stdin is not a terminal)."
    error "It is not designed for piped input or non-interactive automation."
    exit 1
fi

# ----------------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------------
print_header() {
   printf '\n=== VisDir Deploy / Upgrade Tool ===\n\n'
}

get_visdir_version() {
   if [ -f "${VERSION_FILE}" ]; then
      tr -d '[:space:]' < "${VERSION_FILE}"
   else
      printf "unknown"
   fi
}

load_settings() {
   if [ -f "${PROJECT_ROOT}/${SETTINGS_FILE}" ]; then
      cat "${PROJECT_ROOT}/${SETTINGS_FILE}"
   else
      printf '{}\n'
   fi
}

save_settings() {
   printf '%s\n' "$1" > "${PROJECT_ROOT}/${SETTINGS_FILE}"
}

load_captcha_keys() {
   TURNSTILE_SITE_KEY=$(echo "${SETTINGS}" | jq -r '.captcha.turnstile.site_key // empty')
   TURNSTILE_SECRET_KEY=$(echo "${SETTINGS}" | jq -r '.captcha.turnstile.secret_key // empty')
   RECAPTCHA_SITE_KEY=$(echo "${SETTINGS}" | jq -r '.captcha.recaptcha.site_key // empty')
   RECAPTCHA_SECRET_KEY=$(echo "${SETTINGS}" | jq -r '.captcha.recaptcha.secret_key // empty')
   HCAPTCHA_SITE_KEY=$(echo "${SETTINGS}" | jq -r '.captcha.hcaptcha.site_key // empty')
   HCAPTCHA_SECRET_KEY=$(echo "${SETTINGS}" | jq -r '.captcha.hcaptcha.secret_key // empty')
}

prompt_captcha_keys() {
   if [ "${CAPTCHA_TYPE}" != "none" ]; then
      case "${CAPTCHA_TYPE}" in
         turnstile)
            printf 'Cloudflare Turnstile Site Key [%s]: ' "${TURNSTILE_SITE_KEY}"
            read -r input || true
            [ -n "${input}" ] && TURNSTILE_SITE_KEY="${input}"

            printf 'Cloudflare Turnstile Secret Key [%s]: ' "${TURNSTILE_SECRET_KEY}"
            read -r input || true
            [ -n "${input}" ] && TURNSTILE_SECRET_KEY="${input}"
            ;;
         recaptcha)
            printf 'Google reCAPTCHA v3 Site Key [%s]: ' "${RECAPTCHA_SITE_KEY}"
            read -r input || true
            [ -n "${input}" ] && RECAPTCHA_SITE_KEY="${input}"

            printf 'Google reCAPTCHA v3 Secret Key [%s]: ' "${RECAPTCHA_SECRET_KEY}"
            read -r input || true
            [ -n "${input}" ] && RECAPTCHA_SECRET_KEY="${input}"
            ;;
         hcaptcha)
            printf 'hCaptcha Site Key [%s]: ' "${HCAPTCHA_SITE_KEY}"
            read -r input || true
            [ -n "${input}" ] && HCAPTCHA_SITE_KEY="${input}"

            printf 'hCaptcha Secret Key [%s]: ' "${HCAPTCHA_SECRET_KEY}"
            read -r input || true
            [ -n "${input}" ] && HCAPTCHA_SECRET_KEY="${input}"
            ;;
      esac
   fi
   return 0
}

# Prompting function – reusable for first run + edit loop
# Uses current in-memory variables on re-edit (no JSON reload)
ask_all_settings() {
   # === Prompts with [current value] in brackets ===
   if [ -z "${WEB_ROOT}" ]; then
      printf 'Web root folder (where index.html should live): '
      read -r WEB_ROOT || true
   else
      printf 'Web root folder [%s]: ' "${WEB_ROOT}"
      read -r input || true
      [ -n "${input}" ] && WEB_ROOT="${input}"
   fi

   DEFAULT_SCRIPTS="$(dirname "${WEB_ROOT}")/scripts"
   if [ -z "${SCRIPTS_DIR}" ]; then
      SCRIPTS_DIR="${DEFAULT_SCRIPTS}"
      printf 'Scripts folder [%s]: ' "${SCRIPTS_DIR}"
      read -r input || true
      [ -n "${input}" ] && SCRIPTS_DIR="${input}"
   else
      printf 'Scripts folder [%s]: ' "${SCRIPTS_DIR}"
      read -r input || true
      [ -n "${input}" ] && SCRIPTS_DIR="${input}"
   fi

   printf 'Site title [%s]: ' "${SITE_TITLE}"
   read -r input || true
   [ -n "${input}" ] && SITE_TITLE="${input}"

   if [ -z "${URL}" ] || [[ "${URL}" != http* ]]; then
      while true; do
         printf 'Base URL (must start with http:// or https://): '
         if ! read -r URL; then
            error "Input cancelled during URL prompt."
            exit 1
         fi
         if [[ "${URL}" == http* ]]; then
            break
         else
            printf 'ERROR: URL must include http:// or https://\n'
         fi
      done
   else
      printf 'Base URL [%s]: ' "${URL}"
      read -r input || true
      [ -n "${input}" ] && URL="${input}"
   fi

   [ -z "${META_DESC}" ] && { printf '\nMeta description (search results):\n'; read -r META_DESC || true; } || { printf 'Meta description [%s]: ' "${META_DESC}"; read -r input || true; [ -n "${input}" ] && META_DESC="${input}"; }
   [ -z "${OG_DESC}" ] && { printf '\nOpen Graph description (social shares):\n'; read -r OG_DESC || true; } || { printf 'Open Graph description [%s]: ' "${OG_DESC}"; read -r input || true; [ -n "${input}" ] && OG_DESC="${input}"; }
   [ -z "${TO_EMAIL}" ] && { printf '\nContact form "To" email: '; read -r TO_EMAIL || true; } || { printf 'Contact form "To" email [%s]: ' "${TO_EMAIL}"; read -r input || true; [ -n "${input}" ] && TO_EMAIL="${input}"; }

   if [ -z "${FROM_EMAIL}" ]; then
      DOMAIN=$(echo "${URL}" | sed -E 's|https?://([^/]+).*|\1|')
      FROM_EMAIL="no-reply@${DOMAIN}"
      printf 'Contact form "From" address [%s]: ' "${FROM_EMAIL}"
      read -r input || true
      [ -n "${input}" ] && FROM_EMAIL="${input}"
   else
      printf 'Contact form "From" address [%s]: ' "${FROM_EMAIL}"
      read -r input || true
      [ -n "${input}" ] && FROM_EMAIL="${input}"
   fi

   # Minimum Submit Seconds
   printf 'Minimum submit seconds [%s]: ' "${MIN_SECONDS}"
   read -r input || true
   [ -n "${input}" ] && MIN_SECONDS="${input}"

   # Enforce Referer Check
   while true; do
      printf 'Enforce Referer Check? [true/false] [%s]: ' "${ENFORCE_REFERER}"
      read -r input || true
      if [ -z "${input}" ]; then
         break
      fi
      input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
      if [[ "$input_lower" == "true" || "$input_lower" == "false" ]]; then
         ENFORCE_REFERER="$input_lower"
         break
      else
         printf 'Please enter true or false only.\n'
      fi
   done

   # CAPTCHA with remembered default
   printf '\nCAPTCHA provider:\n'
   printf '1) Cloudflare Turnstile (recommended)\n'
   printf '2) Google reCAPTCHA v3\n'
   printf '3) hCaptcha\n'
   printf '4) None\n'
   while true; do
      printf 'Choice 1-4 [%s]: ' "${LAST_CHOICE}"
      read -r choice || true
      if [ -z "${choice}" ]; then
         choice="${LAST_CHOICE}"
      fi
      case "${choice}" in
         1|2|3|4) break ;;
         *) printf 'Please enter 1, 2, 3, or 4.\n' ;;
      esac
   done
   LAST_CHOICE="${choice}"
   case "${choice}" in
      1) CAPTCHA_TYPE="turnstile" ;;
      2) CAPTCHA_TYPE="recaptcha" ;;
      3) CAPTCHA_TYPE="hcaptcha" ;;
      4) CAPTCHA_TYPE="none" ;;
   esac

   # Prompt for keys using dedicated function
   prompt_captcha_keys
   return 0
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
   print_header
   SETTINGS=$(load_settings)
   VISDIR_VERSION=$(get_visdir_version)

   # Load existing values (once)
   WEB_ROOT=$(echo "${SETTINGS}" | jq -r '.web_root // empty')
   SCRIPTS_DIR=$(echo "${SETTINGS}" | jq -r '.scripts_dir // empty')
   SITE_TITLE=$(echo "${SETTINGS}" | jq -r '.site_title // "VisDir"')
   URL=$(echo "${SETTINGS}" | jq -r '.url // empty')
   META_DESC=$(echo "${SETTINGS}" | jq -r '.meta_description // empty')
   OG_DESC=$(echo "${SETTINGS}" | jq -r '.og_description // empty')
   CAPTCHA_TYPE=$(echo "${SETTINGS}" | jq -r '.captcha.type // "none"')
   LAST_CHOICE=$(echo "${SETTINGS}" | jq -r '.captcha.last_choice // 4')
   TO_EMAIL=$(echo "${SETTINGS}" | jq -r '.contact.to // empty')
   FROM_EMAIL=$(echo "${SETTINGS}" | jq -r '.contact.from // empty')
   MIN_SECONDS=$(echo "${SETTINGS}" | jq -r '.contact.min_seconds // 3')
   ENFORCE_REFERER=$(echo "${SETTINGS}" | jq -r '.contact.enforce_referer_check // false')

   # Load CAPTCHA keys via dedicated helper
   load_captcha_keys

   # First run of prompts
   ask_all_settings

   # Review / Edit loop
   while true; do
      # Full Settings Summary + Confirmation
      printf '\n=== Deployment Summary ===\n'
      printf 'Web Root: %s\n' "${WEB_ROOT}"
      printf 'Scripts Folder: %s\n' "${SCRIPTS_DIR}"
      printf 'Site Title: %s\n' "${SITE_TITLE}"
      printf 'Base URL: %s\n' "${URL}"
      printf 'Meta Description: %s\n' "${META_DESC}"
      printf 'OG Description: %s\n' "${OG_DESC}"
      printf 'Contact To: %s\n' "${TO_EMAIL}"
      printf 'Contact From: %s\n' "${FROM_EMAIL}"
      printf 'Min Submit Seconds: %s\n' "${MIN_SECONDS}"
      printf 'Enforce Referer Check: %s\n' "${ENFORCE_REFERER}"
      printf 'CAPTCHA Provider: %s\n' "${CAPTCHA_TYPE}"
      if [ "${CAPTCHA_TYPE}" != "none" ]; then
         case "${CAPTCHA_TYPE}" in
            turnstile) printf ' Site Key: %s\n' "${TURNSTILE_SITE_KEY}"; printf ' Secret Key: %s\n' "${TURNSTILE_SECRET_KEY}" ;;
            recaptcha) printf ' Site Key: %s\n' "${RECAPTCHA_SITE_KEY}"; printf ' Secret Key: %s\n' "${RECAPTCHA_SECRET_KEY}" ;;
            hcaptcha) printf ' Site Key: %s\n' "${HCAPTCHA_SITE_KEY}"; printf ' Secret Key: %s\n' "${HCAPTCHA_SECRET_KEY}" ;;
         esac
      fi
      printf '============================\n'
      printf 'Proceed with deployment? [y/e/n]: '
      if ! read -r confirm; then
         log "Input cancelled. Aborting deployment."
         exit 0
      fi

      case "${confirm}" in
         [Yy]) break ;;
         [Ee]) ask_all_settings ;;   # re-prompt using current in-memory values
         [Nn]) log "Deployment cancelled by user."; exit 0 ;;
         *) printf 'Please enter y, e, or n only.\n' ;;
      esac
   done

   # Save settings
   SETTINGS=$(jq -n \
      --arg web_root "${WEB_ROOT}" \
      --arg scripts_dir "${SCRIPTS_DIR}" \
      --arg site_title "${SITE_TITLE}" \
      --arg url "${URL}" \
      --arg meta "${META_DESC}" \
      --arg og "${OG_DESC}" \
      --arg captcha_type "${CAPTCHA_TYPE}" \
      --argjson last_choice "${choice}" \
      --arg turnstile_site_key "${TURNSTILE_SITE_KEY}" \
      --arg turnstile_secret_key "${TURNSTILE_SECRET_KEY}" \
      --arg recaptcha_site_key "${RECAPTCHA_SITE_KEY}" \
      --arg recaptcha_secret_key "${RECAPTCHA_SECRET_KEY}" \
      --arg hcaptcha_site_key "${HCAPTCHA_SITE_KEY}" \
      --arg hcaptcha_secret_key "${HCAPTCHA_SECRET_KEY}" \
      --arg to "${TO_EMAIL}" \
      --arg from "${FROM_EMAIL}" \
      --argjson min_seconds "${MIN_SECONDS}" \
      --argjson enforce_referer_check "${ENFORCE_REFERER}" \
      '{web_root: $web_root, scripts_dir: $scripts_dir, site_title: $site_title, url: $url, meta_description: $meta, og_description: $og, captcha: {type: $captcha_type, last_choice: $last_choice, turnstile: {site_key: $turnstile_site_key, secret_key: $turnstile_secret_key}, recaptcha: {site_key: $recaptcha_site_key, secret_key: $recaptcha_secret_key}, hcaptcha: {site_key: $hcaptcha_site_key, secret_key: $hcaptcha_secret_key}}, contact: {to: $to, from: $from, min_seconds: $min_seconds, enforce_referer_check: $enforce_referer_check}, version: "'${VISDIR_VERSION}'"}')
   save_settings "${SETTINGS}"
   log "Settings saved to ${SETTINGS_FILE}"

   # Permission checks
   [ ! -d "${WEB_ROOT}" ] && mkdir -p "${WEB_ROOT}"
   [ ! -w "${WEB_ROOT}" ] && { error "Web root not writable: ${WEB_ROOT}"; exit 1; }
   [ ! -d "${PROJECT_ROOT}/${ARCHIVE_DIR}" ] && mkdir -p "${PROJECT_ROOT}/${ARCHIVE_DIR}"
   [ ! -w "${PROJECT_ROOT}/${ARCHIVE_DIR}" ] && { error "Archive directory not writable"; exit 1; }

   # Backup if destination has content
   if [ -f "${WEB_ROOT}/index.html" ] || [ -d "${WEB_ROOT}/thumbnails" ]; then
      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      BACKUP_DIR="${PROJECT_ROOT}/${ARCHIVE_DIR}/backup-${TIMESTAMP}"
      mkdir -p "${BACKUP_DIR}"
      log "Creating backup in ${BACKUP_DIR}..."
      cp -a "${WEB_ROOT}" "${BACKUP_DIR}/" 2>/dev/null || true
      log "Backup completed"
   fi

   # Copy files
   DATA_JSON_EXISTED=false
   [ -f "${WEB_ROOT}/data.json" ] && DATA_JSON_EXISTED=true
   log "Copying fresh files to web root..."
   for f in public_html/*; do
      [ "${f##*/}" != "data.json" ] && cp -a "$f" "${WEB_ROOT}/"
   done
   if [ "$DATA_JSON_EXISTED" = true ]; then
      log "data.json already exists - preserving existing file"
   fi
   mkdir -p "${WEB_ROOT}/thumbnails"
   log "Copying scripts to ${SCRIPTS_DIR}..."
   cp -a scripts "${SCRIPTS_DIR}/"

   # data.json + site.name replacement
   if [ ! -f "${WEB_ROOT}/data.json" ]; then
      cp public_html/data.json.example "${WEB_ROOT}/data.json"
   fi
   jq --arg title "${SITE_TITLE}" '.site.name = $title' "${WEB_ROOT}/data.json" > "${WEB_ROOT}/data.json.tmp" && mv "${WEB_ROOT}/data.json.tmp" "${WEB_ROOT}/data.json"
   log "Updated site.name in data.json to '${SITE_TITLE}'"

   # Apply settings
   log "Applying your custom settings..."
   sed -i "s|https://yourdomain.com|${URL}|g" "${WEB_ROOT}/"*.html "${WEB_ROOT}/sitemap.xml" "${WEB_ROOT}/robots.txt"
   sed -i "s|Visual Directory|${SITE_TITLE}|g" "${WEB_ROOT}/"*.html
   # Handle meta description — template may wrap across two lines
   sed -i '/<meta name="description"/{N;s|<meta name="description"\n[[:space:]]*content="[^"]*">|<meta name="description" content="'"${META_DESC}"'">|;}' "${WEB_ROOT}/index.html"
   # Also handle single-line meta description if multi-line sed didn't match
   sed -i "s|<meta name=\"description\" content=\"[^\"]*\">|<meta name=\"description\" content=\"${META_DESC}\">|" "${WEB_ROOT}/index.html"
   # Handle OG description — same approach (multi-line then single-line fallback)
   sed -i '/<meta property="og:description"/{N;s|<meta property="og:description"\n[[:space:]]*content="[^"]*">|<meta property="og:description" content="'"${OG_DESC}"'">|;}' "${WEB_ROOT}/index.html"
   sed -i "s|<meta property=\"og:description\" content=\"[^\"]*\">|<meta property=\"og:description\" content=\"${OG_DESC}\">|" "${WEB_ROOT}/index.html"
   sed -i "s|\$to[[:space:]]*= .*;|\$to = \"${TO_EMAIL}\";|" "${WEB_ROOT}/contact.php"
   sed -i "s|no-reply@yourdomain.com|${FROM_EMAIL}|" "${WEB_ROOT}/contact.php"
   sed -i "s|\$MINIMUM_SUBMIT_SECONDS = .*;|\$MINIMUM_SUBMIT_SECONDS = ${MIN_SECONDS};|" "${WEB_ROOT}/contact.php"
   sed -i "s|\$ENFORCE_REFERER_CHECK = .*;|\$ENFORCE_REFERER_CHECK = ${ENFORCE_REFERER};|" "${WEB_ROOT}/contact.php"

   if [ "${SCRIPTS_DIR}" != "$(dirname "${WEB_ROOT}")/scripts" ]; then
      RELATIVE_PATH=$(realpath --relative-to="${SCRIPTS_DIR}" "${WEB_ROOT}")
      sed -i "s|PROJECT_DIR = Path(\"../public_html\").resolve()|PROJECT_DIR = Path(\"${RELATIVE_PATH}\").resolve()|" "${SCRIPTS_DIR}/update-thumbnails.py"
   fi

   if [ "${CAPTCHA_TYPE}" != "none" ]; then
      log "Activating ${CAPTCHA_TYPE} CAPTCHA..."
      case "${CAPTCHA_TYPE}" in
         turnstile)
            SITE_KEY="${TURNSTILE_SITE_KEY}"
            SECRET="${TURNSTILE_SECRET_KEY}"
            MARKER="TURNSTILE"
            ;;
         recaptcha)
            SITE_KEY="${RECAPTCHA_SITE_KEY}"
            SECRET="${RECAPTCHA_SECRET_KEY}"
            MARKER="RECAPTCHA"
            ;;
         hcaptcha)
            SITE_KEY="${HCAPTCHA_SITE_KEY}"
            SECRET="${HCAPTCHA_SECRET_KEY}"
            MARKER="HCAPTCHA"
            ;;
      esac
      # Activate individual CAPTCHA blocks
      sed -i "s|${MARKER}-BEGIN|${MARKER}-BEGIN -->|" "${WEB_ROOT}/contact.html"
      sed -i "s|${MARKER}-END|<!-- ${MARKER}-END|" "${WEB_ROOT}/contact.html"
      sed -i "s|${MARKER}-BEGIN|${MARKER}-BEGIN */|" "${WEB_ROOT}/contact.php"
      sed -i "s|${MARKER}-END|/* ${MARKER}-END|" "${WEB_ROOT}/contact.php"
      # Replace SITE_KEY and secret in HTML and PHP templates
      sed -i "s|${MARKER}_SITE_KEY|${SITE_KEY}|g" "${WEB_ROOT}/contact.html" "${WEB_ROOT}/contact.php"
      sed -i "s|${MARKER}_SECRET_KEY|${SECRET}|g" "${WEB_ROOT}/contact.php"
   fi

   log "Deployment completed successfully!"
   printf '\n=== Next Steps ===\n'
   printf '1. Edit %s/data.json with your real directory data\n' "${WEB_ROOT}"
   printf '2. Run thumbnail updater:\n cd %s && ./update-thumbnails.sh\n' "${SCRIPTS_DIR}"
   printf '3. Add to cron (daily at 3 AM):\n'
   printf ' 0 3 * * * %s/update-thumbnails.sh >/dev/null 2>&1\n\n' "${SCRIPTS_DIR}"
   printf 'For issues or discussions: https://github.com/seancrites/visdir\n\n'

   exit 0
}

main "$@"
