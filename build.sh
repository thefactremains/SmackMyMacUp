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
    "$SCRIPT_DIR/Sources/UpdateChecker.swift" \
    -o "$MACOS_DIR/SmackMyMacUp" \
    2>&1

echo "==> Assembling app bundle..."
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy the Go binary into Resources
cp "$SPANK_BINARY" "$RESOURCES_DIR/spank"
chmod +x "$RESOURCES_DIR/spank"

# Copy app icon
if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Ad-hoc code sign to reduce Gatekeeper friction
echo "==> Ad-hoc signing..."
codesign --force --deep -s - "$APP_DIR"

echo "==> Built: $APP_DIR"
echo "==> Size: $(du -sh "$APP_DIR" | cut -f1)"

# Create zip distribution
echo "==> Creating zip..."
ZIP_DIR="$BUILD_DIR/zip-staging"
ZIP_PATH="$BUILD_DIR/SmackMyMacUp.zip"
mkdir -p "$ZIP_DIR"
cp -R "$APP_DIR" "$ZIP_DIR/"

# Create installer script
cat > "$ZIP_DIR/Install.command" << 'INSTALLER'
#!/bin/bash
clear
echo "=============================="
echo "  SmackMyMacUp Installer"
echo "=============================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Close the app if running
pkill -x SmackMyMacUp 2>/dev/null && sleep 1

echo "Installing SmackMyMacUp.app..."
cp -R "$SCRIPT_DIR/SmackMyMacUp.app" /Applications/
xattr -cr /Applications/SmackMyMacUp.app
echo "✓ Installed to /Applications"
echo "✓ Quarantine flag removed"
echo ""
echo "Launching SmackMyMacUp..."
open /Applications/SmackMyMacUp.app
echo ""
echo "Done! You can close this window."
INSTALLER
chmod +x "$ZIP_DIR/Install.command"

cd "$ZIP_DIR"
zip -r "$ZIP_PATH" . -x ".*"
cd "$SCRIPT_DIR"
rm -rf "$ZIP_DIR"

echo "==> Zip created: $ZIP_PATH"
echo "==> Done!"
