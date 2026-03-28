import 'package:flutter/foundation.dart';

import 'ftp_calculator.dart';
import 'test_phase.dart';

/// Identifies which protocol is selected (used for routing / serialisation).
enum TestProtocol {
  ramp('Ramp'),
  twentyMin('20 Min');

  final String label;
  const TestProtocol(this.label);
}

/// High-level lifecycle of the test session.
enum TestLifecycle { idle, running, completed, failed }

/// A single power data point from the trainer.
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

/// Sentinel phase used as the default before a protocol is selected.
const _idlePhase = TestPhase(id: 'idle', displayName: 'Idle');

/// Immutable state for the test session.
///
/// Protocol-specific counters live in [counters] so the state class
/// doesn't need fields for every protocol variant.
@immutable
class TestRunState {
  // ── Lifecycle ─────────────────────────────────────────────────────
  final TestLifecycle lifecycle;
  final TestProtocol protocol;
  final TestPhase currentPhase;

  // ── Universal counters ────────────────────────────────────────────
  final int elapsedSeconds;
  final int warmupElapsedSeconds;
  final int stageElapsedSeconds;
  final int currentStage;

  // ── Protocol-specific counters ────────────────────────────────────
  final Map<String, int> counters;

  // ── Config (copied from protocol at start) ────────────────────────
  final int warmupDuration;
  final int targetPower;

  // ── Sensor data ───────────────────────────────────────────────────
  final int currentPower;
  final int currentCadence;
  final int? currentHeartRate;
  final int? maxHeartRate;

  // ── Collected data ────────────────────────────────────────────────
  /// Power readings keyed by phase ID.
  final Map<String, List<PowerReading>> readingsByPhase;
  final double bestOneMinAvgPower;
  final int? calculatedFtp;

  const TestRunState({
    this.lifecycle = TestLifecycle.idle,
    this.protocol = TestProtocol.ramp,
    this.currentPhase = _idlePhase,
    this.elapsedSeconds = 0,
    this.warmupElapsedSeconds = 0,
    this.stageElapsedSeconds = 0,
    this.currentStage = 0,
    this.counters = const {},
    this.warmupDuration = 300,
    this.targetPower = 0,
    this.currentPower = 0,
    this.currentCadence = 0,
    this.currentHeartRate,
    this.maxHeartRate,
    this.readingsByPhase = const {},
    this.bestOneMinAvgPower = 0,
    this.calculatedFtp,
  });

  // ── Convenience getters ───────────────────────────────────────────

  /// All readings across every phase, sorted by timestamp.
  /// Used for FIT file export (full ride).
  List<PowerReading> get allReadings {
    final all = readingsByPhase.values.expand((list) => list).toList();
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }

  /// Max power across all phases.
  int get maxPower {
    final all = allReadings;
    if (all.isEmpty) return 0;
    return all.fold<int>(0, (max, r) => r.power > max ? r.power : max);
  }

  /// Time-weighted average HR across all phases.
  int? get averageHeartRate {
    final avg = FtpCalculator.averageHeartRate(allReadings);
    return avg?.round();
  }

  // ── Copy helper ───────────────────────────────────────────────────

  TestRunState copyWith({
    TestLifecycle? lifecycle,
    TestProtocol? protocol,
    TestPhase? currentPhase,
    int? elapsedSeconds,
    int? warmupElapsedSeconds,
    int? stageElapsedSeconds,
    int? currentStage,
    Map<String, int>? counters,
    int? warmupDuration,
    int? targetPower,
    int? currentPower,
    int? currentCadence,
    int? currentHeartRate,
    int? maxHeartRate,
    Map<String, List<PowerReading>>? readingsByPhase,
    double? bestOneMinAvgPower,
    int? calculatedFtp,
  }) {
    return TestRunState(
      lifecycle: lifecycle ?? this.lifecycle,
      protocol: protocol ?? this.protocol,
      currentPhase: currentPhase ?? this.currentPhase,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      warmupElapsedSeconds: warmupElapsedSeconds ?? this.warmupElapsedSeconds,
      stageElapsedSeconds: stageElapsedSeconds ?? this.stageElapsedSeconds,
      currentStage: currentStage ?? this.currentStage,
      counters: counters ?? this.counters,
      warmupDuration: warmupDuration ?? this.warmupDuration,
      targetPower: targetPower ?? this.targetPower,
      currentPower: currentPower ?? this.currentPower,
      currentCadence: currentCadence ?? this.currentCadence,
      currentHeartRate: currentHeartRate ?? this.currentHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      readingsByPhase: readingsByPhase ?? this.readingsByPhase,
      bestOneMinAvgPower: bestOneMinAvgPower ?? this.bestOneMinAvgPower,
      calculatedFtp: calculatedFtp ?? this.calculatedFtp,
    );
  }

  /// Apply a [TestTickResult] from the protocol's onTick.
  TestRunState applyTickResult(TestTickResult result, int newElapsed) {
    return copyWith(
      elapsedSeconds: newElapsed,
      currentPhase: result.newPhase ?? currentPhase,
      targetPower: result.newTargetPower ?? targetPower,
      currentStage: result.newStageIndex ?? currentStage,
      stageElapsedSeconds:
          result.newStageIndex != null ? 0 : stageElapsedSeconds + 1,
      counters: {...counters, ...result.counters},
    );
  }
}
