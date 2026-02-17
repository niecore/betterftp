import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bluetooth/data/hr_repository.dart';
import '../../bluetooth/data/trainer_repository.dart';
import '../domain/ftp_calculator.dart';
import '../domain/ramp_test_config.dart';
import '../domain/ramp_test_state.dart';

class RampTestController extends Notifier<RampTestState> {
  final RampTestConfig _config;

  Timer? _timer;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _hrSubscription;
  int? _latestHr;

  RampTestController([this._config = const RampTestConfig()]);

  TrainerRepository get _trainerRepository =>
      ref.read(trainerRepositoryProvider);
  HrRepository get _hrRepository => ref.read(hrRepositoryProvider);

  @override
  RampTestState build() => const RampTestState();

  void start() {
    if (state.phase != RampTestPhase.idle) return;

    // Start warmup phase
    state = state.copyWith(
      phase: RampTestPhase.warmup,
      targetPower: _config.warmupPower,
      elapsedSeconds: 0,
      stageElapsedSeconds: 0,
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
        // Transition to ramping
        final targetPower = _config.startPower;
        _trainerRepository.setTargetPower(targetPower);
        state = state.copyWith(
          phase: RampTestPhase.ramping,
          elapsedSeconds: newElapsed,
          stageElapsedSeconds: 0,
          currentStage: 0,
          targetPower: targetPower,
        );
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
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _hrSubscription?.cancel();
    _hrSubscription = null;

    final ftp = FtpCalculator.calculateFtp(state.powerReadings);

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
