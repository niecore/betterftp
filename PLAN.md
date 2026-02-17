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
│   │   └── app_theme.dart
│   └── utils/
│       └── permissions.dart               # BLE permission handling
│
└── shared/
    └── widgets/
        └── common_widgets.dart
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

## 6. User Interface Screens

### Screen 1: Device Scanner
- Scan button
- List of discovered FTMS trainers
- Connection status indicator
- Connect/disconnect buttons

### Screen 2: Ramp Test (Main)
- Large power display (current vs target)
- Cadence display
- Timer (stage time / total time)
- Current stage indicator
- Progress bar
- Start/Stop buttons

### Screen 3: Results
- Calculated FTP value
- Power curve graph
- Test summary (duration, max power, stages completed)
- Save/Share options

---

## 7. Implementation Phases

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

### Phase 4: User Interface
- [ ] Build device scan screen
- [ ] Build ramp test screen with real-time displays
- [ ] Build results screen
- [ ] Add power chart visualization

### Phase 5: Polish & Testing
- [ ] Add test result persistence (Hive)
- [ ] Handle edge cases (disconnection, low cadence)
- [ ] Test with real trainer hardware
- [ ] UI polish and error handling

---

## 8. Platform Configuration

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

## 9. Testing Strategy

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

## 10. Verification Plan

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
