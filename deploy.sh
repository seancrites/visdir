#!/usr/bin/env bash
# =============================================================================
# deploy.sh
#
# PURPOSE: One-command deploy and upgrade script for VisDir.
# Handles first-time installation and future upgrades after git pull.
# Saves user customizations in deploy-settings.json (gitignored).
# AUTHOR: Sean Crites
# VERSION: 1.0.0
# DATE: 2026-05-09
# DEPENDENCIES: bash, sed, jq (recommended), git, mkdir, cp, chmod
# =============================================================================
set -euo pipefail
# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
SETTINGS_FILE="deploy-settings.json"
ARCHIVE_DIR="archive"
PROJECT_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
VERSION_FILE="${PROJECT_ROOT}/VERSION"
# ----------------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------------
print_header() {
    printf '\n=== VisDir Deploy / Upgrade Tool ===\n\n'
}
log() { printf '[deploy] %s\n' "$1"; }
error() { printf 'ERROR: %s\n' "$1" >&2; }
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
# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
    print_header
    SETTINGS=$(load_settings)
    VISDIR_VERSION=$(get_visdir_version)

    # Load existing values
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

    # === Prompts with [current value] in brackets ===
    if [ -z "${WEB_ROOT}" ]; then
        printf 'Web root folder (where index.html should live): '
        read -r WEB_ROOT
    else
        printf 'Web root folder [%s]: ' "${WEB_ROOT}"
        read -r input
        [ -n "${input}" ] && WEB_ROOT="${input}"
    fi

    DEFAULT_SCRIPTS="$(dirname "${WEB_ROOT}")/scripts"
    if [ -z "${SCRIPTS_DIR}" ]; then
        SCRIPTS_DIR="${DEFAULT_SCRIPTS}"
        printf 'Scripts folder [%s]: ' "${SCRIPTS_DIR}"
        read -r input
        [ -n "${input}" ] && SCRIPTS_DIR="${input}"
    else
        printf 'Scripts folder [%s]: ' "${SCRIPTS_DIR}"
        read -r input
        [ -n "${input}" ] && SCRIPTS_DIR="${input}"
    fi

    if [ -z "${SITE_TITLE}" ] || [ "${SITE_TITLE}" = "VisDir" ]; then
        printf 'Site title [%s]: ' "${SITE_TITLE}"
        read -r input
        [ -n "${input}" ] && SITE_TITLE="${input}"
    fi

    if [ -z "${URL}" ] || [[ "${URL}" != http* ]]; then
        while true; do
            printf 'Base URL (must start with http:// or https://): '
            read -r URL
            if [[ "${URL}" == http* ]]; then
                break
            else
                printf 'ERROR: URL must include http:// or https://\n'
            fi
        done
    else
        printf 'Base URL [%s]: ' "${URL}"
        read -r input
        [ -n "${input}" ] && URL="${input}"
    fi

    [ -z "${META_DESC}" ] && { printf '\nMeta description (search results):\n'; read -r META_DESC; } || { printf 'Meta description [%s]: ' "${META_DESC}"; read -r input; [ -n "${input}" ] && META_DESC="${input}"; }
    [ -z "${OG_DESC}" ] && { printf '\nOpen Graph description (social shares):\n'; read -r OG_DESC; } || { printf 'Open Graph description [%s]: ' "${OG_DESC}"; read -r input; [ -n "${input}" ] && OG_DESC="${input}"; }
    [ -z "${TO_EMAIL}" ] && { printf '\nContact form "To" email: '; read -r TO_EMAIL; } || { printf 'Contact form "To" email [%s]: ' "${TO_EMAIL}"; read -r input; [ -n "${input}" ] && TO_EMAIL="${input}"; }

    if [ -z "${FROM_EMAIL}" ]; then
        DOMAIN=$(echo "${URL}" | sed -E 's|https?://([^/]+).*|\1|')
        FROM_EMAIL="no-reply@${DOMAIN}"
        printf 'Contact form "From" address [%s]: ' "${FROM_EMAIL}"
        read -r input
        [ -n "${input}" ] && FROM_EMAIL="${input}"
    else
        printf 'Contact form "From" address [%s]: ' "${FROM_EMAIL}"
        read -r input
        [ -n "${input}" ] && FROM_EMAIL="${input}"
    fi

    # === NEW: Minimum Submit Seconds ===
    printf 'Minimum submit seconds [%s]: ' "${MIN_SECONDS}"
    read -r input
    [ -n "${input}" ] && MIN_SECONDS="${input}"

    # === NEW: Enforce Referer Check ===
    printf 'Enforce Referer Check? [%s]: ' "${ENFORCE_REFERER}"
    read -r input
    [ -n "${input}" ] && ENFORCE_REFERER="${input}"

    # === CAPTCHA with remembered default ===
    printf '\nCAPTCHA provider:\n'
    printf '1) Cloudflare Turnstile (recommended)\n'
    printf '2) Google reCAPTCHA v3\n'
    printf '3) hCaptcha\n'
    printf '4) None\n'
    printf 'Choice 1-4 [%s]: ' "${LAST_CHOICE}"
    read -r choice
    if [ -z "${choice}" ]; then
        choice="${LAST_CHOICE}"
    fi
    case "${choice}" in
        1) CAPTCHA_TYPE="turnstile" ;;
        2) CAPTCHA_TYPE="recaptcha" ;;
        3) CAPTCHA_TYPE="hcaptcha" ;;
        *) CAPTCHA_TYPE="none" ;;
    esac

    # Load or ask for keys
    TURNSTILE_SITEKEY=$(echo "${SETTINGS}" | jq -r '.captcha.turnstile.sitekey // empty')
    TURNSTILE_SECRET=$(echo "${SETTINGS}" | jq -r '.captcha.turnstile.secret // empty')
    RECAPTCHA_SITEKEY=$(echo "${SETTINGS}" | jq -r '.captcha.recaptcha.sitekey // empty')
    RECAPTCHA_SECRET=$(echo "${SETTINGS}" | jq -r '.captcha.recaptcha.secret // empty')
    HCAPTCHA_SITEKEY=$(echo "${SETTINGS}" | jq -r '.captcha.hcaptcha.sitekey // empty')
    HCAPTCHA_SECRET=$(echo "${SETTINGS}" | jq -r '.captcha.hcaptcha.secret // empty')

    if [ "${CAPTCHA_TYPE}" != "none" ]; then
        case "${CAPTCHA_TYPE}" in
            turnstile)
                [ -z "${TURNSTILE_SITEKEY}" ] && { printf 'Cloudflare Turnstile Site Key: '; read -r TURNSTILE_SITEKEY; }
                [ -z "${TURNSTILE_SECRET}" ] && { printf 'Cloudflare Turnstile Secret Key: '; read -r TURNSTILE_SECRET; }
                ;;
            recaptcha)
                [ -z "${RECAPTCHA_SITEKEY}" ] && { printf 'Google reCAPTCHA v3 Site Key: '; read -r RECAPTCHA_SITEKEY; }
                [ -z "${RECAPTCHA_SECRET}" ] && { printf 'Google reCAPTCHA v3 Secret Key: '; read -r RECAPTCHA_SECRET; }
                ;;
            hcaptcha)
                [ -z "${HCAPTCHA_SITEKEY}" ] && { printf 'hCaptcha Site Key: '; read -r HCAPTCHA_SITEKEY; }
                [ -z "${HCAPTCHA_SECRET}" ] && { printf 'hCaptcha Secret Key: '; read -r HCAPTCHA_SECRET; }
                ;;
        esac
    fi

    # === Full Settings Summary + Confirmation ===
    printf '\n=== Deployment Summary ===\n'
    printf 'Web Root: %s\n' "${WEB_ROOT}"
    printf 'Scripts Folder: %s\n' "${SCRIPTS_DIR}"
    printf 'Site Title: %s\n' "${SITE_TITLE}"
    printf 'Base URL: %s\n' "${URL}"
    printf 'Meta Description: %s\n' "${META_DESC}"
    printf 'OG Description: %s\n' "${OG_DESC}"
    printf 'CAPTCHA Provider: %s\n' "${CAPTCHA_TYPE}"
    if [ "${CAPTCHA_TYPE}" != "none" ]; then
        case "${CAPTCHA_TYPE}" in
            turnstile) printf ' Site Key: %s\n' "${TURNSTILE_SITEKEY}"; printf ' Secret Key: %s\n' "${TURNSTILE_SECRET}" ;;
            recaptcha) printf ' Site Key: %s\n' "${RECAPTCHA_SITEKEY}"; printf ' Secret Key: %s\n' "${RECAPTCHA_SECRET}" ;;
            hcaptcha) printf ' Site Key: %s\n' "${HCAPTCHA_SITEKEY}"; printf ' Secret Key: %s\n' "${HCAPTCHA_SECRET}" ;;
        esac
    fi
    printf 'Contact To: %s\n' "${TO_EMAIL}"
    printf 'Contact From: %s\n' "${FROM_EMAIL}"
    printf 'Min Submit Seconds: %s\n' "${MIN_SECONDS}"
    printf 'Enforce Referer Check: %s\n' "${ENFORCE_REFERER}"
    printf '============================\n'

    printf 'Proceed with deployment? [y/N]: '
    read -r confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user."
        exit 0
    fi

    # Save settings (including new fields)
    SETTINGS=$(jq -n \
        --arg web_root "${WEB_ROOT}" \
        --arg scripts_dir "${SCRIPTS_DIR}" \
        --arg site_title "${SITE_TITLE}" \
        --arg url "${URL}" \
        --arg meta "${META_DESC}" \
        --arg og "${OG_DESC}" \
        --arg captcha_type "${CAPTCHA_TYPE}" \
        --argjson last_choice "${choice}" \
        --arg turnstile_sitekey "${TURNSTILE_SITEKEY}" \
        --arg turnstile_secret "${TURNSTILE_SECRET}" \
        --arg recaptcha_sitekey "${RECAPTCHA_SITEKEY}" \
        --arg recaptcha_secret "${RECAPTCHA_SECRET}" \
        --arg hcaptcha_sitekey "${HCAPTCHA_SITEKEY}" \
        --arg hcaptcha_secret "${HCAPTCHA_SECRET}" \
        --arg to "${TO_EMAIL}" \
        --arg from "${FROM_EMAIL}" \
        --argjson min_seconds "${MIN_SECONDS}" \
        --argjson enforce_referer_check "${ENFORCE_REFERER}" \
        '{web_root: $web_root, scripts_dir: $scripts_dir, site_title: $site_title, url: $url, meta_description: $meta, og_description: $og, captcha: {type: $captcha_type, last_choice: $last_choice, turnstile: {sitekey: $turnstile_sitekey, secret: $turnstile_secret}, recaptcha: {sitekey: $recaptcha_sitekey, secret: $recaptcha_secret}, hcaptcha: {sitekey: $hcaptcha_sitekey, secret: $hcaptcha_secret}}, contact: {to: $to, from: $from, min_seconds: $min_seconds, enforce_referer_check: $enforce_referer_check}, version: "'${VISDIR_VERSION}'"}')

    save_settings "${SETTINGS}"
    log "Settings saved to ${SETTINGS_FILE}"

    # === Permission checks ===
    [ ! -d "${WEB_ROOT}" ] && mkdir -p "${WEB_ROOT}"
    [ ! -w "${WEB_ROOT}" ] && { error "Web root not writable: ${WEB_ROOT}"; exit 1; }
    [ ! -d "${PROJECT_ROOT}/${ARCHIVE_DIR}" ] && mkdir -p "${PROJECT_ROOT}/${ARCHIVE_DIR}"
    [ ! -w "${PROJECT_ROOT}/${ARCHIVE_DIR}" ] && { error "Archive directory not writable"; exit 1; }

    # === Backup if destination has content ===
    if [ -f "${WEB_ROOT}/index.html" ] || [ -d "${WEB_ROOT}/thumbnails" ]; then
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        BACKUP_DIR="${PROJECT_ROOT}/${ARCHIVE_DIR}/backup-${TIMESTAMP}"
        mkdir -p "${BACKUP_DIR}"
        log "Creating backup in ${BACKUP_DIR}..."
        cp -a "${WEB_ROOT}" "${BACKUP_DIR}/" 2>/dev/null || true
        log "Backup completed"
    fi

    # === Copy files ===
    log "Copying fresh files to web root..."
    cp -a public_html/* "${WEB_ROOT}/"
    mkdir -p "${WEB_ROOT}/thumbnails"

    log "Copying scripts to ${SCRIPTS_DIR}..."
    cp -a scripts "${SCRIPTS_DIR}/"

    # data.json + site.name replacement
    if [ ! -f "${WEB_ROOT}/data.json" ]; then
        cp public_html/data.json.example "${WEB_ROOT}/data.json"
    fi
    jq --arg title "${SITE_TITLE}" '.site.name = $title' "${WEB_ROOT}/data.json" > "${WEB_ROOT}/data.json.tmp" && mv "${WEB_ROOT}/data.json.tmp" "${WEB_ROOT}/data.json"
    log "Updated site.name in data.json to '${SITE_TITLE}'"

    # === Apply settings ===
    log "Applying your custom settings..."

    # URL
    sed -i "s|https://yourdomain.com|${URL}|g" "${WEB_ROOT}/"*.html "${WEB_ROOT}/sitemap.xml" "${WEB_ROOT}/robots.txt"

    # Site title
    sed -i "s|VisDir|${SITE_TITLE}|g" "${WEB_ROOT}/"*.html

    # Meta tags
    sed -i "s|<meta name=\"description\" content=\"[^\"]*\">|<meta name=\"description\" content=\"${META_DESC}\">|" "${WEB_ROOT}/index.html"
    sed -i "s|<meta property=\"og:description\" content=\"[^\"]*\">|<meta property=\"og:description\" content=\"${OG_DESC}\">|" "${WEB_ROOT}/index.html"

    # Contact.php
    sed -i "s|\$to = .*;|\$to = \"${TO_EMAIL}\";|" "${WEB_ROOT}/contact.php"
    sed -i "s|no-reply@yourdomain.com|${FROM_EMAIL}|" "${WEB_ROOT}/contact.php"
    sed -i "s|\$MINIMUM_SUBMIT_SECONDS = .*;|\$MINIMUM_SUBMIT_SECONDS = ${MIN_SECONDS};|" "${WEB_ROOT}/contact.php"
    sed -i "s|\$ENFORCE_REFERER_CHECK = .*;|\$ENFORCE_REFERER_CHECK = ${ENFORCE_REFERER};|" "${WEB_ROOT}/contact.php"

    # Update update-thumbnails.py if needed
    if [ "${SCRIPTS_DIR}" != "$(dirname "${WEB_ROOT}")/scripts" ]; then
        RELATIVE_PATH=$(realpath --relative-to="${SCRIPTS_DIR}" "${WEB_ROOT}")
        sed -i "s|PROJECT_DIR = Path(\"../public_html\").resolve()|PROJECT_DIR = Path(\"${RELATIVE_PATH}\").resolve()|" "${SCRIPTS_DIR}/update-thumbnails.py"
    fi

    # === CAPTCHA Activation ===
    if [ "${CAPTCHA_TYPE}" != "none" ]; then
        log "Activating ${CAPTCHA_TYPE} CAPTCHA..."
        case "${CAPTCHA_TYPE}" in
            turnstile)
                SITEKEY="${TURNSTILE_SITEKEY}"
                SECRET="${TURNSTILE_SECRET}"
                MARKER="CLOUDFLARE-TURNSTILE"
                ;;
            recaptcha)
                SITEKEY="${RECAPTCHA_SITEKEY}"
                SECRET="${RECAPTCHA_SECRET}"
                MARKER="GOOGLE-RECAPTCHA-V3"
                ;;
            hcaptcha)
                SITEKEY="${HCAPTCHA_SITEKEY}"
                SECRET="${HCAPTCHA_SECRET}"
                MARKER="HCAPTCHA"
                ;;
        esac

        # Activate all matching segments in contact.html
        sed -i "/${MARKER}-BEGIN/s|${MARKER}-BEGIN|${MARKER}-BEGIN -->|" "${WEB_ROOT}/contact.html"
        sed -i "/${MARKER}-END/s|${MARKER}-END|${MARKER}-END -->|" "${WEB_ROOT}/contact.html"

        # Activate all matching segments in contact.php
        sed -i "/${MARKER}-BEGIN/s|${MARKER}-BEGIN|${MARKER}-BEGIN */|" "${WEB_ROOT}/contact.php"
        sed -i "/${MARKER}-END/s|${MARKER}-END|${MARKER}-END */|" "${WEB_ROOT}/contact.php"

        # Replace placeholder keys
        sed -i "s|YOUR_${MARKER}_SITE_KEY_HERE|${SITEKEY}|g" "${WEB_ROOT}/contact.html" "${WEB_ROOT}/contact.php"
        sed -i "s|YOUR_${MARKER}_SECRET_KEY_HERE|${SECRET}|g" "${WEB_ROOT}/contact.php"
    fi

    log "Deployment completed successfully!"

    printf '\n=== Next Steps ===\n'
    printf '1. Edit %s/data.json with your real directory data\n' "${WEB_ROOT}"
    printf '2. Run thumbnail updater:\n   cd %s && ./update-thumbnails.sh\n' "${SCRIPTS_DIR}"
    printf '3. Add to cron (daily at 3 AM):\n'
    printf '   0 3 * * * %s/update-thumbnails.sh >/dev/null 2>&1\n\n' "${SCRIPTS_DIR}"
    printf 'For issues or discussions: https://github.com/seancrites/visdir\n'

    exit 0
}

main "$@"
