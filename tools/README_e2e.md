# E2E Testing with Real BLE

End-to-end tests that validate the full user journey over **real Bluetooth** using our own FTMS trainer simulator.

**Architecture:** Real phone (iOS/Android) runs the app via Patrol. This Mac runs the FTMS simulator as a fake trainer. They communicate over actual Bluetooth — no mocks.

## Prerequisites

- A Mac with Bluetooth (to run the simulator)
- A physical phone connected via USB (Android or iOS)
- Node.js 18+ (for the BLE simulator)
- Flutter SDK (via `nix develop`)
- Patrol CLI (`dart pub global activate patrol_cli`)

## 1. Install the FTMS Simulator

```bash
cd tools && npm install
```

This installs `@stoprocent/bleno`, an actively maintained BLE peripheral library for Node.js/macOS.

## 2. Install Patrol CLI

```bash
dart pub global activate patrol_cli
patrol doctor  # verify setup
```

## 3. Running Tests

### Terminal 1 — Start the Simulator

**Option A: Interactive mode** (control power/cadence with keyboard)
```bash
node tools/ftms_simulator.js
```

**Option B: Scripted scenario** (auto-emits escalating power for ~55s)
```bash
node tools/ftms_scenario.js
```

Both advertise as **"Zwack"** over BLE with the FTMS Indoor Bike profile.

### Terminal 2 — Run Tests

```bash
cd betterftp

# Run a specific test
patrol test -t patrol_test/ble_connection_test.dart

# Run the full ramp test E2E
patrol test -t patrol_test/ble_ramp_test_e2e.dart

# Run the disconnect test (requires manually stopping the simulator mid-test)
patrol test -t patrol_test/ble_disconnect_test.dart

# Run all E2E tests
patrol test
```

## 4. Test Descriptions

### `ble_connection_test.dart` — Scan & Connect

Validates BLE scanning, device discovery, and connection:
1. App launches, grants BLE/Location permissions
2. Taps "Trainer" to open scan sheet
3. Verifies "Zwack" appears in device list
4. Taps to connect, verifies "Connected" state
5. Verifies live cadence data flows (RPM reading)

### `ble_ramp_test_e2e.dart` — Full Ramp Test

Complete user journey:
1. Connects to the simulator
2. Navigates through Instructions screen
3. Starts ramp test, verifies warmup phase
4. Skips warmup, verifies stage transitions
5. Stops test, verifies Results screen with FTP value
6. Navigates back to home

Best used with the scripted scenario (`node tools/ftms_scenario.js`).

### `ble_disconnect_test.dart` — Mid-Test Disconnect

Tests graceful disconnect handling:
1. Connects and starts test
2. Operator manually stops the simulator (Ctrl+C) within 30s window
3. Verifies app doesn't crash
4. Verifies user can navigate back to home

## 5. Simulator Details

### Interactive Mode (`ftms_simulator.js`)

Keyboard controls:

| Key | Action |
|-----|--------|
| `p` / `P` | Decrease / Increase power by 10W |
| `c` / `C` | Decrease / Increase cadence by 10 RPM |
| `q` | Quit |

### Scripted Scenario (`ftms_scenario.js`)

Emits a pre-defined power curve:

| Phase | Duration | Power | Cadence |
|-------|----------|-------|---------|
| Warmup | 10s | ~100W | 85 RPM |
| Stage 1 | 10s | ~120W | 88 RPM |
| Stage 2 | 10s | ~140W | 90 RPM |
| Stage 3 | 10s | ~160W | 92 RPM |
| Stage 4 | 10s | ~180W | 94 RPM |
| Exhaust | 5s | 60W | 0 RPM |

Total: ~55 seconds. Power values include ±5W jitter for realism.

### FTMS Protocol

Both simulators implement:
- **Service:** `0x1826` (Fitness Machine)
- **Indoor Bike Data** (`0x2AD2`): Notify — broadcasts power (sint16) + cadence (uint16 at 0.5 RPM)
- **Control Point** (`0x2AD9`): Write + Indicate — accepts Request Control (0x00) and Set Target Power (0x05)
- **FTMS Feature** (`0x2ACC`): Read — reports cadence + power + target power support
- **Supported Power Range** (`0x2AD8`): Read — 0–2000W, 1W steps

## 6. Troubleshooting

### Simulator won't start
- Run `node --version` — needs 18+
- Run `cd tools && npm install` if `@stoprocent/bleno` is missing
- macOS may prompt for Bluetooth permission — allow it

### Phone can't find the simulator
- Phone and Mac must be within BLE range (~10m)
- On Android: ensure Location Services are enabled
- On iOS: ensure Bluetooth permission is granted in Settings
- Restart Bluetooth on Mac if needed: System Settings > Bluetooth > Toggle off/on

### Patrol test won't start
- Run `patrol doctor` to check setup
- Ensure phone is connected: `flutter devices`
- On Android: verify `testInstrumentationRunner` is set in `build.gradle.kts`

### Permission dialogs not handled
- Patrol handles native permission dialogs automatically
- On Android 12+: needs BLUETOOTH_SCAN + BLUETOOTH_CONNECT + ACCESS_FINE_LOCATION
- On iOS: needs Bluetooth Usage + Location Usage

## 7. iOS Setup (Manual Steps)

Patrol's iOS integration requires Xcode:

1. Open `betterftp/ios/Runner.xcworkspace` in Xcode
2. File > New > Target > UI Testing Bundle
3. Name it `RunnerUITests`, set language to Swift
4. In the new target's Build Settings, set "iOS Deployment Target" to match Runner
5. Replace `RunnerUITests.swift` content with:
   ```swift
   import XCTest

   final class RunnerUITests: XCTestCase {
       override func setUpWithError() throws {
           continueAfterFailure = false
       }

       func testRunner() {}
   }
   ```
6. Run `cd ios && pod install`
7. Verify with `patrol doctor`
