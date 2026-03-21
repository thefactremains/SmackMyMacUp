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

# Search for the .app bundle in multiple locations
APP_SRC=""
for search_dir in "$SCRIPT_DIR" "$SCRIPT_DIR/.." "$HOME/Downloads" "$HOME/Downloads/SmackMyMacUp" "$HOME/Desktop"; do
    found="$(find "$search_dir" -maxdepth 2 -name "SmackMyMacUp.app" -print -quit 2>/dev/null)"
    if [ -n "$found" ]; then
        APP_SRC="$found"
        break
    fi
done

if [ -z "$APP_SRC" ]; then
    echo "Error: Could not find the app bundle."
    echo ""
    echo "Please extract the zip file first, then run Install.command"
    echo "from the extracted folder."
    exit 1
fi

APP_BASENAME="$(basename "$APP_SRC")"
DEST="/Applications/$APP_BASENAME"

echo "Installing $APP_BASENAME..."
cp -R "$APP_SRC" "/Applications/"
xattr -cr "$DEST"
echo "✓ Installed to /Applications"
echo "✓ Quarantine flag removed"
echo ""
echo "Launching $APP_BASENAME..."
open "$DEST"
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
