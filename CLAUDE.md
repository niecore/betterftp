# FTP Ramp Test App - Claude Context File

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

See PLAN.md for full architecture. Key directories:
- `lib/features/bluetooth/` - FTMS device connection
- `lib/features/ramp_test/` - Test logic and UI
- `lib/features/results/` - FTP display and history

## Current Status

- [ ] Project not yet created
- Refer to PLAN.md Section 7 for implementation phases

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
# Create project
flutter create ftp_ramp_test --org com.example

# Run on device
flutter run

# Run tests
flutter test
```

## Important Files to Read

When resuming work:
1. `PLAN.md` - Full implementation plan
2. `pubspec.yaml` - Dependencies (once created)
3. `lib/features/bluetooth/data/trainer_repository.dart` - FTMS integration
4. `lib/features/ramp_test/presentation/ramp_test_controller.dart` - Test logic

## User Context

- User is a beginner to mobile/BLE development
- Scope: MVP with FTP Ramp Test only
- Protocol: FTMS only (no ANT+ or proprietary)
