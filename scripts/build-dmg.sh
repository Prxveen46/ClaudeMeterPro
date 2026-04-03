#!/bin/bash
set -euo pipefail

# ============================================================
# ClaudeMeterPro DMG Builder
# Usage: bash scripts/build-dmg.sh
# Optional: DEVELOPER_ID="Developer ID Application: ..." bash scripts/build-dmg.sh
# ============================================================

APP_NAME="ClaudeMeterPro"
DISPLAY_NAME="ClaudeMeter Pro"
VERSION="1.1.0"
BUNDLE_ID="com.praveenkumar.ClaudeMeterPro"
MIN_MACOS="13.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build/arm64-apple-macosx/release"
APP_BUNDLE="$PROJECT_ROOT/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_PATH="$PROJECT_ROOT/$DMG_NAME"

# For universal binary (Intel + Apple Silicon), uncomment:
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
    echo "[4/5] Code signing with: $DEVELOPER_ID"
    codesign --force --deep --sign "$DEVELOPER_ID" \
        --entitlements "$PROJECT_ROOT/ClaudeMeterPro/ClaudeMeterPro.entitlements" \
        "$APP_BUNDLE"
else
    echo "[4/5] Skipping code signing (set DEVELOPER_ID env var to sign)"
    echo "      Unsigned apps: users must right-click > Open on first launch"
fi

# Step 5: Create DMG
echo "[5/5] Creating DMG..."
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

# Summary
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1 | xargs)
echo ""
echo "=== Done! ==="
echo "  DMG: $DMG_PATH"
echo "  Size: $DMG_SIZE"
echo "  Version: v${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test: open \"$DMG_PATH\""
echo "  2. Code sign: DEVELOPER_ID=\"Developer ID Application: Your Name\" bash $0"
echo "  3. Notarize: xcrun notarytool submit \"$DMG_PATH\" --apple-id YOUR_ID --team-id YOUR_TEAM"
