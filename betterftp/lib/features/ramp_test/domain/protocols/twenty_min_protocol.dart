import '../ftp_calculator.dart';
import '../ramp_test_state.dart';
import '../test_phase.dart';
import '../test_protocol_definition.dart';

/// 20-minute test: sustain a target power for 20 minutes.
/// FTP = average power over the full window × 0.95.
///
/// Phase sequence:
///   warmup → sustained → results → [cooldown → results] → done
class TwentyMinProtocol extends TestProtocolDefinition {
  static const _testDurationSeconds = 1200;
  static const _startPower = 150;
  static const _resultsStandbyPower = 50;

  // ── Phases ────────────────────────────────────────────────────────

  static const _warmup = TestPhase(
    id: 'warmup',
    displayName: 'Warmup',
    isRecording: true,
    isSkippable: true,
    allowsManualPower: true,
    targetPower: 100,
    durationSeconds: 900,
  );

  static const _sustained = TestPhase(
    id: 'sustained',
    displayName: '20 Min',
    isTestPhase: true,
    isRecording: true,
    allowsManualPower: true,
    targetPower: _startPower,
    durationSeconds: _testDurationSeconds,
  );

  static const _results = TestPhase(
    id: 'results',
    displayName: 'Results',
    isPaused: true,
    targetPower: _resultsStandbyPower,
  );

  static const _cooldown = TestPhase(
    id: 'cooldown',
    displayName: 'Cooldown',
    isRecording: true,
    isSkippable: true,
    allowsManualPower: true,
    targetPower: 100,
    durationSeconds: 600,
  );

  static const _done = TestPhase(
    id: 'done',
    displayName: 'Done',
    isTerminal: true,
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
        'Test ends at 20:00. FTP = 95% of your average. Cool down 10 min easy.',
      ];

  // ── FSM ───────────────────────────────────────────────────────────

  @override
  TestPhase get initialPhase => _warmup;

  @override
  TestPhase nextPhaseOnTimerExpiry(TestPhase current, TestRunState state) {
    if (current.id == _warmup.id) return _sustained;
    if (current.id == _sustained.id) return _results;
    if (current.id == _cooldown.id) return _results;
    return current;
  }

  @override
  TestPhase? nextPhaseOnUserAction(
    TestPhase current,
    UserAction action,
    TestRunState state,
  ) {
    switch ((current.id, action)) {
      case ('warmup', UserAction.skip):
        return _sustained;
      case ('warmup', UserAction.endEffort):
        return _results;
      case ('sustained', UserAction.endEffort):
        return _cooldown;
      case ('results', UserAction.finish):
        return _done;
      case ('cooldown', UserAction.skip):
        return _results;
      case ('cooldown', UserAction.endEffort):
        return _results;
    }
    return null;
  }

  @override
  TestTickResult? onStageTick(TestRunState state) => null;

  // ── FTP calculation ───────────────────────────────────────────────

  @override
  int calculateFtp(Map<String, List<PowerReading>> readingsByPhase) {
    final readings = readingsByPhase[_sustained.id] ?? const [];
    final avg =
        FtpCalculator.averagePowerOverWindow(readings, _testDurationSeconds);
    return (avg * 0.95).round();
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  String headerText(TestRunState state) {
    switch (state.currentPhase.id) {
      case 'warmup':
        return 'Warmup';
      case 'cooldown':
        return 'Cooldown';
      case 'sustained':
        return '20 Min';
      case 'results':
        return 'Results';
      default:
        return state.currentPhase.displayName;
    }
  }

  @override
  List<ResultMetric> resultMetrics(TestRunState state) => const [];

  @override
  int get totalStages => 1;
}
