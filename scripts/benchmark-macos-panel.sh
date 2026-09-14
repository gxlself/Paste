#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/paste-panel-benchmark.XXXXXX")"
LOG="${BUILD_DIR}/build.log"

if ! xcodebuild \
    -project "${ROOT}/Paste.xcodeproj" \
    -scheme Paste \
    -configuration Release \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGNING_ALLOWED=NO \
    PRODUCT_BUNDLE_IDENTIFIER=dev.paste.performance \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS=PERFORMANCE_TESTING \
    build >"${LOG}" 2>&1; then
    tail -80 "${LOG}"
    exit 1
fi

LLVM_PROFILE_FILE="${BUILD_DIR}/benchmark-%p.profraw" \
    "${BUILD_DIR}/Build/Products/Release/Paste.app/Contents/MacOS/Paste"
printf '\nBuild and logs: %s\n' "${BUILD_DIR}"
