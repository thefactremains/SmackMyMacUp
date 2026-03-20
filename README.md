# SmackMyMacUp

Your MacBook has feelings. Hit it and find out.

**SmackMyMacUp** is a native macOS menu bar app that uses your MacBook's accelerometer to detect physical slaps, smacks, and taps — then plays sound effects in response. Slap it gently, it whimpers. Slap it hard, it screams. It's the app nobody asked for but everybody needs.

## What does it do?

When you physically smack your MacBook, the built-in accelerometer picks up the impact. SmackMyMacUp translates that into audio feedback — anything from a pained "ow!" to... well, let's just say there are multiple modes.

**Three modes to choose from:**

- **Pain** — Your Mac says "ow!" like a reasonable being that just got hit
- **Sexy** — Escalating responses based on how often you slap it. We won't elaborate.
- **Halo** — Classic Halo death sounds. For the nostalgic slappers.

## Features

- Lives in your menu bar — zero desktop clutter
- Real-time sensitivity, cooldown, and speed controls
- System volume slider built right in
- Live slap counter (flex your numbers)
- Launch at login — because your Mac should always be ready for abuse
- Pause/resume without quitting
- Volume scaling — harder slaps = louder sounds
- Fast mode for the impatient
- One-time admin setup, no password prompts after that

## Install

1. Download `SmackMyMacUp.dmg` from the [latest release](https://github.com/thefactremains/SmackMyMacUp/releases/latest)
2. Open the DMG and drag to Applications
3. If macOS blocks it: `xattr -cr /Applications/SmackMyMacUp.app`
4. Launch from Applications — look for the hand icon in your menu bar
5. Click it, toggle "Enabled", enter your password once, and start slapping

## Build from source

```bash
git clone https://github.com/thefactremains/SmackMyMacUp.git
cd SmackMyMacUp

# Build the spank engine
git clone https://github.com/taigrr/spank.git temp-spank
cd temp-spank
CGO_ENABLED=1 go build -o spank-binary -ldflags "-s -w" .
cd ..

# Build the app and DMG
cd SpankMac
./build.sh
```

Output lands in `SpankMac/.build/`.

### Requirements

- macOS 13+ on Apple Silicon (M1/M2/M3+)
- Go 1.21+ (for building the spank binary)
- Xcode Command Line Tools

## How it works

SmackMyMacUp is a native Swift menu bar app that wraps the [spank](https://github.com/taigrr/spank) engine. It launches `spank` in `--stdio` mode, communicating over JSON via stdin/stdout. Settings changes are sent live — no restarts needed for sensitivity, cooldown, or speed tweaks. Mode changes restart the engine seamlessly in the background.

The accelerometer requires root access, so the app creates a one-time sudoers entry on first launch (with your permission). After that, no more password prompts.

## Why?

Because your MacBook has been sitting there all smug, thinking it's safe. It's not. Not anymore.

Also, it's a great party trick.

---

Built with questionable judgment by [@thefactremains](https://github.com/thefactremains)

Powered by [spank](https://github.com/taigrr/spank) by [@taigrr](https://github.com/taigrr)
