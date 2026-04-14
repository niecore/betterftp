import 'package:betterftp/app.dart';
import 'package:betterftp/features/bluetooth/data/device_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('home screen loads with all expected elements', ($) async {
    // Initialize Hive (same as main.dart)
    await Hive.initFlutter();

    // Initialize device storage and clear any saved devices
    // so the app doesn't try to auto-reconnect during the test
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
    // of the looping video player on the home screen
    for (var i = 0; i < 20; i++) {
      await $.pump(const Duration(milliseconds: 100));
    }

    // Verify mode selector block
    expect($('SELECT PROTOCOL'), findsOneWidget);
    expect($('Ramp Test'), findsOneWidget);

    // Verify pairing block
    expect($('PAIRING'), findsOneWidget);
    expect($('Trainer'), findsOneWidget);
    expect($('Heart Rate'), findsOneWidget);
  });
}
