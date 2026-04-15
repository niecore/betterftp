import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'e2e_helpers.dart';

void main() {
  patrolTest(
    'full ramp test: connect → instructions → HUD → results → home',
    ($) async {
      // ── Phase 1: Connect ──
      await initApp($);
      await scanAndConnect($);
      expect($('CONNECTED'), findsOneWidget);

      // ── Phase 2: Start ──
      await $(find.textContaining('Start Test')).tap();
      await pumpFrames($, count: 10);

      // ── Phase 3: Instructions screen ──
      expect($('RAMP'), findsOneWidget);
      expect($('HOW IT WORKS'), findsOneWidget);

      // Tap "I'm Ready — Start"
      await $(find.textContaining("I'm Ready")).tap();
      await pumpFrames($, count: 20);

      // ── Phase 4: Warmup ──
      // Wait for HUD to show warmup header
      var warmupVisible = false;
      for (var i = 0; i < 20; i++) {
        await pumpFrames($, count: 5);
        if ($('WARMUP').exists) {
          warmupVisible = true;
          break;
        }
      }
      expect(warmupVisible, isTrue, reason: 'WARMUP header not visible');
      expect($(find.textContaining('Skip Warmup')), findsOneWidget);
      expect($(find.textContaining('Stop Test')), findsOneWidget);

      // ── Phase 5: Skip warmup ──
      await $(find.textContaining('Skip Warmup')).tap();
      await pumpFrames($, count: 20);

      // Should now be in Stage 1
      var stageVisible = false;
      for (var i = 0; i < 20; i++) {
        await pumpFrames($, count: 5);
        if ($('STAGE 1').exists) {
          stageVisible = true;
          break;
        }
      }
      expect(stageVisible, isTrue, reason: 'STAGE 1 header not visible after skipping warmup');

      // Skip warmup button should be gone
      expect($(find.textContaining('Skip Warmup')), findsNothing);

      // ── Phase 6: Verify HUD data ──
      // Wait a few seconds for data to flow
      await pumpFrames($, count: 30, interval: const Duration(milliseconds: 300));

      expect($('WATTS'), findsOneWidget);
      expect($('TARGET'), findsOneWidget);

      // ── Phase 7: Stop test ──
      await $(find.textContaining('Stop Test')).tap();
      await pumpFrames($, count: 20);

      // ── Phase 8: Results screen ──
      var resultsVisible = false;
      for (var i = 0; i < 20; i++) {
        await pumpFrames($, count: 5);
        if ($('Your Results').exists) {
          resultsVisible = true;
          break;
        }
      }
      expect(resultsVisible, isTrue, reason: 'Results screen not shown after stopping test');
      expect($('ESTIMATED FTP'), findsOneWidget);
      expect($('TEST SUMMARY'), findsOneWidget);
      expect($('DURATION'), findsOneWidget);

      // ── Phase 9: Back to home ──
      await $(find.textContaining('Back to Home')).tap();
      await pumpFrames($, count: 20);

      // Verify we're back on the home screen
      var homeVisible = false;
      for (var i = 0; i < 10; i++) {
        await pumpFrames($, count: 5);
        if ($('SELECT PROTOCOL').exists) {
          homeVisible = true;
          break;
        }
      }
      expect(homeVisible, isTrue, reason: 'Home screen not shown after tapping Back to Home');

      // Trainer should still show as connected
      expect($('CONNECTED'), findsOneWidget);
    },
  );
}
