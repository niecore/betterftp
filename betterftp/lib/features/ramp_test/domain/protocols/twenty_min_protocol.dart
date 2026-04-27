import '../ftp_calculator.dart';
import '../ramp_test_state.dart';
import '../test_phase.dart';
import '../test_protocol_definition.dart';

/// 20-minute test: sustain a target power for 20 minutes.
/// FTP = average power over full 20 min (zero-filled if stopped early) × 0.95.
class TwentyMinProtocol extends TestProtocolDefinition {
  static const _testDuration = 1200; // 20 minutes in seconds
  static const _startPower = 150;

  static const _sustainedPhase = TestPhase(
    id: 'sustained',
    displayName: '20 Min',
    isTestPhase: true,
    allowsManualPower: true,
  );

  // ── Identity ──────────────────────────────────────────────────────

  @override
  TestProtocol get protocolType => TestProtocol.twentyMin;

  @override
  String get label => '20 Min';

  @override
  String get description => 'Sustain max effort for 20 min';

  @override
  List<String> get instructions => const [
        'Warm up 15 min. Throw in a few fast spin-ups to wake the legs.',
        'Pick a target you\'re sure you can hold for 20 min. Better to finish strong than blow up at minute 10.',
        'Last 5 minutes: fight to hold the pace. If anything\'s left, push harder.',
        'Stay seated, cadence 85–95.',
        'Test ends at 20:00. FTP = 95% of your average. Cool down 5 min easy.',
      ];

  // ── Warmup ────────────────────────────────────────────────────────

  @override
  TestPhase get warmupPhase => const TestPhase(
        id: 'warmup',
        displayName: 'Warmup',
        isWarmup: true,
        allowsManualPower: true,
        isSkippable: true,
      );

  @override
  int get warmupDurationSeconds => 900;

  @override
  int get warmupPower => 100;

  // ── Test phase ────────────────────────────────────────────────────

  @override
  TestPhase get initialTestPhase => _sustainedPhase;

  @override
  int get initialTestPower => _startPower;

  @override
  int get stageDurationSeconds => _testDuration;

  @override
  int get totalStages => 1;

  // ── Tick logic ────────────────────────────────────────────────────

  @override
  TestTickResult onTick(TestRunState state) {
    if (state.stageElapsedSeconds + 1 >= _testDuration) {
      return const TestTickResult(shouldComplete: true);
    }
    return const TestTickResult();
  }

  // ── FTP calculation ───────────────────────────────────────────────

  @override
  int calculateFtp(Map<String, List<PowerReading>> readingsByPhase) {
    final readings = readingsByPhase['sustained'] ?? [];
    final avg = FtpCalculator.averagePowerOverWindow(readings, _testDuration);
    return (avg * 0.95).round();
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  String headerText(TestRunState state) {
    if (state.currentPhase.isWarmup) return 'Warmup';
    return '20 Min';
  }

  @override
  List<ResultMetric> resultMetrics(TestRunState state) {
    return const [];
  }
}
