# BetterFTP App - Claude Context File

This file provides context for Claude Code to understand the project and continue development across sessions.

## Project Overview

**Goal**: Build a cross-platform mobile app (iOS/Android) using Flutter that:
1. Connects to FTMS-compatible indoor cycling trainers (Zwift Hub, Wahoo Kickr, etc.)
2. Controls the trainer in ERG mode (sets target power)
3. Performs FTP ramp tests with automatic FTP calculation

## Technology Decisions

- **Framework**: Flutter (chosen for dedicated `flutter_ftms` package)
- **State Management**: Riverpod
- **Local Storage**: Hive
- **Charting**: fl_chart
- **Protocol**: Bluetooth FTMS (Fitness Machine Service)

## Design System

**Brand:** FTP.TEST — POWER LAB | **Style:** Bold retro / boxy 2000s

### Key Design Files
- `design/design-guideline.md` — Full design specs, component rules, layout
- `design/color-schema.md` — Color palette with usage rules
- `design/design-system.css` — CSS tokens (translate to Flutter equivalents)
- `design/index.html` — Interactive click dummy (3 screens: Home, Test, Result)

### Quick Reference
- **Font**: Iosevka monospace (400/500/700/900) — used for ALL text
- **Colors**: Teal (`#0D9488`) = primary, Pink (`#EC4899`) = secondary, Yellow (`#FACC15`) = press/hover ONLY (never at rest)
- **Neutrals**: Dark (`#1a1a1a`) = borders/text, Bg (`#F5F5F0`) = scaffold, Card (`#FFFFFF`) = block bodies
- **Core component**: "Block" = bordered card (3px border, 14px radius) with colored header strip (teal/pink/dark)
- **Buttons**: All turn yellow on press. Types: primary (dark), teal, pink, outline
- **Logo**: "FTP." (teal, dot in pink) linebreak "TEST" (teal), subtitle "POWER LAB" in #ccc

### Screens (3 total)
1. **Home** — Logo, mode selector block, pairing block (trainer + HR), start button
2. **Test Running** — Timer, warmup bar + skip, 2×2 stat grid (power/HR/cadence/speed), progress bar, stop/finish buttons
3. **Result** — FTP value (large), avg HR + duration cards, test summary details, save/home buttons

## Key Technical Details

### FTMS Protocol
- Service UUID: 0x1826
- Indoor Bike Data Characteristic: 0x2AD2 (read power, cadence)
- Control Point Characteristic: 0x2AD9 (set target power)
- Set Target Power Op Code: 0x05 (followed by 2 bytes little-endian watts)

### FTP Ramp Test Protocol
- Warm-up: 5 min at 100W
- Ramp: Start 100W, increase 20W every minute
- Continue until exhaustion (cadence drops)
- FTP = Best 1-minute average power × 0.75

## Project Structure

Key directories:
- `lib/features/bluetooth/` - FTMS device connection
- `lib/features/ramp_test/` - Test logic and UI
- `lib/features/results/` - FTP display and history
- `lib/core/theme/` - App theme, color tokens, spacing tokens
- `lib/shared/widgets/` - Reusable design system widgets (block_card, app_button, stat_card, etc.)
- `design/` - Design guidelines, color schema, click dummy, CSS reference

## Current Status

- Flutter project exists at `betterftp/` with BLE/FTMS, ramp test logic, HUD UI, results + FIT export implemented
- Website static landing page at `website/` (deployed to Cloudflare Pages, domain `betterftp.cc`)
- Open: Hive result persistence, unit tests, hardware verification, Firebase App Distribution beta setup

## Development Setup

### Prerequisites

The Nix flake provides Flutter. Platform toolchains must be installed separately:

### Android (Android Studio)

1. Download Android Studio from https://developer.android.com/studio
2. Install and open Android Studio
3. Go to **Settings > Languages & Frameworks > Android SDK**
4. In **SDK Platforms** tab: Install Android 14 (API 34) or newer
5. In **SDK Tools** tab: Ensure these are installed:
   - Android SDK Build-Tools
   - Android SDK Command-line Tools
   - Android Emulator (optional, for testing without device)
6. Accept licenses: `flutter doctor --android-licenses`
7. Verify: `flutter doctor` should show Android toolchain ✓

### iOS/macOS (Xcode)

1. Install Xcode from the Mac App Store
2. Open Xcode once to accept the license agreement
3. Run these commands:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
4. Install CocoaPods: `sudo gem install cocoapods`
5. Verify: `flutter doctor` should show Xcode ✓

### Verify Setup

```bash
# Enter dev environment
nix develop

# Check all toolchains
flutter doctor
```

## Commands

```bash
# Run on device (from betterftp/ directory)
cd betterftp && flutter run

# Run tests (from betterftp/ directory)
cd betterftp && flutter test
```

## Important Files to Read

When resuming work:
1. `pubspec.yaml` - Dependencies
2. `design/design-guideline.md` - Design specs, component rules, screen layouts
3. `design/color-schema.md` - Color palette and usage rules
4. `design/index.html` - Click dummy prototype (open in browser to preview)
5. `lib/features/bluetooth/data/trainer_repository.dart` - FTMS integration
6. `lib/features/ramp_test/presentation/ramp_test_controller.dart` - Test logic
7. `lib/core/theme/app_colors.dart` - Color palette implementation

## User Context

- User is a beginner to mobile/BLE development
- Scope: MVP with FTP Ramp Test only
- Protocol: FTMS only (no ANT+ or proprietary)
