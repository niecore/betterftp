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

  // ── Warmup ────────────────────────────────────────────────────────

  @override
  TestPhase get warmupPhase => const TestPhase(
        id: 'warmup',
        displayName: 'Warmup',
        isWarmup: true,
        allowsManualPower: true,
      );

  @override
  int get warmupDurationSeconds => 300;

  @override
  int get warmupPower => 100;

  // ── Test phase ────────────────────────────────────────────────────

  @override
  TestPhase get initialTestPhase => _sustainedPhase;

  @override
  int get initialTestPower => _startPower;

  // ── Tick logic ────────────────────────────────────────────────────

  @override
  TestTickResult onTick(TestRunState state) {
    final sustained = (state.counters['sustainedElapsed'] ?? 0) + 1;
    if (sustained >= _testDuration) {
      return TestTickResult(
        shouldComplete: true,
        counters: {'sustainedElapsed': sustained},
      );
    }
    return TestTickResult(counters: {'sustainedElapsed': sustained});
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
  ProgressWidgetType progressWidgetType(TestPhase phase) {
    return ProgressWidgetType.linear;
  }

  @override
  List<ResultMetric> resultMetrics(TestRunState state) {
    return const [];
  }

  // ── Helpers accessible to UI ──────────────────────────────────────

  /// Total test duration (used by progress bar).
  int get testDuration => _testDuration;
}
