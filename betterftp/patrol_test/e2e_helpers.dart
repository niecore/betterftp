import 'package:betterftp/app.dart';
import 'package:betterftp/features/bluetooth/data/device_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:patrol/patrol.dart';

/// Name advertised by the FTMS simulator (tools/ftms_scenario.js).
const simulatorDeviceName = 'BetterTrainerSimulator';

/// Initialize the app for E2E testing.
///
/// Starts Hive, clears stored devices (prevents auto-reconnect),
/// pumps the widget tree, and waits for the home screen to settle.
Future<void> initApp(PatrolIntegrationTester $) async {
  await Hive.initFlutter();

  final deviceStorage = DeviceStorageService();
  await deviceStorage.init();
  await deviceStorage.clearTrainer();
  await deviceStorage.clearHrMonitor();

  await $.pumpWidget(
    ProviderScope(
      overrides: [
        deviceStorageServiceProvider.overrideWithValue(deviceStorage),
      ],
      child: const BetterFtpApp(),
    ),
  );

  // Pump frames manually — pumpAndSettle times out because
  // of the looping video player on the home screen.
  await pumpFrames($, count: 30);
}

/// Pump [count] frames with the given [interval] between each.
///
/// Use this instead of `pumpAndSettle()` everywhere — the home screen's
/// looping video player means `pumpAndSettle` never completes.
Future<void> pumpFrames(
  PatrolIntegrationTester $, {
  int count = 10,
  Duration interval = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < count; i++) {
    await $.pump(interval);
  }
}

/// Handle the iOS Bluetooth permission dialog ("OK" button).
///
/// This dialog only appears on the first launch after install.
/// On subsequent launches this is a no-op (try/catch).
Future<void> handleBluetoothPermission(PatrolIntegrationTester $) async {
  try {
    await $.native.tap(Selector(text: 'OK'));
    await pumpFrames($, count: 5);
  } catch (_) {
    // Permission dialog not shown — already granted.
  }
}

/// Scan for and connect to the FTMS simulator.
///
/// 1. Taps the "Trainer" row to open the scan sheet.
/// 2. Handles the BLE permission dialog (iOS first-launch only).
/// 3. Polls up to 15 seconds for the simulator device to appear.
/// 4. Taps the device to connect.
/// 5. Waits for the CONNECTED tag to appear.
Future<void> scanAndConnect(PatrolIntegrationTester $) async {
  // Tap the Trainer pairing row to open the scan bottom sheet
  await $(find.text('Trainer')).tap();
  await pumpFrames($, count: 5);

  // Handle BLE permission dialog (iOS first-launch only)
  await handleBluetoothPermission($);

  // Poll for the simulator device to appear in the scan list (up to 15s)
  var found = false;
  for (var i = 0; i < 30; i++) {
    await pumpFrames($, count: 5, interval: const Duration(milliseconds: 100));
    if ($(simulatorDeviceName).exists) {
      found = true;
      break;
    }
  }
  expect(found, isTrue, reason: 'Simulator "$simulatorDeviceName" not found in scan list within 15s');

  // Tap the simulator device to connect
  await $(simulatorDeviceName).tap();
  await pumpFrames($, count: 10);

  // Wait for CONNECTED tag to appear (up to 10s)
  var connected = false;
  for (var i = 0; i < 20; i++) {
    await pumpFrames($, count: 5, interval: const Duration(milliseconds: 100));
    if ($('CONNECTED').exists) {
      connected = true;
      break;
    }
  }
  expect(connected, isTrue, reason: 'Device did not reach CONNECTED state within 10s');
}
