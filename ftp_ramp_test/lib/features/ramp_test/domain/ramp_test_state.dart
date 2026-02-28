import 'package:flutter/foundation.dart';

enum TestProtocol {
  ramp('Ramp'),
  twentyMin('20 Min'),
  eightMin('8 Min');

  final String label;
  const TestProtocol(this.label);
}

enum RampTestPhase { idle, warmup, ramping, sustained, completed, failed }

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
  final TestProtocol protocol;
  final int currentStage; // 0-based stage index during ramping
  final int targetPower; // Current target watts
  final int elapsedSeconds; // Total elapsed time
  final int stageElapsedSeconds; // Time within current stage/warmup
  final int sustainedElapsedSeconds; // Time within sustained phase
  final int warmupDuration; // Total warmup duration in seconds
  final int stageDuration; // Duration per ramp stage in seconds
  final int testDuration; // Total sustained test duration (0 = unlimited/ramp)
  final List<PowerReading> powerReadings;
  final double bestOneMinAvgPower;
  final int? calculatedFtp;
  final int currentPower; // Latest power reading
  final int currentCadence; // Latest cadence reading
  final int? currentHeartRate; // Latest HR reading (null if no HR monitor)
  final int? maxHeartRate; // Max HR during test (null if no HR monitor)

  const RampTestState({
    this.phase = RampTestPhase.idle,
    this.protocol = TestProtocol.ramp,
    this.currentStage = 0,
    this.targetPower = 0,
    this.elapsedSeconds = 0,
    this.stageElapsedSeconds = 0,
    this.sustainedElapsedSeconds = 0,
    this.warmupDuration = 300,
    this.stageDuration = 60,
    this.testDuration = 0,
    this.powerReadings = const [],
    this.bestOneMinAvgPower = 0,
    this.calculatedFtp,
    this.currentPower = 0,
    this.currentCadence = 0,
    this.currentHeartRate,
    this.maxHeartRate,
  });

  /// Max actual power recorded from the trainer.
  int get maxPower {
    if (powerReadings.isEmpty) return 0;
    return powerReadings.fold<int>(0, (max, r) => r.power > max ? r.power : max);
  }

  /// Average heart rate across all power readings that have HR data.
  int? get averageHeartRate {
    final hrReadings = powerReadings.where((r) => r.heartRate != null).toList();
    if (hrReadings.isEmpty) return null;
    final sum = hrReadings.fold<int>(0, (s, r) => s + r.heartRate!);
    return (sum / hrReadings.length).round();
  }

  RampTestState copyWith({
    RampTestPhase? phase,
    TestProtocol? protocol,
    int? currentStage,
    int? targetPower,
    int? elapsedSeconds,
    int? stageElapsedSeconds,
    int? sustainedElapsedSeconds,
    int? warmupDuration,
    int? stageDuration,
    int? testDuration,
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
      protocol: protocol ?? this.protocol,
      currentStage: currentStage ?? this.currentStage,
      targetPower: targetPower ?? this.targetPower,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      stageElapsedSeconds: stageElapsedSeconds ?? this.stageElapsedSeconds,
      sustainedElapsedSeconds:
          sustainedElapsedSeconds ?? this.sustainedElapsedSeconds,
      warmupDuration: warmupDuration ?? this.warmupDuration,
      stageDuration: stageDuration ?? this.stageDuration,
      testDuration: testDuration ?? this.testDuration,
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
