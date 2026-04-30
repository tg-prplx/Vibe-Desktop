#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PACKAGE_DIR}/../.." && pwd)"

APP_NAME="${APP_NAME:-Vibe}"
BUNDLE_ID="${BUNDLE_ID:-ai.mistral.vibe.mac}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CONFIGURATION="release"
EMBED_VENV=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --embed-venv)
      EMBED_VENV=1
      shift
      ;;
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --build)
      BUILD_NUMBER="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

swift build --package-path "${PACKAGE_DIR}" -c "${CONFIGURATION}"
BIN_DIR="$(swift build --package-path "${PACKAGE_DIR}" -c "${CONFIGURATION}" --show-bin-path)"
BINARY="${BIN_DIR}/VibeMac"

APP_ROOT="${PACKAGE_DIR}/.build/app"
APP_DIR="${APP_ROOT}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BACKEND_DIR="${RESOURCES_DIR}/VibeBackend"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${BACKEND_DIR}"

cp "${BINARY}" "${MACOS_DIR}/VibeMac"
chmod 755 "${MACOS_DIR}/VibeMac"

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>VibeMac</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

rsync -a --delete \
  --exclude '__pycache__/' \
  --exclude '*.pyc' \
  "${REPO_ROOT}/vibe" \
  "${BACKEND_DIR}/"

for file in pyproject.toml uv.lock .python-version README.md LICENSE; do
  if [[ -f "${REPO_ROOT}/${file}" ]]; then
    cp "${REPO_ROOT}/${file}" "${BACKEND_DIR}/${file}"
  fi
done

if [[ "${EMBED_VENV}" -eq 1 ]]; then
  if [[ ! -d "${REPO_ROOT}/.venv" ]]; then
    echo "Cannot embed .venv: ${REPO_ROOT}/.venv does not exist" >&2
    exit 1
  fi
  PYTHON_BASE="$("${REPO_ROOT}/.venv/bin/python" -c 'import sys; print(sys.base_prefix)')"
  PYTHON_VERSION="$("${REPO_ROOT}/.venv/bin/python" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  PYTHON_BIN_NAME="python${PYTHON_VERSION}"

  if [[ ! -x "${PYTHON_BASE}/bin/${PYTHON_BIN_NAME}" ]]; then
    echo "Cannot embed Python runtime: ${PYTHON_BASE}/bin/${PYTHON_BIN_NAME} is not executable" >&2
    exit 1
  fi

  rsync -a --delete \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "${PYTHON_BASE}/" \
    "${BACKEND_DIR}/Python/"

  rsync -a --delete \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "${REPO_ROOT}/.venv" \
    "${BACKEND_DIR}/"

  ln -sfn "../../Python/bin/${PYTHON_BIN_NAME}" "${BACKEND_DIR}/.venv/bin/python"
  ln -sfn "python" "${BACKEND_DIR}/.venv/bin/python3"
  ln -sfn "python" "${BACKEND_DIR}/.venv/bin/${PYTHON_BIN_NAME}"
fi

xattr -dr com.apple.quarantine "${APP_DIR}" 2>/dev/null || true
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "${APP_DIR}"
