#!/usr/bin/env bash
# =============================================================================
# deploy.sh
#
# PURPOSE: One-command deploy and upgrade script for VisDir.
#          Handles first-time installation and future upgrades after git pull.
#          Saves user customizations in deploy-settings.json (gitignored).
# AUTHOR: Sean Crites
# VERSION: 1.0.0
# DATE: 2026-05-09
# BASHISMS: Yes (JSON handling, interactive flow)
# DEPENDENCIES: bash, sed, jq (recommended), git, mkdir, cp, chmod
#
# USAGE: ./deploy.sh
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

# Load current VisDir version from VERSION file
get_visdir_version() {
    if [ -f "${VERSION_FILE}" ]; then
        tr -d '[:space:]' < "${VERSION_FILE}"
    else
        printf "unknown"
    fi
}

# Load or create settings file
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

    # Load existing values or empty
    WEB_ROOT=$(echo "${SETTINGS}" | jq -r '.web_root // empty')
    SCRIPTS_DIR=$(echo "${SETTINGS}" | jq -r '.scripts_dir // empty')
    SITE_TITLE=$(echo "${SETTINGS}" | jq -r '.site_title // "VisDir"')
    URL=$(echo "${SETTINGS}" | jq -r '.url // empty')
    META_DESC=$(echo "${SETTINGS}" | jq -r '.meta_description // empty')
    OG_DESC=$(echo "${SETTINGS}" | jq -r '.og_description // empty')
    CAPTCHA_TYPE=$(echo "${SETTINGS}" | jq -r '.captcha.type // "none"')
    CAPTCHA_SITEKEY=$(echo "${SETTINGS}" | jq -r '.captcha.sitekey // empty')
    CAPTCHA_SECRET=$(echo "${SETTINGS}" | jq -r '.captcha.secret // empty')
    TO_EMAIL=$(echo "${SETTINGS}" | jq -r '.contact.to // empty')
    FROM_EMAIL=$(echo "${SETTINGS}" | jq -r '.contact.from // empty')
    MIN_SECONDS=$(echo "${SETTINGS}" | jq -r '.contact.min_seconds // 3')

    # === Interactive prompts (show saved value in [brackets] on repeat runs) ===
    if [ -z "${WEB_ROOT}" ]; then
        printf 'Web root folder (where index.html should live): '
        read -r WEB_ROOT
    else
        printf 'Web root folder [%s]: ' "${WEB_ROOT}"
        read -r input
        [ -n "${input}" ] && WEB_ROOT="${input}"
    fi

    # Default scripts_dir = parent of web_root
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
        DOMAIN=$(echo "${WEB_ROOT}" | sed -E 's|https?://||; s|/.*||')
        FROM_EMAIL="no-reply@${DOMAIN}"
        printf 'Contact form "From" address [%s]: ' "${FROM_EMAIL}"
        read -r input
        [ -n "${input}" ] && FROM_EMAIL="${input}"
    else
        printf 'Contact form "From" address [%s]: ' "${FROM_EMAIL}"
        read -r input
        [ -n "${input}" ] && FROM_EMAIL="${input}"
    fi

    # CAPTCHA selection
    if [ "${CAPTCHA_TYPE}" = "none" ] || [ -z "${CAPTCHA_TYPE}" ]; then
        printf '\nCAPTCHA provider:\n'
        printf '1) Cloudflare Turnstile (recommended)\n'
        printf '2) Google reCAPTCHA v3\n'
        printf '3) hCaptcha\n'
        printf '4) None (invisible protections only)\n'
        printf 'Choice [1-4]: '
        read -r choice
        case "${choice}" in
            1) CAPTCHA_TYPE="turnstile" ;;
            2) CAPTCHA_TYPE="recaptcha" ;;
            3) CAPTCHA_TYPE="hcaptcha" ;;
            *) CAPTCHA_TYPE="none" ;;
        esac
    fi

    if [ "${CAPTCHA_TYPE}" != "none" ] && [ -z "${CAPTCHA_SITEKEY}" ]; then
        printf 'CAPTCHA Site Key: '
        read -r CAPTCHA_SITEKEY
        printf 'CAPTCHA Secret Key: '
        read -r CAPTCHA_SECRET
    fi

    # Save settings
    SETTINGS=$(jq -n \
        --arg web_root "${WEB_ROOT}" \
        --arg scripts_dir "${SCRIPTS_DIR}" \
        --arg site_title "${SITE_TITLE}" \
        --arg url "${URL}" \
        --arg dest "${DEST}" \
        --arg meta "${META_DESC}" \
        --arg og "${OG_DESC}" \
        --arg captcha_type "${CAPTCHA_TYPE}" \
        --arg sitekey "${CAPTCHA_SITEKEY}" \
        --arg secret "${CAPTCHA_SECRET}" \
        --arg to "${TO_EMAIL}" \
        --arg from "${FROM_EMAIL}" \
        --argjson min_seconds "${MIN_SECONDS}" \
        '{url: $url, destination: $dest, meta_description: $meta, og_description: $og, captcha: {type: $captcha_type, sitekey: $sitekey, secret: $secret}, contact: {to: $to, from: $from, min_seconds: $min_seconds}, version: "'${VISDIR_VERSION}'"}')

    save_settings "${SETTINGS}"
    log "Settings saved to ${SETTINGS_FILE}"

    # Permission checks
    [ ! -d "${DEST}" ] && mkdir -p "${DEST}"
    [ ! -w "${DEST}" ] && { error "Destination not writable: ${DEST}"; exit 1; }

    [ ! -d "${PROJECT_ROOT}/${ARCHIVE_DIR}" ] && mkdir -p "${PROJECT_ROOT}/${ARCHIVE_DIR}"
    [ ! -w "${PROJECT_ROOT}/${ARCHIVE_DIR}" ] && { error "Archive directory not writable"; exit 1; }

    # Backup if destination has content
    if [ -d "${DEST}/public_html" ] || [ -d "${DEST}/scripts" ]; then
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        BACKUP_DIR="${PROJECT_ROOT}/${ARCHIVE_DIR}/backup-${TIMESTAMP}"
        mkdir -p "${BACKUP_DIR}"
        log "Creating backup in ${BACKUP_DIR}..."
        cp -a "${DEST}/public_html" "${BACKUP_DIR}/" 2>/dev/null || true
        cp -a "${DEST}/scripts" "${BACKUP_DIR}/" 2>/dev/null || true
        log "Backup completed"
    fi

    # Copy fresh files
    log "Copying fresh files to ${DEST}..."
    cp -a public_html "${DEST}/"
    cp -a scripts "${DEST}/"
    mkdir -p "${DEST}/public_html/thumbnails"

    if [ ! -f "${DEST}/public_html/data.json" ]; then
        cp public_html/data.json.example "${DEST}/public_html/data.json"
        log "Created public_html/data.json from example. Please edit it with your real data."
    fi

    # Apply settings
    log "Applying your custom settings..."

    # URL
    sed -i "s|https://yourdomain.com|${URL}|g" "${DEST}/public_html/"*.html "${DEST}/public_html/sitemap.xml" "${DEST}/public_html/robots.txt"

    # Meta tags
    sed -i "s|<meta name=\"description\" content=\"[^\"]*\">|<meta name=\"description\" content=\"${META_DESC}\">|" "${DEST}/public_html/index.html"
    sed -i "s|<meta property=\"og:description\" content=\"[^\"]*\">|<meta property=\"og:description\" content=\"${OG_DESC}\">|" "${DEST}/public_html/index.html"

    # Contact.php
    sed -i "s|\$to = .*;|\$to = \"${TO_EMAIL}\";|" "${DEST}/public_html/contact.php"
    sed -i "s|no-reply@yourdomain.com|${FROM_EMAIL}|" "${DEST}/public_html/contact.php"
    sed -i "s|\$MINIMUM_SUBMIT_SECONDS = .*;|\$MINIMUM_SUBMIT_SECONDS = ${MIN_SECONDS};|" "${DEST}/public_html/contact.php"

    # CAPTCHA handling
    log "Configuring CAPTCHA..."
    if [ "${CAPTCHA_TYPE}" = "turnstile" ]; then
        sed -i '/Cloudflare Turnstile (Recommended)/,/<\/div>/s/<!-- //' "${DEST}/public_html/contact.html"
        sed -i '/Cloudflare Turnstile (Recommended)/,/<\/div>/s| -->||' "${DEST}/public_html/contact.html"
        sed -i '/--- Cloudflare Turnstile (Recommended) ---/,/^\*\//s|^/\*||; /^\*\//s|^\*/||' "${DEST}/public_html/contact.php"
    elif [ "${CAPTCHA_TYPE}" = "recaptcha" ]; then
        sed -i '/Google reCAPTCHA v3/,/<\/script>/s/<!-- //' "${DEST}/public_html/contact.html"
        sed -i '/Google reCAPTCHA v3/,/<\/script>/s| -->||' "${DEST}/public_html/contact.html"
        sed -i '/--- Google reCAPTCHA v3 ---/,/^\*\//s|^/\*||; /^\*\//s|^\*/||' "${DEST}/public_html/contact.php"
    elif [ "${CAPTCHA_TYPE}" = "hcaptcha" ]; then
        sed -i '/hCaptcha/,/<\/div>/s/<!-- //' "${DEST}/public_html/contact.html"
        sed -i '/hCaptcha/,/<\/div>/s| -->||' "${DEST}/public_html/contact.html"
        sed -i '/--- hCaptcha ---/,/^\*\//s|^/\*||; /^\*\//s|^\*/||' "${DEST}/public_html/contact.php"
    else
        # None - ensure all are commented
        sed -i '/Cloudflare Turnstile/,/<\/div>/s|^|<!-- |; /<\/div>/s|$| -->|' "${DEST}/public_html/contact.html"
        sed -i '/Google reCAPTCHA v3/,/<\/script>/s|^|<!-- |; /<\/script>/s|$| -->|' "${DEST}/public_html/contact.html"
        sed -i '/hCaptcha/,/<\/div>/s|^|<!-- |; /<\/div>/s|$| -->|' "${DEST}/public_html/contact.html"
        sed -i '/--- Cloudflare Turnstile/,/^\*\//s|^|/*|; /^\*\//s|$|*/|' "${DEST}/public_html/contact.php"
        sed -i '/--- Google reCAPTCHA v3 ---/,/^\*\//s|^|/*|; /^\*\//s|$|*/|' "${DEST}/public_html/contact.php"
        sed -i '/--- hCaptcha ---/,/^\*\//s|^|/*|; /^\*\//s|$|*/|' "${DEST}/public_html/contact.php"
    fi

    log "Deployment completed successfully!"

    printf '\n=== Next Steps ===\n'
    printf '1. Edit %s/public_html/data.json with your real directory data\n' "${DEST}"
    printf '2. Run thumbnail updater:\n   cd %s && ./scripts/update-thumbnails.sh\n' "${DEST}"
    printf '3. Add to cron (daily at 3 AM):\n'
    printf '   0 3 * * * %s/scripts/update-thumbnails.sh >/dev/null 2>&1\n\n' "${DEST}"
    printf 'For issues or discussions: https://github.com/seancrites/visdir\n'

    exit 0
}

main "$@"
