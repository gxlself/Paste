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
ARCHIVE="${ROOT}/build/Paste.xcarchive"
EXPORT_DIR="${ROOT}/build/export"
EXPORT_PLIST="${ROOT}/ExportOptions.developer-id.plist"
TEAM_ID="W8L8ZJ3N2P"
mkdir -p "${ROOT}/dist"
rm -rf "${DERIVED}" "${ARCHIVE}" "${EXPORT_DIR}"

# The app must be signed for DISTRIBUTION, not development.
#
# CloudKit keeps two separate databases per container. A build signed with a development
# provisioning profile talks to *Development*; TestFlight and App Store builds talk to
# *Production*. Plain `xcodebuild build` with automatic signing picks the Mac Team
# Provisioning Profile (development) and silently rewrites the `aps-environment`
# entitlement to `development` — even though PasteRelease.entitlements asks for
# `production`. The result is a released macOS app that can never sync with the iOS app.
#
# Archiving and exporting with method `developer-id` uses the distribution certificate and
# lands on Production, matching the iOS build.
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application:.*(${TEAM_ID})"; then
  echo "Error: no 'Developer ID Application' certificate for team ${TEAM_ID} in the keychain."
  echo ""
  echo "Without it the app can only be signed for development, which puts it on the CloudKit"
  echo "Development database — it will not sync with the TestFlight/App Store iOS app."
  echo ""
  echo "Create one at https://developer.apple.com/account/resources/certificates"
  echo "  (Certificates → + → Developer ID Application), download and double-click it,"
  echo "  or use Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application."
  exit 1
fi

echo "Archiving Paste (macOS, Release)..."
"${XB_ARR[@]}" \
  -project Paste.xcodeproj \
  -scheme Paste \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "${ARCHIVE}" \
  -derivedDataPath "${DERIVED}" \
  -skipPackagePluginValidation \
  -allowProvisioningUpdates \
  archive

echo "Exporting with Developer ID..."
"${XB_ARR[@]}" \
  -exportArchive \
  -archivePath "${ARCHIVE}" \
  -exportOptionsPlist "${EXPORT_PLIST}" \
  -exportPath "${EXPORT_DIR}" \
  -allowProvisioningUpdates

APP="${EXPORT_DIR}/Paste.app"
if [[ ! -d "${APP}" ]]; then
  echo "Export failed: ${APP} not found."
  exit 1
fi

# Guard against the silent downgrade described above.
#
# Read the signed entitlements into a file and query it with PlistBuddy: the keys are dotted,
# and `plutil -extract` would treat each dot as a keypath separator and report them missing.
ENT_PLIST="${ROOT}/build/signed-entitlements.plist"
codesign -d --entitlements :- "${APP}" > "${ENT_PLIST}" 2>/dev/null

read_entitlement() {
  /usr/libexec/PlistBuddy -c "Print :$1" "${ENT_PLIST}" 2>/dev/null || true
}

# The authoritative key for which CloudKit database the app talks to. Distribution profiles set
# it; development profiles do not.
CK_ENV="$(read_entitlement 'com.apple.developer.icloud-container-environment')"
APS_ENV="$(read_entitlement 'com.apple.developer.aps-environment')"

if [[ "${CK_ENV}" != "Production" ]]; then
  echo "Error: icloud-container-environment is '${CK_ENV:-<missing>}', expected 'Production'."
  echo "       (aps-environment = '${APS_ENV:-<missing>}')"
  echo "The app would sync against the CloudKit Development database and never reach iOS users."
  echo "Signed entitlements: ${ENT_PLIST}"
  exit 1
fi

SIGNER="$(codesign -dvv "${APP}" 2>&1 | sed -n 's/^Authority=\(Developer ID Application.*\)$/\1/p' | head -1)"
echo "Signed by: ${SIGNER:-<unknown>}"
echo "CloudKit environment: ${CK_ENV} (aps-environment: ${APS_ENV:-none}). OK."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${APP}/Contents/Info.plist" 2>/dev/null || echo "unknown")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "${APP}/Contents/Info.plist" 2>/dev/null || echo "0")"

# ---------------------------------------------------------------------------
# Notarization
#
# A Developer ID signature alone is not enough: Gatekeeper still blocks the app on a machine
# that has not seen it before, and the user has to right-click → Open (macOS 15+: System
# Settings → Privacy & Security → Open Anyway). Notarizing and then *stapling* the ticket to
# the bundle removes that step entirely, including for users who are offline on first launch.
#
# Credentials are read from a notarytool keychain profile. Create it once with:
#   xcrun notarytool store-credentials paste-notary \
#     --apple-id <your Apple ID> --team-id W8L8ZJ3N2P --password <app-specific password>
# App-specific passwords: https://account.apple.com → Sign-In and Security → App-Specific Passwords
#
# Set SKIP_NOTARIZE=1 to build an un-notarized package (testing only).
# ---------------------------------------------------------------------------
NOTARY_PROFILE="${NOTARY_PROFILE:-paste-notary}"

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
  echo ""
  echo "SKIP_NOTARIZE=1 — skipping notarization. Users will have to bypass Gatekeeper manually."
else
  if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
    echo "Error: no notarytool credentials for profile '${NOTARY_PROFILE}'."
    echo ""
    echo "Create them once:"
    echo "  xcrun notarytool store-credentials ${NOTARY_PROFILE} \\"
    echo "    --apple-id <your Apple ID> --team-id ${TEAM_ID} --password <app-specific password>"
    echo ""
    echo "Generate the app-specific password at https://account.apple.com"
    echo "  → Sign-In and Security → App-Specific Passwords."
    echo ""
    echo "Or re-run with SKIP_NOTARIZE=1 to produce an un-notarized build."
    exit 1
  fi

  # notarytool needs a container to upload; the ticket is stapled to the .app afterwards.
  SUBMIT_ZIP="${ROOT}/build/Paste-notarize.zip"
  rm -f "${SUBMIT_ZIP}"
  ditto -c -k --sequesterRsrc --keepParent "${APP}" "${SUBMIT_ZIP}"

  echo ""
  echo "Submitting to Apple for notarization (this usually takes 1-5 minutes)..."
  if ! xcrun notarytool submit "${SUBMIT_ZIP}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait; then
    echo ""
    echo "Notarization failed. Fetch the log for the submission id printed above:"
    echo "  xcrun notarytool log <submission-id> --keychain-profile ${NOTARY_PROFILE}"
    exit 1
  fi

  echo "Stapling ticket to Paste.app..."
  xcrun stapler staple "${APP}"
  xcrun stapler validate "${APP}"
fi

# Everything below is packaged from the (now stapled) app.
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

# A .pkg carries its own signature, separate from the app's. Signing it needs a
# "Developer ID Installer" certificate; without one the installer cannot be notarized and
# macOS will warn on open, even though the app inside is notarized and stapled.
INSTALLER_ID="$(security find-identity -v | sed -n "s/.*\"\(Developer ID Installer: .*(${TEAM_ID})\)\".*/\1/p" | head -1)"

if [[ -n "${INSTALLER_ID}" ]]; then
  pkgbuild \
    --root "${PKG_STAGING}" \
    --identifier "gxlself.paste-tool.macos.installer" \
    --version "${VERSION}" \
    --install-location /Applications \
    --sign "${INSTALLER_ID}" \
    "${PKG}"

  if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
    echo ""
    echo "Notarizing the installer..."
    if xcrun notarytool submit "${PKG}" --keychain-profile "${NOTARY_PROFILE}" --wait; then
      xcrun stapler staple "${PKG}"
      xcrun stapler validate "${PKG}"
      PKG_NOTE="signed + notarized + stapled"
    else
      PKG_NOTE="signed, but notarization FAILED"
    fi
  else
    PKG_NOTE="signed, not notarized"
  fi
else
  pkgbuild \
    --root "${PKG_STAGING}" \
    --identifier "gxlself.paste-tool.macos.installer" \
    --version "${VERSION}" \
    --install-location /Applications \
    "${PKG}"
  PKG_NOTE="UNSIGNED — no 'Developer ID Installer' certificate for team ${TEAM_ID}"
fi

echo ""
echo "Done (version ${VERSION}, build ${BUILD}):"
echo "  ${ZIP}   (app is notarized + stapled; unzip and drag to Applications)"
echo "  ${PKG}   (${PKG_NOTE})"
echo ""
if [[ -n "${INSTALLER_ID}" ]]; then
  echo "Both open with a double-click on a clean Mac — no Gatekeeper prompt."
else
  echo "Ship the .zip: it opens with a double-click on a clean Mac."
  echo "The .pkg is unsigned and will still warn. To fix, create a 'Developer ID Installer'"
  echo "certificate (Xcode → Settings → Accounts → Manage Certificates → + ) and re-run."
fi
echo ""
echo "Upload to GitHub → Releases → Draft a new release → attach binaries."
