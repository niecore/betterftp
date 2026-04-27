import '../ftp_calculator.dart';
import '../ramp_test_state.dart';
import '../test_phase.dart';
import '../test_protocol_definition.dart';

/// Ramp test: power increases by [_increment] watts every [_stageDuration]
/// seconds until exhaustion. FTP = best 1-min average × 0.75.
class RampProtocol extends TestProtocolDefinition {
  static const _startPower = 100;
  static const _increment = 20;
  static const _stageDuration = 60;
  static const _displayStages = 15;

  static const _rampingPhase = TestPhase(
    id: 'ramping',
    displayName: 'Ramping',
    isTestPhase: true,
    allowsManualPower: false,
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
        'FTP = 75% of your best minute. Cool down 5 min easy.',
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
  int get warmupDurationSeconds => 600;

  @override
  int get warmupPower => 100;

  // ── Test phase ────────────────────────────────────────────────────

  @override
  TestPhase get initialTestPhase => _rampingPhase;

  @override
  int get initialTestPower => _startPower;

  @override
  int get stageDurationSeconds => _stageDuration;

  @override
  int get totalStages => _displayStages;

  // ── Tick logic ────────────────────────────────────────────────────

  @override
  TestTickResult onTick(TestRunState state) {
    final stageElapsed = state.stageElapsedSeconds + 1;
    if (stageElapsed >= _stageDuration) {
      final newStage = state.currentStage + 1;
      final newPower = _startPower + (newStage * _increment);
      return TestTickResult(
        newStageIndex: newStage,
        newTargetPower: newPower,
      );
    }
    // No mutations — controller will increment stageElapsedSeconds.
    return const TestTickResult();
  }

  // ── FTP calculation ───────────────────────────────────────────────

  @override
  int calculateFtp(Map<String, List<PowerReading>> readingsByPhase) {
    final readings = readingsByPhase['ramping'] ?? [];
    final best = FtpCalculator.bestOneMinuteAverage(readings);
    return (best * 0.75).round();
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  String headerText(TestRunState state) {
    if (state.currentPhase.isWarmup) return 'Warmup';
    return 'Stage ${state.currentStage + 1}';
  }

  @override
  List<ResultMetric> resultMetrics(TestRunState state) {
    return [
      ResultMetric(
          'Best 1-min Avg', '${state.bestOneMinAvgPower.round()} W'),
      ResultMetric('Stages Completed', '${state.currentStage + 1}'),
    ];
  }
}
