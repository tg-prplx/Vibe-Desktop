#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="${APP_NAME:-Vibe}"
VERSION="${VERSION:-0.1.0}"

APP_ARGS=("--embed-venv")
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name)
      APP_NAME="$2"
      APP_ARGS+=("$1" "$2")
      shift 2
      ;;
    --version)
      VERSION="$2"
      APP_ARGS+=("$1" "$2")
      shift 2
      ;;
    --bundle-id|--build)
      APP_ARGS+=("$1" "$2")
      shift 2
      ;;
    *)
      APP_ARGS+=("$1")
      shift
      ;;
  esac
done

BUILD_LOG="$(mktemp)"
"${SCRIPT_DIR}/build_app.sh" "${APP_ARGS[@]}" >"${BUILD_LOG}"
cat "${BUILD_LOG}" >&2
APP_PATH="$(tail -n 1 "${BUILD_LOG}")"
rm -f "${BUILD_LOG}"
DMG_STAGING="${PACKAGE_DIR}/.build/dmg-staging"
DMG_PATH="${PACKAGE_DIR}/.build/${APP_NAME}-${VERSION}-macos-arm64.dmg"

rm -rf "${DMG_STAGING}" "${DMG_PATH}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_PATH}" "${DMG_STAGING}/${APP_NAME}.app"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGING}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

echo "${DMG_PATH}"
