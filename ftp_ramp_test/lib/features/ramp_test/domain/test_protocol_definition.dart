import 'ramp_test_state.dart';
import 'test_phase.dart';

/// Contract that every test protocol must implement.
///
/// The controller delegates all protocol-specific logic here so it
/// never needs to branch on protocol type.
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

  // ── Warmup ────────────────────────────────────────────────────────

  /// Pre-built warmup phase shared by all protocols.
  TestPhase get warmupPhase;

  /// Duration of the warmup in seconds.
  int get warmupDurationSeconds;

  /// ERG power during warmup.
  int get warmupPower;

  // ── Test phase ────────────────────────────────────────────────────

  /// The phase the test transitions to after warmup ends.
  TestPhase get initialTestPhase;

  /// Target power when the test phase begins.
  int get initialTestPower;

  /// Duration of one stage/interval in seconds. Used by the interval
  /// countdown bar (60 for ramp stages, 1200 for a single 20-min block).
  int get stageDurationSeconds;

  /// Number of stages to render in the stepped progress footer.
  /// For open-ended ramps this is an estimated display maximum.
  int get totalStages;

  // ── Tick logic ────────────────────────────────────────────────────

  /// Called every second while the test is running (not during warmup).
  ///
  /// Returns a [TestTickResult] describing what should change.
  /// The controller applies the result without knowing protocol details.
  TestTickResult onTick(TestRunState state);

  // ── FTP calculation ───────────────────────────────────────────────

  /// Compute the estimated FTP from the collected readings.
  ///
  /// The protocol picks the phase lists it needs from the map.
  int calculateFtp(Map<String, List<PowerReading>> readingsByPhase);

  // ── UI configuration ──────────────────────────────────────────────

  /// Header text for the HUD block (e.g. "Stage 3", "20 Min").
  String headerText(TestRunState state);

  /// Extra result rows shown in the test summary block.
  ///
  /// Rows like "Max Power" and "Protocol" are always shown by the screen.
  /// This returns protocol-specific extras (e.g. "Best 1-min Avg").
  List<ResultMetric> resultMetrics(TestRunState state);
}
