#!/usr/bin/env bash
#
# Build CocoaMSX (Release) and install CocoaMSX.app for local use.
#
# Usage:
#   ./scripts/build-local-release.sh              # build + install to ~/Applications
#   ./scripts/build-local-release.sh --open       # build, install, then launch
#   INSTALL_DIR=/Applications ./scripts/build-local-release.sh
#   ./scripts/build-local-release.sh --build-only # build only, no install
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="CocoaMSX"
CONFIGURATION="Release"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/build/DerivedData}"
BUILD_PRODUCTS="$DERIVED_DATA/Build/Products/$CONFIGURATION"
APP_NAME="CocoaMSX.app"
BUILT_APP="$BUILD_PRODUCTS/$APP_NAME"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"

OPEN_AFTER_INSTALL=0
BUILD_ONLY=0

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \?//'
    echo
    echo "Options:"
    echo "  --build-only     Build the .app but do not copy to Applications"
    echo "  --open           Launch CocoaMSX after a successful install"
    echo "  -h, --help       Show this help"
    echo
    echo "Environment:"
    echo "  INSTALL_DIR      Destination folder (default: ~/Applications)"
    echo "  DERIVED_DATA     Xcode DerivedData path (default: build/DerivedData)"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build-only)
            BUILD_ONLY=1
            shift
            ;;
        --open)
            OPEN_AFTER_INSTALL=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "error: xcodebuild not found. Install Xcode command-line tools." >&2
    exit 1
fi

echo "==> Building $SCHEME ($CONFIGURATION)"
echo "    Source:      $ROOT"
echo "    DerivedData: $DERIVED_DATA"
echo

cd "$ROOT"

xcodebuild \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    build

if [[ ! -d "$BUILT_APP" ]]; then
    echo "error: expected app bundle not found at $BUILT_APP" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$BUILT_APP/Contents/Info.plist" 2>/dev/null || echo unknown)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$BUILT_APP/Contents/Info.plist" 2>/dev/null || echo unknown)"

echo
echo "==> Build succeeded: $BUILT_APP"
echo "    Version: $VERSION ($BUILD)"

if [[ "$BUILD_ONLY" -eq 1 ]]; then
    echo
    echo "Build-only mode; not installing."
    echo "To install manually:"
    echo "  ditto \"$BUILT_APP\" \"$INSTALL_DIR/$APP_NAME\""
    exit 0
fi

DEST="$INSTALL_DIR/$APP_NAME"
mkdir -p "$INSTALL_DIR"

echo
echo "==> Installing to $DEST"
rm -rf "$DEST"
ditto "$BUILT_APP" "$DEST"

echo "==> Installed CocoaMSX $VERSION ($BUILD)"
echo "    Run from Finder or: open -a \"$DEST\""

if [[ "$OPEN_AFTER_INSTALL" -eq 1 ]]; then
    open -a "$DEST"
fi
