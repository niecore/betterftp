import 'ramp_test_state.dart';
import 'test_phase.dart';

/// Contract that every test protocol must implement.
///
/// The controller is a generic FSM dispatcher: it ticks timers, drives
/// transitions, and manages BLE subscriptions. All protocol-specific
/// policy — phase sequence, what user actions mean — lives here.
abstract class TestProtocolDefinition {
  // ── Identity ──────────────────────────────────────────────────────

  /// Enum value used for routing and serialisation.
  TestProtocol get protocolType;

  /// Short label shown in the UI (e.g. "Ramp", "20 Min").
  String get label;

  /// One-line description for the mode-selector.
  String get description;

  /// Step-by-step instructions shown on the pre-test briefing screen.
  List<String> get instructions;

  // ── FSM ───────────────────────────────────────────────────────────

  /// Phase the FSM enters when [RampTestController.start] is called.
  TestPhase get initialPhase;

  /// Next phase when [current]'s [TestPhase.durationSeconds] expires.
  /// Return [current] (or any phase with the same id) to stay put.
  TestPhase nextPhaseOnTimerExpiry(TestPhase current, TestRunState state);

  /// Next phase in response to a user action; null if the action is
  /// invalid in [current].
  TestPhase? nextPhaseOnUserAction(
    TestPhase current,
    UserAction action,
    TestRunState state,
  );

  /// Stage-internal tick — fired every second while in a recording,
  /// non-paused phase. Returns null if no stage change is needed.
  /// Used for protocols with stepped stages (e.g. ramp's 20W bumps).
  TestTickResult? onStageTick(TestRunState state);

  /// Duration of the current interval-bar window. For phases with a
  /// fixed [TestPhase.durationSeconds] this is just that. For stepped,
  /// open-ended phases like ramp's `ramping` it's the per-stage clock
  /// (e.g. 60 s) since `stageElapsedSeconds` resets per stage.
  int currentIntervalDurationSeconds(TestRunState state) =>
      state.currentPhase.durationSeconds ?? 0;

  // ── FTP calculation ───────────────────────────────────────────────

  /// Computed when the FSM exits the test phase. Reads the readings the
  /// protocol cares about (typically just the test phase's bucket).
  int calculateFtp(Map<String, List<PowerReading>> readingsByPhase);

  // ── UI configuration ──────────────────────────────────────────────

  /// Header text for the HUD block (e.g. "Stage 3", "20 Min", "Cooldown").
  String headerText(TestRunState state);

  /// Extra rows shown in the results-screen summary block.
  /// Generic rows like "Max Power" / "Protocol" are added by the screen.
  List<ResultMetric> resultMetrics(TestRunState state);

  /// Estimated number of stages in the test phase — used by the stepped
  /// progress footer in the HUD. Single-stage protocols return 1.
  int get totalStages;
}
