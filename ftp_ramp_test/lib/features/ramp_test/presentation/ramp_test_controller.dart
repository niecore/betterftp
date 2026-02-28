import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bluetooth/data/hr_repository.dart';
import '../../bluetooth/data/trainer_repository.dart';
import '../domain/ftp_calculator.dart';
import '../domain/ramp_test_config.dart';
import '../domain/ramp_test_state.dart';

class RampTestController extends Notifier<RampTestState> {
  RampTestConfig _config = const RampTestConfig();

  Timer? _timer;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _hrSubscription;
  int? _latestHr;

  TrainerRepository get _trainerRepository =>
      ref.read(trainerRepositoryProvider);
  HrRepository get _hrRepository => ref.read(hrRepositoryProvider);

  @override
  RampTestState build() => const RampTestState();

  void start([TestProtocol protocol = TestProtocol.ramp]) {
    if (state.phase != RampTestPhase.idle) return;

    _config = RampTestConfig.forProtocol(protocol);

    // Start warmup phase
    state = state.copyWith(
      phase: RampTestPhase.warmup,
      protocol: protocol,
      targetPower: _config.warmupPower,
      elapsedSeconds: 0,
      stageElapsedSeconds: 0,
      sustainedElapsedSeconds: 0,
      warmupDuration: _config.warmupDuration,
      stageDuration: _config.stageDuration,
      testDuration: _config.testDuration,
      currentStage: 0,
      powerReadings: [],
      bestOneMinAvgPower: 0,
      calculatedFtp: null,
    );

    _trainerRepository.setTargetPower(_config.warmupPower);

    // Listen to HR data if connected
    _hrSubscription = _hrRepository.hrDataStream.listen((hrData) {
      _latestHr = hrData.heartRate;
    });

    // Listen to trainer data
    _dataSubscription = _trainerRepository.trainerDataStream.listen((data) {
      if (state.phase == RampTestPhase.idle ||
          state.phase == RampTestPhase.completed ||
          state.phase == RampTestPhase.failed) {
        return;
      }

      final reading = PowerReading(
        timestamp: data.timestamp,
        power: data.power,
        heartRate: _latestHr,
      );

      final readings = [...state.powerReadings, reading];
      final bestAvg = FtpCalculator.bestOneMinuteAverage(readings);

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
        powerReadings: readings,
        bestOneMinAvgPower: bestAvg,
        currentHeartRate: currentHr,
        maxHeartRate: maxHr,
      );
    });

    // Tick every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (state.phase == RampTestPhase.completed ||
        state.phase == RampTestPhase.failed ||
        state.phase == RampTestPhase.idle) {
      return;
    }

    final newElapsed = state.elapsedSeconds + 1;
    final newStageElapsed = state.stageElapsedSeconds + 1;

    if (state.phase == RampTestPhase.warmup) {
      if (newStageElapsed >= _config.warmupDuration) {
        // Transition based on protocol
        final targetPower = _config.startPower;
        _trainerRepository.setTargetPower(targetPower);
        if (state.protocol == TestProtocol.ramp) {
          state = state.copyWith(
            phase: RampTestPhase.ramping,
            elapsedSeconds: newElapsed,
            stageElapsedSeconds: 0,
            currentStage: 0,
            targetPower: targetPower,
          );
        } else {
          state = state.copyWith(
            phase: RampTestPhase.sustained,
            elapsedSeconds: newElapsed,
            stageElapsedSeconds: 0,
            sustainedElapsedSeconds: 0,
            targetPower: targetPower,
          );
        }
      } else {
        state = state.copyWith(
          elapsedSeconds: newElapsed,
          stageElapsedSeconds: newStageElapsed,
        );
      }
    } else if (state.phase == RampTestPhase.ramping) {
      if (newStageElapsed >= _config.stageDuration) {
        // Next stage
        final newStage = state.currentStage + 1;
        final targetPower =
            _config.startPower + (newStage * _config.increment);
        _trainerRepository.setTargetPower(targetPower);
        state = state.copyWith(
          elapsedSeconds: newElapsed,
          stageElapsedSeconds: 0,
          currentStage: newStage,
          targetPower: targetPower,
        );
      } else {
        state = state.copyWith(
          elapsedSeconds: newElapsed,
          stageElapsedSeconds: newStageElapsed,
        );
      }
    } else if (state.phase == RampTestPhase.sustained) {
      final newSustained = state.sustainedElapsedSeconds + 1;
      if (_config.testDuration > 0 && newSustained >= _config.testDuration) {
        // Auto-complete when test duration reached
        stop();
        return;
      }
      state = state.copyWith(
        elapsedSeconds: newElapsed,
        sustainedElapsedSeconds: newSustained,
      );
    }
  }

  void adjustPower(int delta) {
    if (state.phase != RampTestPhase.warmup &&
        state.phase != RampTestPhase.sustained) {
      return;
    }
    final newPower = (state.targetPower + delta).clamp(50, 500);
    state = state.copyWith(targetPower: newPower);
    _trainerRepository.setTargetPower(newPower);
  }

  void skipWarmup() {
    if (state.phase != RampTestPhase.warmup) return;
    final targetPower = _config.startPower;
    _trainerRepository.setTargetPower(targetPower);
    if (state.protocol == TestProtocol.ramp) {
      state = state.copyWith(
        phase: RampTestPhase.ramping,
        stageElapsedSeconds: 0,
        currentStage: 0,
        targetPower: targetPower,
      );
    } else {
      state = state.copyWith(
        phase: RampTestPhase.sustained,
        stageElapsedSeconds: 0,
        sustainedElapsedSeconds: 0,
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

    final ftp = FtpCalculator.calculateFtp(state.powerReadings, state.protocol);

    state = state.copyWith(
      phase: RampTestPhase.completed,
      calculatedFtp: ftp,
    );
  }
}

final rampTestControllerProvider =
    NotifierProvider<RampTestController, RampTestState>(
  RampTestController.new,
);
