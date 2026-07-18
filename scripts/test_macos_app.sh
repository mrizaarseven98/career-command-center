#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && /bin/pwd -P)"
TEST_BUILD="${TEST_BUILD_ROOT:-$ROOT/build/tests}"
CACHE="$TEST_BUILD/module-cache"
ARCH="${TEST_ARCHITECTURE:-$(uname -m)}"
APP_ARCHITECTURES="${APP_ARCHITECTURES:-arm64 x86_64}"
SWIFT_INTERFACE_VERSION="$(xcrun swiftc --version 2>&1 | sed -nE 's/.*Apple Swift version ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' | head -n 1)"

mkdir -p "$TEST_BUILD" "$CACHE"

run_swift() {
  local log="$1"
  shift
  if MACOSX_DEPLOYMENT_TARGET=14.0 \
    CLANG_MODULE_CACHE_PATH="$CACHE" \
    SWIFT_MODULE_CACHE_PATH="$CACHE" \
    xcrun swiftc "$@" 2>"$log"; then
    rm -f "$log"
    return
  fi
  if grep -q "SDK is not supported by the compiler" "$log" && [[ -n "$SWIFT_INTERFACE_VERSION" ]]; then
    if MACOSX_DEPLOYMENT_TARGET=14.0 \
      CLANG_MODULE_CACHE_PATH="$CACHE" \
      SWIFT_MODULE_CACHE_PATH="$CACHE" \
      xcrun swiftc "$@" \
        -Xfrontend -interface-compiler-version \
        -Xfrontend "$SWIFT_INTERFACE_VERSION" 2>>"$log"; then
      rm -f "$log"
      return
    fi
  fi
  cat "$log" >&2
  exit 1
}

cd "$ROOT"
python3 tests/test_plugin.py

ARCHITECTURES="$APP_ARCHITECTURES" scripts/build_app.sh >/dev/null
APP="$ROOT/build/Career Command Center.app"
codesign --verify --deep --strict "$APP"
for required_arch in $APP_ARCHITECTURES; do
  lipo "$APP/Contents/MacOS/CareerCommandCenter" -verify_arch "$required_arch"
  lipo "$APP/Contents/Helpers/CareerCommandCenterUpdater" -verify_arch "$required_arch"
done

COMMON_SOURCES=(
  assets/macos-app/Sources/CoreModels.swift
  assets/macos-app/Sources/UpdateService.swift
  assets/macos-app/Sources/AppStore.swift
)
COMMON_FLAGS=(
  -swift-version 5
  -parse-as-library
  -target "$ARCH-apple-macos14.0"
  -module-cache-path "$CACHE"
  -framework SwiftUI
  -framework AppKit
  -framework Foundation
)

run_swift "$TEST_BUILD/core.log" \
  "${COMMON_FLAGS[@]}" \
  "${COMMON_SOURCES[@]}" \
  assets/macos-app/Tests/CoreTests.swift \
  -o "$TEST_BUILD/CoreTests"
"$TEST_BUILD/CoreTests"

run_swift "$TEST_BUILD/compatibility.log" \
  "${COMMON_FLAGS[@]}" \
  "${COMMON_SOURCES[@]}" \
  assets/macos-app/Tests/CompatibilityTests.swift \
  -o "$TEST_BUILD/CompatibilityTests"
"$TEST_BUILD/CompatibilityTests" tests/fixtures/legacy_state.json

run_swift "$TEST_BUILD/update-stage.log" \
  -swift-version 5 \
  -parse-as-library \
  -target "$ARCH-apple-macos14.0" \
  -module-cache-path "$CACHE" \
  -framework Foundation \
  assets/macos-app/Sources/UpdateService.swift \
  assets/macos-app/Tests/UpdateStageTests.swift \
  -o "$TEST_BUILD/UpdateStageTests"
"$TEST_BUILD/UpdateStageTests" "$APP"

python3 tests/test_update_installer.py --app "$APP"

run_swift "$TEST_BUILD/snapshot.log" \
  "${COMMON_FLAGS[@]}" \
  "${COMMON_SOURCES[@]}" \
  assets/macos-app/Sources/DesignSystem.swift \
  assets/macos-app/Sources/OnboardingView.swift \
  assets/macos-app/Sources/LeadWorkspaceView.swift \
  assets/macos-app/Sources/LibraryViews.swift \
  assets/macos-app/Sources/QuestionsView.swift \
  assets/macos-app/Tests/SnapshotApp.swift \
  -o "$TEST_BUILD/SnapshotApp"

echo "All macOS application tests passed"
