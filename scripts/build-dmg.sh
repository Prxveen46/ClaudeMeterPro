#!/bin/bash
set -euo pipefail

# ============================================================
# ClaudeMeterPro DMG Builder
# Usage: bash scripts/build-dmg.sh
# Optional: DEVELOPER_ID="Developer ID Application: ..." bash scripts/build-dmg.sh
# ============================================================

APP_NAME="ClaudeMeterPro"
DISPLAY_NAME="ClaudeMeter Pro"
BUNDLE_ID="com.praveenkumar.ClaudeMeterPro"
MIN_MACOS="13.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read version from single source of truth (AppVersion.swift)
VERSION=$(grep 'static let current' "$PROJECT_ROOT/ClaudeMeterPro/AppVersion.swift" | sed 's/.*"\(.*\)".*/\1/')

BUILD_DIR="$PROJECT_ROOT/.build/arm64-apple-macosx/release"
APP_BUNDLE="$PROJECT_ROOT/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_PATH="$PROJECT_ROOT/$DMG_NAME"

# Apple Silicon only. For universal binary (Intel + Apple Silicon), install full Xcode then use:
# ARCH_FLAGS="--arch arm64 --arch x86_64"
ARCH_FLAGS="--arch arm64"

echo "=== Building ${DISPLAY_NAME} v${VERSION} ==="
echo ""

# Step 1: Build release binary
echo "[1/5] Building release binary..."
cd "$PROJECT_ROOT"
swift build -c release $ARCH_FLAGS
echo "      Binary: $BUILD_DIR/$APP_NAME"

# Step 2: Create .app bundle
echo "[2/5] Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cp "$PROJECT_ROOT/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Step 3: Generate Info.plist
echo "[3/5] Writing Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Step 4: Code signing (optional)
if [ -n "${DEVELOPER_ID:-}" ]; then
    echo "[4/6] Code signing with: $DEVELOPER_ID"
    codesign --force --options runtime --deep --sign "$DEVELOPER_ID" \
        --entitlements "$PROJECT_ROOT/ClaudeMeterPro/ClaudeMeterPro.entitlements" \
        --timestamp \
        "$APP_BUNDLE"
    echo "      Verifying signature..."
    codesign --verify --deep --strict "$APP_BUNDLE"
    echo "      Signature valid."
else
    echo "[4/6] Skipping code signing (set DEVELOPER_ID env var to sign)"
    echo "      Unsigned apps: users must right-click > Open on first launch"
fi

# Step 5: Create DMG
echo "[5/6] Creating DMG..."
STAGING=$(mktemp -d)
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "$DISPLAY_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" \
    -quiet

# Cleanup
rm -rf "$STAGING"
rm -rf "$APP_BUNDLE"

# Step 6: Notarization (optional — requires APPLE_ID, TEAM_ID, and APP_PASSWORD)
if [ -n "${DEVELOPER_ID:-}" ] && [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ]; then
    echo "[6/6] Submitting for notarization..."
    if [ -n "${APP_PASSWORD:-}" ]; then
        NOTARY_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_PASSWORD" \
            --wait 2>&1)
        echo "$NOTARY_OUTPUT"
        if echo "$NOTARY_OUTPUT" | grep -q "status: Accepted"; then
            echo "      Stapling notarization ticket..."
            xcrun stapler staple "$DMG_PATH"
            echo "      Notarization complete. DMG is ready for distribution."
        else
            echo "      Notarization failed. Check output above."
            exit 1
        fi
    else
        echo "      APP_PASSWORD not set. Use an app-specific password from appleid.apple.com"
        echo "      Or store in keychain: xcrun notarytool store-credentials"
        echo "      Then: xcrun notarytool submit \"$DMG_PATH\" --keychain-profile \"notary-profile\" --wait"
    fi
else
    echo "[6/6] Skipping notarization (requires DEVELOPER_ID, APPLE_ID, TEAM_ID, APP_PASSWORD)"
fi

# Summary
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1 | xargs)
echo ""
echo "=== Done! ==="
echo "  DMG: $DMG_PATH"
echo "  Size: $DMG_SIZE"
echo "  Version: v${VERSION}"
if [ -n "${DEVELOPER_ID:-}" ]; then
    echo "  Signed: Yes"
    if [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ]; then
        echo "  Notarized: Yes"
    else
        echo "  Notarized: No (set APPLE_ID, TEAM_ID, APP_PASSWORD)"
    fi
else
    echo "  Signed: No (set DEVELOPER_ID)"
fi
echo ""
echo "Environment variables for full signing + notarization:"
echo "  DEVELOPER_ID=\"Developer ID Application: Your Name (TEAM_ID)\""
echo "  APPLE_ID=\"your@email.com\""
echo "  TEAM_ID=\"YOUR_TEAM_ID\""
echo "  APP_PASSWORD=\"app-specific-password-from-appleid.apple.com\""
