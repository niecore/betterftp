# Indoor Cycling Trainer FTP Ramp Test App - Implementation Plan

## Executive Summary
Build a cross-platform (iOS/Android) mobile app using **Flutter** that connects to FTMS-compatible indoor cycling trainers (Zwift Hub, Wahoo Kickr, etc.) and performs FTP ramp tests.

---

## 1. Technology Stack

### Framework: Flutter
**Why Flutter over React Native:**
- **Dedicated FTMS library**: `flutter_ftms` handles all protocol complexity
- **Proven compatibility**: Tested with Zwift Hub, Wahoo trainers
- **Single codebase**: One implementation for iOS and Android
- **Beginner-friendly**: Less custom BLE code required

### Core Dependencies
```yaml
dependencies:
  flutter_ftms: ^1.0.0          # FTMS protocol handling (includes flutter_blue_plus)
  flutter_riverpod: ^2.4.0      # State management
  go_router: ^13.0.0            # Navigation
  hive: ^2.2.3                  # Local storage for test results
  fl_chart: ^0.66.0             # Real-time power charts
  wakelock_plus: ^1.1.0         # Keep screen on during test
  permission_handler: ^11.0.0   # BLE permissions
```

### Development Tools
- **Flutter SDK**: 3.19+ (latest stable)
- **Dart SDK**: 3.3+
- **IDE**: VS Code with Flutter extension or Android Studio
- **Testing**: Flutter test + integration_test

---

## 2. FTMS Protocol Overview

### What is FTMS?
Fitness Machine Service (FTMS) is the Bluetooth SIG standard for fitness equipment communication.

### Key BLE Characteristics
| Characteristic | UUID | Purpose |
|---------------|------|---------|
| FTMS Service | 0x1826 | Service identifier |
| Indoor Bike Data | 0x2AD2 | Power, cadence, speed data |
| Control Point | 0x2AD9 | Set target power (ERG mode) |
| Machine Features | 0x2ACC | Supported features |
| Machine Status | 0x2ADA | Trainer status changes |

### ERG Mode Control
The app will use the Control Point characteristic to set target power:
1. Request control (Op Code 0x00)
2. Set target power (Op Code 0x05) with power in watts (little-endian uint16)

---

## 3. FTP Ramp Test Protocol

### Standard Ramp Test
Based on Zwift/TrainerRoad protocol:

| Phase | Duration | Power Target |
|-------|----------|--------------|
| Warm-up | 5 min | 100W (easy spinning) |
| Ramp Start | - | 100W |
| Ramp Increment | Every 60 sec | +20W |
| End | User exhaustion | Can't maintain cadence |

### Ramp Test Lite (Optional - for lighter riders)
- Start: 50W
- Increment: +10W per minute

### FTP Calculation
```
FTP = Best 1-minute average power × 0.75
```

Example: If rider fails at 320W after completing the 300W stage:
- Best 1-min power ≈ 300W
- FTP = 300 × 0.75 = 225W

---

## 4. App Architecture

### Project Structure
```
lib/
├── main.dart
├── app.dart                      # App configuration, routing
│
├── features/
│   ├── bluetooth/
│   │   ├── data/
│   │   │   └── trainer_repository.dart    # FTMS device operations
│   │   ├── domain/
│   │   │   ├── trainer.dart               # Trainer entity
│   │   │   └── trainer_data.dart          # Power/cadence data
│   │   └── presentation/
│   │       ├── device_scan_screen.dart    # Scan & connect UI
│   │       └── device_scan_controller.dart
│   │
│   ├── ramp_test/
│   │   ├── data/
│   │   │   └── ramp_test_repository.dart  # Test result storage
│   │   ├── domain/
│   │   │   ├── ramp_test_config.dart      # Test parameters
│   │   │   ├── ramp_test_state.dart       # Current test state
│   │   │   └── ftp_calculator.dart        # FTP calculation logic
│   │   └── presentation/
│   │       ├── ramp_test_screen.dart      # Main test UI
│   │       ├── ramp_test_controller.dart  # Test orchestration
│   │       └── widgets/
│   │           ├── power_gauge.dart       # Current power display
│   │           ├── target_power_display.dart
│   │           ├── cadence_display.dart
│   │           └── timer_display.dart
│   │
│   └── results/
│       └── presentation/
│           └── results_screen.dart        # FTP result display
│
├── core/
│   ├── constants/
│   │   └── ftms_constants.dart            # UUIDs, op codes
│   ├── theme/
│   │   ├── app_theme.dart                 # ThemeData, Iosevka font, colors
│   │   ├── app_colors.dart                # Color palette tokens (teal/pink/yellow/dark)
│   │   └── app_spacing.dart               # Spacing tokens (xs through 3xl)
│   └── utils/
│       └── permissions.dart               # BLE permission handling
│
├── shared/
│   └── widgets/
│       ├── block_card.dart                # Block component (header + body)
│       ├── app_button.dart                # Button variants with yellow press
│       ├── stat_card.dart                 # 2×2 stat grid card
│       ├── tag_widget.dart                # ON/OFF status tags
│       ├── icon_box.dart                  # 36×36 icon boxes
│       └── phase_badge.dart               # Warmup/testing phase badge
```

### State Management Flow
```
User Action → Controller → Repository → FTMS Device
                ↓
            State Update → UI Rebuild
```

---

## 5. Key Implementation Details

### 5.1 Device Connection Flow
```dart
// Using flutter_ftms
1. Request BLE permissions
2. Scan for FTMS devices: FTMS.scanForDevices()
3. Filter by device type: DeviceDataType.indoorBike
4. Connect to selected device
5. Subscribe to Indoor Bike Data characteristic
6. Request control of Control Point
```

### 5.2 Ramp Test State Machine
```
IDLE → WARMUP → RAMPING → COMPLETED
         ↓         ↓
       PAUSED ← PAUSED
         ↓         ↓
      CANCELLED  FAILED
```

### 5.3 Power Tracking
During the test, continuously track:
- Instantaneous power (from trainer)
- Rolling 1-minute average power
- Best 1-minute average power (for FTP calculation)
- Current cadence
- Elapsed time per stage

### 5.4 ERG Mode Control
```dart
// Set target power on trainer
await controlPoint.write([
  0x05,                    // Op code: Set Target Power
  power & 0xFF,            // Power low byte
  (power >> 8) & 0xFF,     // Power high byte
]);
```

---

## 6. Design System

### Brand
- **App name:** FTP.TEST
- **Tagline:** POWER LAB
- **Domain:** ftptests.icu
- **Style:** Bold retro / boxy 2000s — chunky borders, monospace typography, color-coded sections

### Font
**Iosevka** (monospace) — used for ALL text (logo, headings, labels, body, values, buttons).
- Weights: 400 (Regular), 500 (Medium), 700 (Bold), 900 (Black)
- Flutter package: `google_fonts` or bundle Iosevka as an asset

### Color Palette (3-color system)
| Role      | Token          | Hex                          | Usage                                    |
|-----------|----------------|------------------------------|------------------------------------------|
| Primary   | `teal`         | `#0D9488`                    | Block headers, power stats, progress bar |
| Primary   | `teal-dark`    | `#0F766E`                    | Cadence stat header                      |
| Primary   | `teal-bg`      | `rgba(13,148,136,0.06)`      | Tag backgrounds, selected option bg      |
| Secondary | `pink`         | `#EC4899`                    | Pairing header, HR stats, logo dot, FTP result |
| Secondary | `pink-bg`      | `rgba(236,72,153,0.06)`      | Warmup phase badge bg                    |
| Confirm   | `yellow`       | `#FACC15`                    | Hover/press bg (NEVER at rest)           |
| Confirm   | `yellow-deep`  | `#EAB308`                    | Hover/press border                       |
| Neutral   | `dark`         | `#1a1a1a`                    | Borders, primary button, text            |
| Neutral   | `bg`           | `#F5F5F0`                    | Page/scaffold background                 |
| Neutral   | `card`         | `#FFFFFF`                    | Card/block body backgrounds              |
| Neutral   | `muted`        | `#AAAAAA`                    | Placeholder, subtitles, units            |
| Neutral   | `border-light` | `#F0F0F0`                    | Row separators                           |
| Icon      | `trainer-bg`   | `#FEF3C7`                    | Trainer icon background                  |
| Icon      | `hr-bg`        | `#FCE7F3`                    | Heart rate icon background               |
| Icon      | `cadence-bg`   | `#F0FDF4`                    | Cadence icon background                  |
| Icon      | `speed-bg`     | `#E0F2FE`                    | Speed icon background                    |

**Key rule:** Yellow NEVER appears at rest — only on hover/press as confirmation feedback.

### Core Component: Block
The primary UI building block — a bordered card with a colored header strip.
- Border: 3px solid `#1a1a1a`, border-radius: 14px
- Header: 9px bold uppercase, 2px letter-spacing, colored bg (teal/pink/dark)
- Body: 16px padding, white background
- Interactive blocks: on press, border → yellow-deep, header bg → yellow-deep

### Buttons
All buttons turn yellow on press (confirmation pattern).
| Type    | Default BG  | Border      | Text   | Press BG  |
|---------|-------------|-------------|--------|-----------|
| Primary | `#1a1a1a`   | `#1a1a1a`   | white  | `#FACC15` |
| Teal    | `#0D9488`   | `#0D9488`   | white  | `#FACC15` |
| Pink    | `#EC4899`   | `#EC4899`   | white  | `#FACC15` |
| Outline | transparent | `#1a1a1a`   | dark   | `#FACC15` |

Specs: 3px border, 14px radius, 17px padding, Iosevka Black 16px (primary) / 14px (secondary).

### Spacing Tokens
| Token | Value | Usage                    |
|-------|-------|--------------------------|
| xs    | 4px   | Tight gaps               |
| sm    | 8px   | Between tags, small gaps |
| md    | 12px  | Block margin, grid gap   |
| lg    | 16px  | Block body padding       |
| xl    | 20px  | Screen side padding      |
| 2xl   | 24px  | Overlay padding          |
| 3xl   | 32px  | Large section spacing    |

Screen padding: 52px top (status bar clearance), 22px sides, 32px bottom.

### Other Components
- **Tags:** 9px bold, 4px/10px padding, 2px border, 4px radius. ON = teal, OFF = #ddd/#ccc
- **Icon Box:** 36×36px, 2.5px border, 10px radius, colored bg per type
- **Phase Badge:** 10px bold uppercase, 2px border, 6px radius. Warmup = pink (pulsing), Testing = teal
- **Progress Bar:** 10px height, 2px border, 5px radius, teal fill
- **Overlay (bottom sheet):** 18px top border-radius, backdrop rgba(0,0,0,0.5)

---

## 7. User Interface Screens

Refer to `design/index.html` for the interactive click dummy prototype.

### Screen 1: Home
- Logo: "FTP." (teal, dot in pink) + "TEST" (teal), subtitle "POWER LAB" (#ccc)
- Mode selector block (teal header) — taps open bottom sheet overlay with options
- Pairing block (pink header) with trainer row (icon + name + connection status + ON/OFF tag) and HR row
- Start Test button (primary/dark, full width)

### Screen 2: Test Running
- Title bar: "Test Running" + phase badge (warmup=pink pulsing / testing=teal)
- Timer block (teal header): large time display (52px), estimated total below
- Warmup bar: target watts + "SKIP" inline button (hidden after warmup)
- 2×2 stat grid:
  - Power (teal header) — value in watts
  - Heart Rate (pink header) — value in BPM
  - Cadence (teal-dark header) — value in RPM
  - Speed (dark header) — value in KM/H
- Progress bar with percentage label
- Stop Test button (pink) + Finish & Calculate button (outline)

### Screen 3: Results
- "Test Complete" badge (teal)
- "Your Results" title
- FTP result block (pink header): large FTP value (68px), watts unit, change vs last test
- 2-column stats: Avg HR (pink header) + Duration (teal header)
- Test Summary block (dark header): detail rows — Avg Power, Max Power, Max HR, Avg Cadence, Test Mode
- Save Result button (teal) + Back to Home button (outline)

### Mode Selector Overlay
- Bottom sheet with backdrop blur
- Options as bordered cards with checkmark
- Selected: teal border + teal bg
- On press: yellow border + yellow bg tint

---

## 8. Implementation Phases

### Phase 1: Project Setup (Foundation)
- [ ] Create Flutter project
- [ ] Configure dependencies
- [ ] Set up iOS/Android BLE permissions
- [ ] Create basic app structure and routing

### Phase 2: Bluetooth/FTMS Integration
- [ ] Implement device scanning
- [ ] Implement device connection
- [ ] Subscribe to Indoor Bike Data
- [ ] Test reading power/cadence data
- [ ] Implement Control Point writing (ERG mode)

### Phase 3: Ramp Test Logic
- [ ] Create ramp test configuration
- [ ] Implement test state machine
- [ ] Build timer and stage progression
- [ ] Implement power target updates (ERG control)
- [ ] Track rolling 1-minute power average

### Phase 4: User Interface (per design system in Section 6)
- [ ] Implement app theme (`app_theme.dart`) with Iosevka font, color palette, spacing tokens
- [ ] Build reusable Block widget (bordered card with colored header)
- [ ] Build reusable button variants (primary, teal, pink, outline) with yellow press feedback
- [ ] Build Home screen: logo, mode selector, pairing block, start button
- [ ] Build Mode Selector overlay (bottom sheet)
- [ ] Build Test Running screen: timer, warmup bar, 2×2 stat grid, progress bar, controls
- [ ] Build Results screen: FTP display, stat cards, test summary detail block
- [ ] Add phase badge with warmup pulse animation

### Phase 5: Polish & Testing
- [ ] Add test result persistence (Hive)
- [ ] Handle edge cases (disconnection, low cadence)
- [ ] Test with real trainer hardware
- [ ] UI polish and error handling

---

## 9. Platform Configuration

### iOS (ios/Info.plist)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to your indoor cycling trainer</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to connect to your indoor cycling trainer</string>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

---

## 10. Testing Strategy

### Unit Tests
- FTP calculation logic
- Ramp test state transitions
- Power averaging algorithms

### Integration Tests
- BLE mock device connection
- Full ramp test flow simulation

### Manual Hardware Testing
- Test with FTMS emulator (ftmsemu.github.io)
- Test with physical trainer (Zwift Hub, Wahoo Kickr, etc.)

---

## 11. Verification Plan

After implementation, verify by:

1. **Device Connection**: Scan and connect to an FTMS trainer
2. **Data Reading**: Confirm power and cadence values are displayed correctly
3. **ERG Control**: Verify trainer resistance changes when target power is set
4. **Full Ramp Test**: Complete a ramp test and verify FTP calculation
5. **Edge Cases**: Test disconnection handling, pausing, and cancellation

---

## References

- [Bluetooth FTMS Specification](https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0/)
- [flutter_ftms Package](https://pub.dev/packages/flutter_ftms)
- [PowerTrain Example App](https://github.com/iliuta/ftms/)
- [FTP Ramp Test Protocol (TrainRight)](https://trainright.com/ftp-tests-how-to-perform-20-minute-8-minute-and-ramp-tests/)
- [TrainerRoad Ramp Test](https://support.trainerroad.com/hc/en-us/articles/360006903031-Ramp-Test-FAQs)
