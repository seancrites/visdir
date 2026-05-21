#!/usr/bin/env bash
# =============================================================================
# resize-thumbnail.sh
#
# PURPOSE: Wrapper to run resize-thumbnail.py inside the VisDir virtualenv
#          (same environment used by update-thumbnails.sh)
#
# USAGE:
#   ./scripts/resize-thumbnail.sh large-screenshot.png
#   ./scripts/resize-thumbnail.sh sv1.png sv2.png
#
# NOTES FOR FUTURE README.md MERGE:
#   Add under "Thumbnail Setup":
#     ## Manual Thumbnail Resizer
#     For large screenshots (e.g. Google Street View):
#       ./scripts/resize-thumbnail.sh your-image.png
#
# AUTHOR: Sean Crites
# VERSION: v2.0.1
# DATE: 2026-05-15
# =============================================================================

set -eo pipefail

# ========================== CONFIGURATION ==================================
VENV_DIR="${HOME}/visdir-env"
SCRIPTS_DIR="$(dirname "$(realpath "$0")")"

# ========================== MAIN LOGIC =====================================

echo "=== VisDir Manual Thumbnail Resizer ==="
echo "Venv      : ${VENV_DIR}"
echo "─────────────────────────────────────"

(
    set +u
    source "${VENV_DIR}/bin/activate"
    set -u

    cd "${SCRIPTS_DIR}"
    python3 resize-thumbnail.py "$@"
)

echo "─────────────────────────────────────"
echo "✓ Done at $(date '+%Y-%m-%d %H:%M:%S')"
