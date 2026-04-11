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
        isSkippable: true,
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
