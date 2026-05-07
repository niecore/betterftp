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

/// High-level lifecycle of the workout session.
///
/// `running` covers the entire FSM run from warmup through cooldown until
/// the FSM enters its terminal phase, at which point the lifecycle becomes
/// `completed`. Phase identity (warmup vs. test vs. cooldown vs. results)
/// is tracked separately on [TestRunState.currentPhase].
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

/// Immutable state for the workout session.
@immutable
class TestRunState {
  // ── Lifecycle ─────────────────────────────────────────────────────
  final TestLifecycle lifecycle;
  final TestProtocol protocol;
  final TestPhase currentPhase;

  // ── Counters ──────────────────────────────────────────────────────

  /// Total elapsed seconds across all phases since [RampTestController.start].
  final int elapsedSeconds;

  /// Seconds elapsed within the current phase (or current stage inside
  /// a stepped phase like ramping). Reset to 0 on any phase change.
  final int stageElapsedSeconds;

  /// Stage index inside the current phase (used by ramping for the
  /// 20W-per-minute step counter). Reset to 0 on any phase change.
  final int currentStage;

  // ── ERG / sensor data ────────────────────────────────────────────
  final int targetPower;
  final int currentPower;
  final int currentCadence;
  final int? currentHeartRate;
  final int? maxHeartRate;

  // ── Connection health ────────────────────────────────────────────
  final bool trainerDisconnected;
  final bool dataStale;

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
    this.stageElapsedSeconds = 0,
    this.currentStage = 0,
    this.targetPower = 0,
    this.currentPower = 0,
    this.currentCadence = 0,
    this.currentHeartRate,
    this.maxHeartRate,
    this.trainerDisconnected = false,
    this.dataStale = false,
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
    int? stageElapsedSeconds,
    int? currentStage,
    int? targetPower,
    int? currentPower,
    int? currentCadence,
    int? currentHeartRate,
    int? maxHeartRate,
    bool? trainerDisconnected,
    bool? dataStale,
    Map<String, List<PowerReading>>? readingsByPhase,
    double? bestOneMinAvgPower,
    int? calculatedFtp,
  }) {
    return TestRunState(
      lifecycle: lifecycle ?? this.lifecycle,
      protocol: protocol ?? this.protocol,
      currentPhase: currentPhase ?? this.currentPhase,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      stageElapsedSeconds: stageElapsedSeconds ?? this.stageElapsedSeconds,
      currentStage: currentStage ?? this.currentStage,
      targetPower: targetPower ?? this.targetPower,
      currentPower: currentPower ?? this.currentPower,
      currentCadence: currentCadence ?? this.currentCadence,
      currentHeartRate: currentHeartRate ?? this.currentHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      trainerDisconnected: trainerDisconnected ?? this.trainerDisconnected,
      dataStale: dataStale ?? this.dataStale,
      readingsByPhase: readingsByPhase ?? this.readingsByPhase,
      bestOneMinAvgPower: bestOneMinAvgPower ?? this.bestOneMinAvgPower,
      calculatedFtp: calculatedFtp ?? this.calculatedFtp,
    );
  }
}
