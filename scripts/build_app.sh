#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && /bin/pwd -P)"
SOURCE_ROOT="$PLUGIN_ROOT/assets/macos-app"
BUILD_ROOT="${BUILD_ROOT:-$PLUGIN_ROOT/build}"
APP_BUNDLE="$BUILD_ROOT/Career Command Center.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/CareerCommandCenter"
HELPER="$APP_BUNDLE/Contents/Helpers/CareerCommandCenterUpdater"
MODULE_CACHE="$BUILD_ROOT/.module-cache"
ARCHITECTURES="${ARCHITECTURES:-$(uname -m)}"
ARCHES=($ARCHITECTURES)

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Career Command Center is a macOS application." >&2
  exit 2
fi
if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required to build the app." >&2
  exit 2
fi
if [[ ${#ARCHES[@]} -eq 0 ]]; then
  echo "At least one architecture is required." >&2
  exit 2
fi

SWIFT_INTERFACE_VERSION="$(xcrun swiftc --version 2>&1 | sed -nE 's/.*Apple Swift version ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' | head -n 1)"

run_swift() {
  local log="$1"
  local cache="$2"
  shift 2
  mkdir -p "$cache"
  if MACOSX_DEPLOYMENT_TARGET=14.0 \
    CLANG_MODULE_CACHE_PATH="$cache" \
    SWIFT_MODULE_CACHE_PATH="$cache" \
    xcrun swiftc "$@" 2>"$log"; then
    rm -f "$log"
    return
  fi

  if grep -q "SDK is not supported by the compiler" "$log" && [[ -n "$SWIFT_INTERFACE_VERSION" ]]; then
    echo "Retrying after a local Swift compiler/SDK patch-version mismatch." >&2
    if MACOSX_DEPLOYMENT_TARGET=14.0 \
      CLANG_MODULE_CACHE_PATH="$cache" \
      SWIFT_MODULE_CACHE_PATH="$cache" \
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

rm -rf "$APP_BUNDLE"
mkdir -p \
  "$APP_BUNDLE/Contents/MacOS" \
  "$APP_BUNDLE/Contents/Helpers" \
  "$APP_BUNDLE/Contents/Resources" \
  "$MODULE_CACHE"

MAIN_SOURCES=(
  "$SOURCE_ROOT/Sources/CoreModels.swift"
  "$SOURCE_ROOT/Sources/UpdateService.swift"
  "$SOURCE_ROOT/Sources/AppStore.swift"
  "$SOURCE_ROOT/Sources/DesignSystem.swift"
  "$SOURCE_ROOT/Sources/OnboardingView.swift"
  "$SOURCE_ROOT/Sources/LeadWorkspaceView.swift"
  "$SOURCE_ROOT/Sources/LibraryViews.swift"
  "$SOURCE_ROOT/Sources/QuestionsView.swift"
  "$SOURCE_ROOT/Sources/CareerCommandCenterApp.swift"
)

MAIN_SLICES=()
HELPER_SLICES=()
for arch in "${ARCHES[@]}"; do
  main_slice="$BUILD_ROOT/CareerCommandCenter-$arch"
  helper_slice="$BUILD_ROOT/CareerCommandCenterUpdater-$arch"
  cache="$MODULE_CACHE/$arch"
  run_swift "$BUILD_ROOT/swift-main-$arch.log" "$cache" \
    -swift-version 5 \
    -parse-as-library \
    -O \
    -target "$arch-apple-macos14.0" \
    -module-cache-path "$cache" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Foundation \
    "${MAIN_SOURCES[@]}" \
    -o "$main_slice"
  run_swift "$BUILD_ROOT/swift-helper-$arch.log" "$cache" \
    -swift-version 5 \
    -parse-as-library \
    -O \
    -target "$arch-apple-macos14.0" \
    -module-cache-path "$cache" \
    -framework Foundation \
    "$SOURCE_ROOT/Sources/UpdateInstaller.swift" \
    -o "$helper_slice"
  [[ -x "$main_slice" && -x "$helper_slice" ]] || {
    echo "Swift compilation did not produce executable $arch slices." >&2
    exit 1
  }
  MAIN_SLICES+=("$main_slice")
  HELPER_SLICES+=("$helper_slice")
done

if [[ ${#ARCHES[@]} -eq 1 ]]; then
  cp "${MAIN_SLICES[0]}" "$EXECUTABLE"
  cp "${HELPER_SLICES[0]}" "$HELPER"
else
  /usr/bin/lipo -create "${MAIN_SLICES[@]}" -output "$EXECUTABLE"
  /usr/bin/lipo -create "${HELPER_SLICES[@]}" -output "$HELPER"
fi

cp "$SOURCE_ROOT/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$SOURCE_ROOT/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

SUPPORT="$APP_BUNDLE/Contents/Resources/Support"
mkdir -p "$SUPPORT/references" "$SUPPORT/scripts"
cp "$PLUGIN_ROOT/references/APP_WORKFLOW.md" "$SUPPORT/WORKFLOW.md"
cp "$PLUGIN_ROOT"/references/* "$SUPPORT/references/"
cp \
  "$PLUGIN_ROOT/scripts/doctor.py" \
  "$PLUGIN_ROOT/scripts/mark_automation_synced.py" \
  "$PLUGIN_ROOT/scripts/question_cli.py" \
  "$PLUGIN_ROOT/scripts/register_masters.py" \
  "$PLUGIN_ROOT/scripts/render_automation_spec.py" \
  "$PLUGIN_ROOT/scripts/state_cli.py" \
  "$SUPPORT/scripts/"

chmod +x "$EXECUTABLE" "$HELPER" "$SUPPORT"/scripts/*.py
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
codesign --verify --deep --strict "$APP_BUNDLE"

echo "$APP_BUNDLE"
