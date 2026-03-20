#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/.build"
APP_NAME="SmackMyMacUp.app"
APP_DIR="$BUILD_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Build the Go binary if not already built
SPANK_BINARY="$PROJECT_DIR/temp-spank/spank-binary"
if [ ! -f "$SPANK_BINARY" ]; then
    echo "==> Building Go binary..."
    cd "$PROJECT_DIR/temp-spank"
    CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 go build -o spank-binary -ldflags "-s -w" .
    cd "$SCRIPT_DIR"
fi

echo "==> Building Swift app..."
swiftc \
    -target arm64-apple-macos13.0 \
    -O \
    -sdk "$(xcrun --show-sdk-path)" \
    -parse-as-library \
    "$SCRIPT_DIR/Sources/SpankMacApp.swift" \
    "$SCRIPT_DIR/Sources/AppDelegate.swift" \
    "$SCRIPT_DIR/Sources/SpankEngine.swift" \
    "$SCRIPT_DIR/Sources/SettingsView.swift" \
    -o "$MACOS_DIR/SmackMyMacUp" \
    2>&1

echo "==> Assembling app bundle..."
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy the Go binary into Resources
cp "$SPANK_BINARY" "$RESOURCES_DIR/spank"
chmod +x "$RESOURCES_DIR/spank"

echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "==> Built: $APP_DIR"
echo "==> Size: $(du -sh "$APP_DIR" | cut -f1)"

# Create DMG
echo "==> Creating DMG..."
DMG_DIR="$BUILD_DIR/dmg-staging"
DMG_PATH="$BUILD_DIR/SmackMyMacUp.dmg"
mkdir -p "$DMG_DIR"
cp -R "$APP_DIR" "$DMG_DIR/"

ln -s /Applications "$DMG_DIR/Applications"

if command -v create-dmg &>/dev/null; then
    create-dmg \
        --volname "SmackMyMacUp" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME" 150 185 \
        --icon "Applications" 450 185 \
        --hide-extension "$APP_NAME" \
        --app-drop-link 450 185 \
        "$DMG_PATH" \
        "$DMG_DIR" \
        2>&1 || {
            echo "create-dmg failed, using hdiutil..."
            hdiutil create -volname "SmackMyMacUp" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_PATH"
        }
else
    echo "create-dmg not found, using hdiutil..."
    hdiutil create -volname "SmackMyMacUp" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_PATH"
fi

rm -rf "$DMG_DIR"

echo "==> DMG created: $DMG_PATH"
echo "==> Done!"
