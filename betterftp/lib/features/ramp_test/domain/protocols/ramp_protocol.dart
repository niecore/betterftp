import '../ftp_calculator.dart';
import '../ramp_test_state.dart';
import '../test_phase.dart';
import '../test_protocol_definition.dart';

/// Ramp test: power steps up 20W every minute until the rider ends the
/// effort. FTP = best 1-min average × 0.75.
///
/// Phase sequence:
///   warmup → ramping → results → [cooldown → results] → done
class RampProtocol extends TestProtocolDefinition {
  static const _startPower = 100;
  static const _increment = 20;
  static const _stageDurationSeconds = 60;
  static const _displayStages = 15;
  static const _resultsStandbyPower = 50;

  // ── Phases ────────────────────────────────────────────────────────

  static const _warmup = TestPhase(
    id: 'warmup',
    displayName: 'Warmup',
    isRecording: true,
    isSkippable: true,
    allowsManualPower: true,
    targetPower: 100,
    durationSeconds: 600,
  );

  static const _ramping = TestPhase(
    id: 'ramping',
    displayName: 'Ramping',
    isTestPhase: true,
    isRecording: true,
    targetPower: _startPower,
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
  TestProtocol get protocolType => TestProtocol.ramp;

  @override
  String get label => 'Ramp';

  @override
  String get description => 'Incremental power every minute';

  @override
  List<String> get instructions => const [
        'Warm up 10 min. Throw in a few fast spin-ups to wake the legs.',
        'Power steps up 20W every minute. Stay seated, cadence 85–95.',
        'When the legs scream, give one more stage. That\'s where your FTP hides.',
        'FTP = 75% of your best minute. Cool down 10 min easy.',
      ];

  // ── FSM ───────────────────────────────────────────────────────────

  @override
  TestPhase get initialPhase => _warmup;

  @override
  TestPhase nextPhaseOnTimerExpiry(TestPhase current, TestRunState state) {
    if (current.id == _warmup.id) return _ramping;
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
        return _ramping;
      case ('warmup', UserAction.endEffort):
        return _results;
      case ('ramping', UserAction.endEffort):
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
  TestTickResult? onStageTick(TestRunState state) {
    if (state.currentPhase.id != _ramping.id) return null;
    if (state.stageElapsedSeconds + 1 >= _stageDurationSeconds) {
      final newStage = state.currentStage + 1;
      return TestTickResult(
        newStageIndex: newStage,
        newTargetPower: _startPower + (newStage * _increment),
      );
    }
    return null;
  }

  @override
  int currentIntervalDurationSeconds(TestRunState state) {
    if (state.currentPhase.id == _ramping.id) return _stageDurationSeconds;
    return state.currentPhase.durationSeconds ?? 0;
  }

  // ── FTP calculation ───────────────────────────────────────────────

  @override
  int calculateFtp(Map<String, List<PowerReading>> readingsByPhase) {
    final readings = readingsByPhase[_ramping.id] ?? const [];
    final best = FtpCalculator.bestOneMinuteAverage(readings);
    return (best * 0.75).round();
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  String headerText(TestRunState state) {
    switch (state.currentPhase.id) {
      case 'warmup':
        return 'Warmup';
      case 'cooldown':
        return 'Cooldown';
      case 'ramping':
        return 'Stage ${state.currentStage + 1}';
      case 'results':
        return 'Results';
      default:
        return state.currentPhase.displayName;
    }
  }

  @override
  List<ResultMetric> resultMetrics(TestRunState state) {
    return [
      ResultMetric('Best 1-min Avg', '${state.bestOneMinAvgPower.round()} W'),
      ResultMetric('Stages Completed', '${state.currentStage + 1}'),
    ];
  }

  @override
  int get totalStages => _displayStages;
}
