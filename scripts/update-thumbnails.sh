#!/usr/bin/env bash
# =============================================================================
# update-thumbnails.sh
#
# PURPOSE: One-command thumbnail updater for VisDir
#          (activate venv → run → deactivate)
#
# AUTHOR: Generated for the visdir project
# VERSION: 1.4.0
# DATE: 2026-04-23
# =============================================================================

set -eo pipefail

# ========================== CONFIGURATION ==================================
VENV_DIR="${HOME}/visdir-env"
SCRIPTS_DIR="$(dirname "$(realpath "$0")")"

# ========================== OPTIONAL LOGGING ===============================
# Uncomment the two lines below to enable logging
# LOG_FILE="${HOME}/visdir-thumbnail-update.log"
# LOG_ENABLED=true

# ========================== MAIN LOGIC =====================================

echo "=== VisDir Thumbnail Updater ==="
echo "Venv      : ${VENV_DIR}"
echo "Scripts   : ${SCRIPTS_DIR}"
echo "─────────────────────────────────────"

# Optional logging
if [[ "${LOG_ENABLED:-false}" == "true" && -n "${LOG_FILE:-}" ]]; then
    exec >> "${LOG_FILE}" 2>&1
    echo "=== Log started at $(date '+%Y-%m-%d %H:%M:%S') ==="
fi

# Run the process safely
(
    set +u
    source "${VENV_DIR}/bin/activate"
    set -u

    cd "${SCRIPTS_DIR}"
    python update-thumbnails.py
)

echo "─────────────────────────────────────"
echo "✓ Thumbnail update completed successfully at $(date '+%Y-%m-%d %H:%M:%S')"

if [[ "${LOG_ENABLED:-false}" == "true" && -n "${LOG_FILE:-}" ]]; then
    echo "=== Log ended at $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo ""
fi
