import 'package:flutter/foundation.dart';

/// A phase within a test protocol (e.g. warmup, ramping, sustained).
///
/// Each protocol defines its own phases as [TestPhase] instances.
/// The controller uses these to determine behaviour without knowing
/// which protocol is running.
@immutable
class TestPhase {
  /// Stable identifier used as key in [readingsByPhase] map.
  final String id;

  /// Human-readable name shown in the HUD header.
  final String displayName;

  /// Whether power readings in this phase count toward FTP calculation.
  final bool isTestPhase;

  /// Whether the user can manually adjust target power (+/− buttons).
  final bool allowsManualPower;

  /// Whether this phase is a warmup (controls badge style + skip button).
  final bool isWarmup;

  /// Whether the user can skip this phase (advance to the next phase/stage).
  /// When true, the HUD renders a skip button below the progress bar.
  final bool isSkippable;

  const TestPhase({
    required this.id,
    required this.displayName,
    this.isTestPhase = false,
    this.allowsManualPower = false,
    this.isWarmup = false,
    this.isSkippable = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestPhase && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Mutations returned by [TestProtocolDefinition.onTick].
///
/// The controller applies these generically without knowing protocol details.
@immutable
class TestTickResult {
  /// Switch to a new phase (null = stay in current phase).
  final TestPhase? newPhase;

  /// Set a new target power on the trainer (null = no change).
  final int? newTargetPower;

  /// Update the stage index (null = no change). Used by ramp protocol.
  final int? newStageIndex;

  /// If true the test is complete and [stop()] should be called.
  final bool shouldComplete;

  const TestTickResult({
    this.newPhase,
    this.newTargetPower,
    this.newStageIndex,
    this.shouldComplete = false,
  });
}

/// A label+value pair shown in the results screen summary block.
@immutable
class ResultMetric {
  final String label;
  final String value;

  const ResultMetric(this.label, this.value);
}
