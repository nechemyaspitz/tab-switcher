#!/bin/bash
set -euo pipefail

# Build, embed Sparkle framework, code sign, create DMG, and notarize
#
# Prerequisites:
#   - Xcode command-line tools
#   - A valid Developer ID certificate in Keychain
#   - notarytool credentials stored (xcrun notarytool store-credentials)
#
# Usage:
#   ./build.sh                          # build only (no signing/notarization)
#   ./build.sh --sign                   # build + code sign
#   ./build.sh --sign --notarize        # build + sign + notarize

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_BUNDLE="$PROJECT_DIR/dist/Tab Switcher.app"
DMG_PATH="$PROJECT_DIR/dist/Tab Switcher.dmg"
BINARY_NAME="tab-switcher"

SIGN=false
NOTARIZE=false
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-TabSwitcher}"

for arg in "$@"; do
    case "$arg" in
        --sign) SIGN=true ;;
        --notarize) NOTARIZE=true ;;
    esac
done

echo "==> Building release binary..."
cd "$SCRIPT_DIR"
swift build -c release

echo "==> Generating app icon from .icon source..."
ICON_SRC="$SCRIPT_DIR/AppIcon.icon"
if [ -d "$ICON_SRC" ]; then
    xcrun actool "$ICON_SRC" \
        --compile "$APP_BUNDLE/Contents/Resources" \
        --output-format human-readable-text --notices --warnings --errors \
        --output-partial-info-plist /tmp/icon-partial.plist \
        --app-icon AppIcon --include-all-app-icons \
        --enable-on-demand-resources NO \
        --development-region en \
        --target-device mac \
        --minimum-deployment-target 26.0 \
        --platform macosx
    echo "   Icon compiled (Assets.car + AppIcon.icns)"
else
    echo "   Skipping icon generation (AppIcon.icon not found)"
fi

echo "==> Copying binary to app bundle..."
cp ".build/release/$BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"

echo "==> Embedding Sparkle.framework..."
FRAMEWORK_SRC=$(find .build -path '*/Sparkle.framework' -type d | head -1)
if [ -z "$FRAMEWORK_SRC" ]; then
    echo "ERROR: Sparkle.framework not found in .build. Run 'swift package resolve' first."
    exit 1
fi

mkdir -p "$APP_BUNDLE/Contents/Frameworks"
# Remove old framework if present
rm -rf "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
cp -R "$FRAMEWORK_SRC" "$APP_BUNDLE/Contents/Frameworks/"

echo "==> Fixing rpath on binary..."
# Add rpath if not already present (ignore error if already exists)
install_name_tool -add_rpath @executable_path/../Frameworks "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME" 2>/dev/null || true

if $SIGN; then
    echo "==> Unlocking keychain (enter password once)..."
    security unlock-keychain login.keychain-db

    echo "==> Code signing..."
    # Sign Sparkle framework (inside out — all nested bundles and executables)
    SPARKLE="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework/Versions/B"
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" \
        "$SPARKLE/XPCServices/Downloader.xpc" \
        "$SPARKLE/XPCServices/Installer.xpc" \
        "$SPARKLE/Autoupdate" \
        "$SPARKLE/Updater.app" \
        "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

    # Sign the app bundle
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"

    echo "==> Verifying code signature..."
    codesign --verify --deep --strict "$APP_BUNDLE"
fi

echo "==> Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create -volname "Tab Switcher" -srcfolder "$APP_BUNDLE" \
    -ov -format UDZO "$DMG_PATH"

if $SIGN; then
    codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"
fi

if $NOTARIZE; then
    echo "==> Notarizing DMG..."
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"
fi

echo "==> Done!"
echo "   App bundle: $APP_BUNDLE"
echo "   DMG: $DMG_PATH"
