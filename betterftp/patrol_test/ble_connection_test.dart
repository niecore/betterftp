import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'e2e_helpers.dart';

void main() {
  patrolTest(
    'scan, connect to FTMS simulator, and verify live data',
    ($) async {
      // 1. Launch app
      await initApp($);

      // 2. Verify home screen elements
      expect($('SELECT PROTOCOL'), findsOneWidget);
      expect($('PAIRING'), findsOneWidget);
      expect($('Trainer'), findsOneWidget);

      // 3. Scan and connect to the simulator
      await scanAndConnect($);

      // 4. Verify the device name appears in the trainer row
      expect($(simulatorDeviceName), findsOneWidget);

      // 5. Verify CONNECTED tag
      expect($('CONNECTED'), findsOneWidget);

      // 6. Poll for live RPM data (up to 10s)
      var hasRpm = false;
      for (var i = 0; i < 20; i++) {
        await pumpFrames($, count: 5, interval: const Duration(milliseconds: 100));
        if ($(find.textContaining('RPM')).exists) {
          hasRpm = true;
          break;
        }
      }
      expect(hasRpm, isTrue, reason: 'Live RPM data not received within 10s');
    },
  );
}
