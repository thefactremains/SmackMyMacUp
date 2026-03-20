# WhacMyMac

Native macOS menu bar app for [spank](https://github.com/taigrr/spank) — slap your MacBook, it yells back.

## Features

- Menu bar UI with settings popover
- Mode selection: Pain, Sexy, Halo
- Sensitivity, cooldown, speed controls
- Volume scaling toggle
- Fast mode toggle
- Pause/resume
- Live slap counter
- Packaged as DMG installer

## Requirements

- macOS 13+ on Apple Silicon (M2+)
- Go 1.26+ (for building the spank binary)
- Xcode Command Line Tools (for Swift compilation)

## Build

```bash
# Clone the repo
git clone https://github.com/YOUR_USER/WhacMyMac.git
cd WhacMyMac

# Clone the spank source
git clone https://github.com/taigrr/spank.git temp-spank
cd temp-spank
CGO_ENABLED=1 go build -o spank-binary -ldflags "-s -w" .
cd ..

# Build the app and DMG
cd SpankMac
./build.sh
```

The built `.app` and `.dmg` will be in `SpankMac/.build/`.

## Install

1. Open `WhacMyMac.dmg`
2. Drag `WhacMyMac.app` to Applications
3. Launch from Applications — it appears in the menu bar
4. Click the hand icon to configure settings
5. Toggle "Enabled" to start (requires sudo password for accelerometer access)

## How it works

The app wraps the Go `spank` binary, launching it with `--stdio` mode for JSON communication. The menu bar UI sends settings changes via stdin and reads slap events from stdout.
