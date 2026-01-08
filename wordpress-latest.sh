#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# WordPress Latest Installer / Updater
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/wordpress-latest.sh | bash -s -- core
#   curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/wordpress-latest.sh | bash -s -- install
#   curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/wordpress-latest.sh | bash -s -- overwrite
#
# If no mode is given, it prints help and exits.
#
# Optional env vars:
#   WP_TARGET_DIR="/path/to/site"   (default: current directory)
#
# Modes:
#   core      -> copy ONLY WP core (keeps wp-content + wp-config.php)
#   install   -> full install (copies wp-content, keeps existing wp-config.php)
#   overwrite -> full overwrite (copies wp-content + wp-config.php)
# ------------------------------------------------------------

WP_TARGET_DIR="${WP_TARGET_DIR:-$(pwd)}"
MODE="${1:-}"

print_help() {
  echo
  echo "=============================="
  echo " WordPress Latest Installer"
  echo "=============================="
  echo
  echo "Target directory (default): current directory"
  echo
  echo "USAGE:"
  echo "  # Core update (safe for existing sites)"
  echo "  curl -fsSL <SCRIPT_URL> | bash -s -- core"
  echo
  echo "  # Full install (for empty folders / new site)"
  echo "  curl -fsSL <SCRIPT_URL> | bash -s -- install"
  echo
  echo "  # Full overwrite (DESTRUCTIVE)"
  echo "  curl -fsSL <SCRIPT_URL> | bash -s -- overwrite"
  echo
  echo "OPTIONAL:"
  echo "  WP_TARGET_DIR=\"/path/to/site\" curl -fsSL <SCRIPT_URL> | bash -s -- core"
  echo
  echo "EXAMPLE:"
  echo "  WP_TARGET_DIR=\"/data/sites/web/1337rbe/subsites/tcarail.107.be\" \\"
  echo "    curl -fsSL https://raw.githubusercontent.com/lukave/devops-scripts/main/wordpress-latest.sh | bash -s -- install"
  echo
  echo "MODES:"
  echo "  core      -> copy only WP core (keeps wp-content + wp-config.php)"
  echo "  install   -> full install (includes wp-content, keeps existing wp-config.php)"
  echo "  overwrite -> full overwrite (includes wp-content + wp-config.php)"
  echo
}

# --- If no mode given: show help and exit ---
if [[ -z "${MODE}" ]]; then
  print_help
  exit 0
fi

# --- Validate mode ---
case "${MODE}" in
  core|install|overwrite) ;;
  -h|--help|help)
    print_help
    exit 0
    ;;
  *)
    echo "ERROR: Unknown mode '${MODE}'."
    print_help
    exit 1
    ;;
esac

# --- Preconditions ---
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not installed"; exit 1; }
command -v tar  >/dev/null 2>&1 || { echo "ERROR: tar not installed"; exit 1; }

if [[ ! -d "${WP_TARGET_DIR}" ]]; then
  echo "ERROR: Target directory does not exist: ${WP_TARGET_DIR}"
  exit 1
fi

# --- Detection logic (for warnings only) ---
HAS_WP_CONFIG="0"
HAS_WP_CONTENT="0"
HAS_WP_CORE="0"

[[ -f "${WP_TARGET_DIR}/wp-config.php" ]] && HAS_WP_CONFIG="1"
[[ -d "${WP_TARGET_DIR}/wp-content" ]] && HAS_WP_CONTENT="1"
if [[ -f "${WP_TARGET_DIR}/wp-settings.php" || -d "${WP_TARGET_DIR}/wp-admin" || -d "${WP_TARGET_DIR}/wp-includes" ]]; then
  HAS_WP_CORE="1"
fi

IS_EMPTY="0"
if [[ "${HAS_WP_CONFIG}" == "0" && "${HAS_WP_CONTENT}" == "0" && "${HAS_WP_CORE}" == "0" ]]; then
  IS_EMPTY="1"
fi

echo
echo "=============================="
echo " WordPress Latest Installer"
echo "=============================="
echo "Target directory: ${WP_TARGET_DIR}"
echo "Mode: ${MODE}"
echo

if [[ "${IS_EMPTY}" == "1" ]]; then
  echo "Detected: empty folder (no WordPress core/wp-content/wp-config found)."
  if [[ "${MODE}" == "core" ]]; then
    echo "⚠️ WARNING: You chose 'core' in an empty folder."
    echo "   This will NOT include wp-content (themes/plugins)."
    echo "   Consider using: install"
    echo
  fi
else
  echo "Detected: existing WordPress install (core/wp-content/wp-config found)."
  if [[ "${MODE}" == "install" ]]; then
    echo "ℹ️ NOTE: You chose 'install' on an existing site."
    echo "   wp-content WILL be overwritten (except wp-config.php is protected)."
    echo
  fi
fi

if [[ "${MODE}" == "overwrite" ]]; then
  echo "⚠️ WARNING: OVERWRITE mode will overwrite wp-content AND wp-config.php."
  echo "If you run this on an existing site, you WILL lose content if not backed up."
  echo
  echo "Refusing to run overwrite without explicit confirmation flag."
  echo "Run with: overwrite --force"
  echo
  echo "Example:"
  echo "  curl -fsSL <SCRIPT_URL> | bash -s -- overwrite --force"
  exit 1
fi

FORCE="${2:-}"

# For overwrite mode, require --force
if [[ "${MODE}" == "overwrite" && "${FORCE}" != "--force" ]]; then
  echo "ERROR: overwrite requires --force"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

echo "==> Downloading WordPress latest..."
curl -L --silent --show-error --fail -o "${TMP_DIR}/wordpress.tar.gz" "https://wordpress.org/latest.tar.gz"

echo "==> Extracting..."
tar -xzf "${TMP_DIR}/wordpress.tar.gz" -C "${TMP_DIR}"

if [[ ! -d "${TMP_DIR}/wordpress" ]]; then
  echo "ERROR: wordpress directory not found after extraction."
  exit 1
fi

# --- Mode behaviors ---
if [[ "${MODE}" == "core" ]]; then
  echo "==> CORE mode: keeping wp-content + wp-config.php"
  rm -rf "${TMP_DIR}/wordpress/wp-content"
  rm -f  "${TMP_DIR}/wordpress/wp-config.php" || true

elif [[ "${MODE}" == "install" ]]; then
  echo "==> INSTALL mode: copying everything incl. wp-content"
  # Protect existing wp-config.php
  if [[ -f "${WP_TARGET_DIR}/wp-config.php" ]]; then
    echo "==> Existing wp-config.php found - will not overwrite."
    rm -f "${TMP_DIR}/wordpress/wp-config.php" || true
  fi

elif [[ "${MODE}" == "overwrite" ]]; then
  echo "==> OVERWRITE mode: copying everything incl. wp-content + wp-config.php"
fi

echo "==> Copying files..."
cp -a "${TMP_DIR}/wordpress/." "${WP_TARGET_DIR}/"

echo "==> Removing unnecessary public files..."
rm -f "${WP_TARGET_DIR}/readme.html" \
      "${WP_TARGET_DIR}/license.txt" || true

# wp-config-sample.php is required for fresh installs (WordPress setup wizard)
# Only remove it for CORE updates on existing installs.
if [[ "${MODE}" == "core" ]]; then
  echo "==> CORE mode: removing wp-config-sample.php"
  rm -f "${WP_TARGET_DIR}/wp-config-sample.php" || true
else
  echo "==> ${MODE} mode: keeping wp-config-sample.php (required for setup)"
fi

echo
echo "✅ Done!"
echo "WordPress files are now in: ${WP_TARGET_DIR}"
echo
