import 'package:flutter/foundation.dart';

/// A phase within a test protocol — pure data describing the phase's
/// behaviour. The controller drives the FSM generically using these flags
/// without knowing which protocol is running.
@immutable
class TestPhase {
  /// Stable identifier used as the key in [readingsByPhase] and as the
  /// cross-protocol equality key.
  final String id;

  /// Human-readable name shown in the HUD header.
  final String displayName;

  /// Power readings collected during this phase count toward FTP.
  final bool isTestPhase;

  /// Trainer/HR streams stay subscribed and incoming readings are
  /// appended to [readingsByPhase] under this phase's [id].
  final bool isRecording;

  /// No timer ticks; the FSM waits for an explicit [UserAction]
  /// (e.g. the post-test "Results" interstitial).
  final bool isPaused;

  /// Last phase of the FSM. The controller cleans up subscriptions and
  /// the lifecycle becomes [TestLifecycle.completed] on entry.
  final bool isTerminal;

  /// User can manually adjust target power via the +/- buttons.
  final bool allowsManualPower;

  /// User can skip this phase via [UserAction.skip].
  final bool isSkippable;

  /// ERG target sent to the trainer when the phase is entered.
  /// Null leaves the previous target in place.
  final int? targetPower;

  /// Phase length in seconds. When [stageElapsedSeconds] reaches this,
  /// the controller fires [TestProtocolDefinition.nextPhaseOnTimerExpiry].
  /// Null means the phase is open-ended (e.g. ramp until user ends effort).
  final int? durationSeconds;

  const TestPhase({
    required this.id,
    required this.displayName,
    this.isTestPhase = false,
    this.isRecording = false,
    this.isPaused = false,
    this.isTerminal = false,
    this.allowsManualPower = false,
    this.isSkippable = false,
    this.targetPower,
    this.durationSeconds,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestPhase && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Stage-level mutations returned by [TestProtocolDefinition.onStageTick].
/// Used for protocols with stepped stages inside a phase (e.g. ramp's
/// 20W-per-minute bumps inside the 'ramping' phase).
@immutable
class TestTickResult {
  /// Set a new target power on the trainer (null = no change).
  final int? newTargetPower;

  /// Update the stage index (null = no change).
  final int? newStageIndex;

  const TestTickResult({
    this.newTargetPower,
    this.newStageIndex,
  });
}

/// User-driven inputs to the FSM. Each phase can choose to react (via
/// [TestProtocolDefinition.nextPhaseOnUserAction]) or ignore them.
enum UserAction {
  /// Skip a skippable phase (advance to the next one). Used for warmup
  /// and cooldown.
  skip,

  /// End the active test effort. From a test phase this advances into
  /// the cooldown phase (where FTP is already calculated); from
  /// warmup or cooldown it short-circuits to the results interstitial.
  endEffort,

  /// Finish the workout for good. Valid in the 'results' paused phase.
  finish,
}

/// A label+value pair shown in the results screen summary block.
@immutable
class ResultMetric {
  final String label;
  final String value;

  const ResultMetric(this.label, this.value);
}
