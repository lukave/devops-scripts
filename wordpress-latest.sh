#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Interactive WordPress latest installer/updater
# - Asks what you want to do
# - Safe defaults
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

# Check if it's an existing WP install (basic)
IS_EXISTING="0"
if [[ -f "${WP_TARGET_DIR}/wp-config.php" || -d "${WP_TARGET_DIR}/wp-content" ]]; then
  IS_EXISTING="1"
fi

if [[ "${IS_EXISTING}" == "1" ]]; then
  echo "Detected: existing WordPress install (wp-config.php and/or wp-content found)."
else
  echo "Detected: empty or non-standard folder (no wp-config/wp-content found)."
fi

echo
echo "Choose what you want to do:"
echo "  1) Update / reinstall WordPress CORE only (keep wp-content + wp-config)  ✅ safest"
echo "  2) Full install (copy everything incl. wp-content)                      ✅ new install"
echo "  3) Full overwrite (copy everything incl. wp-content + wp-config)        ⚠️ destructive"
echo "  4) Cancel"
echo

read -r -p "Enter choice [1-4]: " CHOICE

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
  read -r -p "Type OVERWRITE to confirm: " CONFIRM
  if [[ "${CONFIRM}" != "OVERWRITE" ]]; then
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

# Mode behaviors
if [[ "${MODE}" == "core" ]]; then
  echo "==> CORE mode: keep wp-content + wp-config.php"
  rm -rf "${TMP_DIR}/wordpress/wp-content"
  rm -f  "${TMP_DIR}/wordpress/wp-config.php" || true
elif [[ "${MODE}" == "install" ]]; then
  echo "==> INSTALL mode: copy everything incl. wp-content"
  # Still: protect existing wp-config.php
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
