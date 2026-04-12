import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bluetooth/data/hr_repository.dart';
import '../../bluetooth/data/trainer_repository.dart';
import '../domain/ftp_calculator.dart';
import '../domain/protocol_registry.dart';
import '../domain/ramp_test_state.dart';
import '../domain/test_protocol_definition.dart';

class RampTestController extends Notifier<TestRunState> {
  late TestProtocolDefinition _protocol;

  Timer? _timer;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _hrSubscription;
  int? _latestHr;

  TrainerRepository get _trainerRepository =>
      ref.read(trainerRepositoryProvider);
  HrRepository get _hrRepository => ref.read(hrRepositoryProvider);

  @override
  TestRunState build() => const TestRunState();

  void start([TestProtocol protocol = TestProtocol.ramp]) {
    if (state.lifecycle != TestLifecycle.idle) return;

    _protocol = ProtocolRegistry.get(protocol);

    state = state.copyWith(
      lifecycle: TestLifecycle.running,
      protocol: protocol,
      currentPhase: _protocol.warmupPhase,
      targetPower: _protocol.warmupPower,
      elapsedSeconds: 0,
      warmupElapsedSeconds: 0,
      stageElapsedSeconds: 0,
      currentStage: 0,
      warmupDuration: _protocol.warmupDurationSeconds,
      readingsByPhase: {},
      bestOneMinAvgPower: 0,
      calculatedFtp: null,
    );

    _trainerRepository.setTargetPower(_protocol.warmupPower);

    // Listen to HR data if connected
    _hrSubscription = _hrRepository.hrDataStream.listen((hrData) {
      _latestHr = hrData.heartRate;
    });

    // Listen to trainer data — append to current phase's reading list
    _dataSubscription = _trainerRepository.trainerDataStream.listen((data) {
      if (state.lifecycle != TestLifecycle.running) return;

      final reading = PowerReading(
        timestamp: data.timestamp,
        power: data.power,
        heartRate: _latestHr,
      );

      // Append reading to the current phase's list
      final phaseId = state.currentPhase.id;
      final updatedPhaseList = <PowerReading>[
        ...state.readingsByPhase[phaseId] ?? [],
        reading,
      ];
      final updatedMap = <String, List<PowerReading>>{
        ...state.readingsByPhase,
        phaseId: updatedPhaseList,
      };

      // Compute best 1-min average on test-phase readings only
      final testReadings = updatedMap.entries
          .where((e) => _isTestPhaseId(e.key))
          .expand<PowerReading>((e) => e.value)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final bestAvg = FtpCalculator.bestOneMinuteAverage(testReadings);

      final currentHr = _latestHr;
      final maxHr = currentHr != null
          ? (state.maxHeartRate != null
              ? (currentHr > state.maxHeartRate!
                  ? currentHr
                  : state.maxHeartRate!)
              : currentHr)
          : state.maxHeartRate;

      state = state.copyWith(
        currentPower: data.power,
        currentCadence: data.cadence,
        readingsByPhase: updatedMap,
        bestOneMinAvgPower: bestAvg,
        currentHeartRate: currentHr,
        maxHeartRate: maxHr,
      );
    });

    // Tick every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Check if a phase ID corresponds to a test phase in the current protocol.
  bool _isTestPhaseId(String phaseId) {
    if (phaseId == _protocol.initialTestPhase.id) return true;
    // Warmup is never a test phase
    return false;
  }

  void _tick() {
    if (state.lifecycle != TestLifecycle.running) return;

    final newElapsed = state.elapsedSeconds + 1;

    // ── Warmup (generic for all protocols) ──
    if (state.currentPhase.isWarmup) {
      final newWarmup = state.warmupElapsedSeconds + 1;
      if (newWarmup >= _protocol.warmupDurationSeconds) {
        // Transition to the protocol's initial test phase
        final targetPower = _protocol.initialTestPower;
        _trainerRepository.setTargetPower(targetPower);
        state = state.copyWith(
          elapsedSeconds: newElapsed,
          warmupElapsedSeconds: newWarmup,
          currentPhase: _protocol.initialTestPhase,
          stageElapsedSeconds: 0,
          currentStage: 0,
          targetPower: targetPower,
        );
      } else {
        state = state.copyWith(
          elapsedSeconds: newElapsed,
          warmupElapsedSeconds: newWarmup,
        );
      }
      return;
    }

    // ── Test phase (delegated to protocol) ──
    final result = _protocol.onTick(state);

    if (result.shouldComplete) {
      stop();
      return;
    }

    state = state.applyTickResult(result, newElapsed);

    if (result.newTargetPower != null) {
      _trainerRepository.setTargetPower(result.newTargetPower!);
    }
  }

  void adjustPower(int delta) {
    if (!state.currentPhase.allowsManualPower) return;
    final newPower = (state.targetPower + delta).clamp(50, 500);
    state = state.copyWith(targetPower: newPower);
    _trainerRepository.setTargetPower(newPower);
  }

  /// Skip the current phase if it is marked skippable.
  ///
  /// Today this advances from the warmup phase straight into the protocol's
  /// initial test phase. The controller stays generic — any phase marked
  /// [TestPhase.isSkippable] can wire up its own advance logic here later.
  void skipPhase() {
    if (!state.currentPhase.isSkippable) return;

    if (state.currentPhase.isWarmup) {
      final targetPower = _protocol.initialTestPower;
      _trainerRepository.setTargetPower(targetPower);
      state = state.copyWith(
        currentPhase: _protocol.initialTestPhase,
        stageElapsedSeconds: 0,
        currentStage: 0,
        targetPower: targetPower,
      );
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _hrSubscription?.cancel();
    _hrSubscription = null;

    final ftp = _protocol.calculateFtp(state.readingsByPhase);

    state = state.copyWith(
      lifecycle: TestLifecycle.completed,
      calculatedFtp: ftp,
    );
  }
}

final rampTestControllerProvider =
    NotifierProvider<RampTestController, TestRunState>(
  RampTestController.new,
);
