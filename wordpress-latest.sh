#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Interactive WordPress latest installer/updater
# - Auto-detects empty folder -> proposes full install by default
# - Works with: curl ... | bash   (reads from /dev/tty)
#
# Optional env vars:
#   WP_TARGET_DIR="/path/to/site"
# ------------------------------------------------------------

WP_TARGET_DIR="${WP_TARGET_DIR:-$(pwd)}"

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not installed"; exit 1; }
command -v tar  >/dev/null 2>&1 || { echo "ERROR: tar not installed"; exit 1; }

if [[ ! -d "${WP_TARGET_DIR}" ]]; then
  echo "ERROR: Target directory does not exist: ${WP_TARGET_DIR}"
  exit 1
fi

echo
echo "=============================="
echo " WordPress Latest Installer"
echo "=============================="
echo "Target directory: ${WP_TARGET_DIR}"
echo

# --- Detection logic ---
HAS_WP_CONFIG="0"
HAS_WP_CONTENT="0"
HAS_WP_CORE="0"

[[ -f "${WP_TARGET_DIR}/wp-config.php" ]] && HAS_WP_CONFIG="1"
[[ -d "${WP_TARGET_DIR}/wp-content" ]] && HAS_WP_CONTENT="1"

# Core indicators
if [[ -f "${WP_TARGET_DIR}/wp-settings.php" || -d "${WP_TARGET_DIR}/wp-admin" || -d "${WP_TARGET_DIR}/wp-includes" ]]; then
  HAS_WP_CORE="1"
fi

# "empty" = no config, no content, no core
IS_EMPTY="0"
if [[ "${HAS_WP_CONFIG}" == "0" && "${HAS_WP_CONTENT}" == "0" && "${HAS_WP_CORE}" == "0" ]]; then
  IS_EMPTY="1"
fi

# Default choice: empty -> full install, existing -> core
DEFAULT_CHOICE="1"
if [[ "${IS_EMPTY}" == "1" ]]; then
  DEFAULT_CHOICE="2"
  echo "Detected: empty folder (no WordPress core/wp-content/wp-config found)."
  echo "Suggestion: FULL install (option 2)."
else
  echo "Detected: existing WordPress install (core/wp-content/wp-config found)."
  echo "Suggestion: CORE update (option 1) to keep wp-content + wp-config."
fi

echo
echo "Choose what you want to do:"
echo "  1) Update / reinstall WordPress CORE only (keep wp-content + wp-config)  ✅ safest"
echo "  2) Full install (copy everything incl. wp-content)                      ✅ new install"
echo "  3) Full overwrite (copy everything incl. wp-content + wp-config)        ⚠️ destructive"
echo "  4) Cancel"
echo

# --- IMPORTANT: Read from /dev/tty so it works with curl | bash ---
CHOICE=""
if [[ -t 0 ]]; then
  # stdin is a TTY
  read -r -p "Enter choice [1-4] (default: ${DEFAULT_CHOICE}): " CHOICE || true
else
  # stdin is piped; read from terminal
  read -r -p "Enter choice [1-4] (default: ${DEFAULT_CHOICE}): " CHOICE </dev/tty || true
fi

CHOICE="${CHOICE:-$DEFAULT_CHOICE}"

case "${CHOICE}" in
  1) MODE="core" ;;
  2) MODE="install" ;;
  3) MODE="overwrite" ;;
  4) echo "Canceled."; exit 0 ;;
  *) echo "Invalid choice. Exiting."; exit 1 ;;
esac

if [[ "${MODE}" == "overwrite" ]]; then
  echo
  echo "⚠️ WARNING: This will overwrite wp-content and wp-config.php if they exist."
  CONFIRM=""
  if [[ -t 0 ]]; then
    read -r -p "Type OVERWRITE to confirm: " CONFIRM || true
  else
    read -r -p "Type OVERWRITE to confirm: " CONFIRM </dev/tty || true
  fi

  if [[ "${CONFIRM:-}" != "OVERWRITE" ]]; then
    echo "Not confirmed. Exiting."
    exit 1
  fi
fi

echo
echo "==> Selected mode: ${MODE}"
echo

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
  echo "==> CORE mode: keep wp-content + wp-config.php"
  rm -rf "${TMP_DIR}/wordpress/wp-content"
  rm -f  "${TMP_DIR}/wordpress/wp-config.php" || true

elif [[ "${MODE}" == "install" ]]; then
  echo "==> INSTALL mode: copy everything incl. wp-content"
  # protect existing wp-config.php
  if [[ -f "${WP_TARGET_DIR}/wp-config.php" ]]; then
    echo "==> Existing wp-config.php found - will not overwrite."
    rm -f "${TMP_DIR}/wordpress/wp-config.php" || true
  fi

elif [[ "${MODE}" == "overwrite" ]]; then
  echo "==> OVERWRITE mode: overwrite everything (incl. wp-content + wp-config.php)"
fi

echo "==> Copying files..."
cp -a "${TMP_DIR}/wordpress/." "${WP_TARGET_DIR}/"

echo
echo "✅ Done!"
echo "WordPress files are now in: ${WP_TARGET_DIR}"
echo
