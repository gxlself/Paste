#!/usr/bin/env bash
# Build macOS Release .app and zip for GitHub Releases.
# Requires full Xcode (not Command Line Tools only). See docs/RELEASE_MACOS.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

resolve_xcodebuild() {
  if command -v xcodebuild &>/dev/null && xcodebuild -version &>/dev/null; then
    echo "xcodebuild"
    return 0
  fi
  if [[ -x "/usr/bin/xcodebuild" ]] && /usr/bin/xcodebuild -version &>/dev/null; then
    echo "/usr/bin/xcodebuild"
    return 0
  fi
  if xcrun --find xcodebuild &>/dev/null; then
    echo "xcrun xcodebuild"
    return 0
  fi
  return 1
}

if ! XB="$(resolve_xcodebuild)"; then
  echo "Error: xcodebuild not found or not usable."
  echo ""
  echo "Do this:"
  echo "  1. Install **Xcode** from the App Store (full app, not Command Line Tools only)."
  echo "  2. Open Xcode once and finish component installation."
  echo "  3. In Terminal run:"
  echo "       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "       sudo xcodebuild -license accept"
  echo "  4. Run this script again."
  echo ""
  echo "If Xcode is not at the default path, point xcode-select to your Xcode.app."
  exit 1
fi

# shellcheck disable=SC2206
XB_ARR=($XB)

DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
echo "Using: ${XB_ARR[*]}"
echo "DEVELOPER_DIR: ${DEV_DIR:-unknown}"
echo ""

DERIVED="${ROOT}/build/DerivedData"
mkdir -p "${ROOT}/dist"
rm -rf "${DERIVED}"

echo "Building Paste (macOS, Release)..."
"${XB_ARR[@]}" \
  -project Paste.xcodeproj \
  -scheme Paste \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${DERIVED}" \
  -skipPackagePluginValidation \
  build

APP="${DERIVED}/Build/Products/Release/Paste.app"
if [[ ! -d "${APP}" ]]; then
  echo "Build failed: ${APP} not found."
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${APP}/Contents/Info.plist" 2>/dev/null || echo "unknown")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "${APP}/Contents/Info.plist" 2>/dev/null || echo "0")"
ZIP="${ROOT}/dist/Paste-${VERSION}-macos.zip"
rm -f "${ZIP}"
ditto -c -k --sequesterRsrc --keepParent "${APP}" "${ZIP}"

# Installer .pkg → installs Paste.app into /Applications
PKG_STAGING="${ROOT}/build/pkg_staging"
rm -rf "${PKG_STAGING}"
mkdir -p "${PKG_STAGING}"
ditto "${APP}" "${PKG_STAGING}/Paste.app"
PKG="${ROOT}/dist/Paste-${VERSION}-macos.pkg"
rm -f "${PKG}"
pkgbuild \
  --root "${PKG_STAGING}" \
  --identifier "gxlself.paste-tool.macos.installer" \
  --version "${VERSION}" \
  --install-location /Applications \
  "${PKG}"

echo ""
echo "Done:"
echo "  ${ZIP}   (drag .app to Applications, or unzip anywhere)"
echo "  ${PKG}   (double-click → installs to Applications)"
echo ""
echo "Upload either or both to GitHub Releases."
echo "Without notarization, users may need to right-click the app → Open after install."
