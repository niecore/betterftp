import 'package:flutter/foundation.dart';

enum RampTestPhase { idle, warmup, ramping, completed, failed }

@immutable
class PowerReading {
  final DateTime timestamp;
  final int power;
  final int? heartRate;

  const PowerReading({
    required this.timestamp,
    required this.power,
    this.heartRate,
  });
}

@immutable
class RampTestState {
  final RampTestPhase phase;
  final int currentStage; // 0-based stage index during ramping
  final int targetPower; // Current target watts
  final int elapsedSeconds; // Total elapsed time
  final int stageElapsedSeconds; // Time within current stage/warmup
  final List<PowerReading> powerReadings;
  final double bestOneMinAvgPower;
  final int? calculatedFtp;
  final int currentPower; // Latest power reading
  final int currentCadence; // Latest cadence reading
  final int? currentHeartRate; // Latest HR reading (null if no HR monitor)
  final int? maxHeartRate; // Max HR during test (null if no HR monitor)

  const RampTestState({
    this.phase = RampTestPhase.idle,
    this.currentStage = 0,
    this.targetPower = 0,
    this.elapsedSeconds = 0,
    this.stageElapsedSeconds = 0,
    this.powerReadings = const [],
    this.bestOneMinAvgPower = 0,
    this.calculatedFtp,
    this.currentPower = 0,
    this.currentCadence = 0,
    this.currentHeartRate,
    this.maxHeartRate,
  });

  RampTestState copyWith({
    RampTestPhase? phase,
    int? currentStage,
    int? targetPower,
    int? elapsedSeconds,
    int? stageElapsedSeconds,
    List<PowerReading>? powerReadings,
    double? bestOneMinAvgPower,
    int? calculatedFtp,
    int? currentPower,
    int? currentCadence,
    int? currentHeartRate,
    int? maxHeartRate,
  }) {
    return RampTestState(
      phase: phase ?? this.phase,
      currentStage: currentStage ?? this.currentStage,
      targetPower: targetPower ?? this.targetPower,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      stageElapsedSeconds: stageElapsedSeconds ?? this.stageElapsedSeconds,
      powerReadings: powerReadings ?? this.powerReadings,
      bestOneMinAvgPower: bestOneMinAvgPower ?? this.bestOneMinAvgPower,
      calculatedFtp: calculatedFtp ?? this.calculatedFtp,
      currentPower: currentPower ?? this.currentPower,
      currentCadence: currentCadence ?? this.currentCadence,
      currentHeartRate: currentHeartRate ?? this.currentHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
    );
  }
}
