import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bluetooth/data/hr_repository.dart';
import '../../bluetooth/data/trainer_repository.dart';
import '../../bluetooth/domain/trainer.dart';
import '../domain/ftp_calculator.dart';
import '../domain/protocol_registry.dart';
import '../domain/ramp_test_state.dart';
import '../domain/test_phase.dart';
import '../domain/test_protocol_definition.dart';

/// Generic FSM dispatcher for the workout session.
///
/// All protocol-specific policy (phase sequence, transition rules) lives
/// in [TestProtocolDefinition]. This controller is responsible only for:
///   - ticking the FSM clock,
///   - driving timer-expiry and stage transitions,
///   - applying [UserAction]s to the FSM,
///   - managing BLE/HR subscriptions across recording boundaries,
///   - sending ERG target power on phase entry,
///   - computing FTP at the test → non-test boundary,
///   - cleaning up at the terminal phase.
class RampTestController extends Notifier<TestRunState> {
  late TestProtocolDefinition _protocol;

  Timer? _timer;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _hrSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _dataStaleSubscription;
  int? _latestHr;

  TrainerRepository get _trainerRepository =>
      ref.read(trainerRepositoryProvider);
  HrRepository get _hrRepository => ref.read(hrRepositoryProvider);

  @override
  TestRunState build() => const TestRunState();

  // ── Public API ────────────────────────────────────────────────────

  void start([TestProtocol protocol = TestProtocol.ramp]) {
    if (state.lifecycle != TestLifecycle.idle) return;

    _protocol = ProtocolRegistry.get(protocol);

    state = const TestRunState().copyWith(
      lifecycle: TestLifecycle.running,
      protocol: protocol,
    );

    _transitionTo(_protocol.initialPhase);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Apply a user-driven input to the FSM. Ignored if the protocol's
  /// transition table doesn't define a target for the current phase.
  void onUserAction(UserAction action) {
    if (state.lifecycle != TestLifecycle.running) return;
    final next = _protocol.nextPhaseOnUserAction(
      state.currentPhase,
      action,
      state,
    );
    if (next != null) _transitionTo(next);
  }

  void adjustPower(int delta) {
    if (!state.currentPhase.allowsManualPower) return;
    final newPower = (state.targetPower + delta).clamp(50, 500);
    state = state.copyWith(targetPower: newPower);
    _sendTargetPower(newPower);
  }

  // ── FSM tick ──────────────────────────────────────────────────────

  void _tick() {
    if (state.lifecycle != TestLifecycle.running) return;
    final phase = state.currentPhase;
    if (phase.isPaused || phase.isTerminal) return;

    final newElapsed = state.elapsedSeconds + 1;
    final newStageElapsed = state.stageElapsedSeconds + 1;

    // Stage-internal transitions (e.g. ramp's 20W-per-minute bumps).
    final stageResult = _protocol.onStageTick(state);
    if (stageResult != null) {
      state = state.copyWith(
        elapsedSeconds: newElapsed,
        stageElapsedSeconds: 0,
        currentStage: stageResult.newStageIndex ?? state.currentStage,
        targetPower: stageResult.newTargetPower ?? state.targetPower,
      );
      if (stageResult.newTargetPower != null) {
        _sendTargetPower(stageResult.newTargetPower!);
      }
      return;
    }

    // Timer-driven phase transition.
    final dur = phase.durationSeconds;
    if (dur != null && newStageElapsed >= dur) {
      // Bump elapsed first so the transition shows the full phase
      // duration in the workout clock.
      state = state.copyWith(elapsedSeconds: newElapsed);
      _transitionTo(_protocol.nextPhaseOnTimerExpiry(phase, state));
      return;
    }

    state = state.copyWith(
      elapsedSeconds: newElapsed,
      stageElapsedSeconds: newStageElapsed,
    );
  }

  // ── Phase transitions ─────────────────────────────────────────────

  void _transitionTo(TestPhase next) {
    final old = state.currentPhase;

    // FTP at the test → non-test boundary. Idempotent: only computes
    // the first time we leave a test phase.
    if (old.isTestPhase && !next.isTestPhase && state.calculatedFtp == null) {
      final ftp = _protocol.calculateFtp(state.readingsByPhase);
      state = state.copyWith(calculatedFtp: ftp);
    }

    // Subscription lifecycle.
    if (old.isRecording && !next.isRecording) _unsubscribeSensors();
    if (!old.isRecording && next.isRecording) _subscribeSensors();

    // Reset stage counters and seed the new phase's target power.
    state = state.copyWith(
      currentPhase: next,
      stageElapsedSeconds: 0,
      currentStage: 0,
      targetPower: next.targetPower ?? state.targetPower,
      trainerDisconnected: false,
      dataStale: false,
    );

    if (next.targetPower != null) _sendTargetPower(next.targetPower!);

    if (next.isTerminal) {
      _cleanup();
      state = state.copyWith(lifecycle: TestLifecycle.completed);
    }
  }

  // ── Subscription helpers ─────────────────────────────────────────

  void _subscribeSensors() {
    _hrSubscription ??= _hrRepository.hrDataStream.listen((hrData) {
      _latestHr = hrData.heartRate;
    });

    _dataSubscription ??= _trainerRepository.trainerDataStream.listen((data) {
      if (state.lifecycle != TestLifecycle.running) return;
      if (!state.currentPhase.isRecording) return;

      final reading = PowerReading(
        timestamp: data.timestamp,
        power: data.power,
        heartRate: _latestHr,
      );

      final phaseId = state.currentPhase.id;
      final updatedPhaseList = <PowerReading>[
        ...state.readingsByPhase[phaseId] ?? const [],
        reading,
      ];
      final updatedMap = <String, List<PowerReading>>{
        ...state.readingsByPhase,
        phaseId: updatedPhaseList,
      };

      // Best 1-min avg over all test-phase readings (for live HUD display).
      final testReadings = updatedMap.entries
          .where((e) => _isTestPhaseId(e.key))
          .expand<PowerReading>((e) => e.value)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final bestAvg = FtpCalculator.bestOneMinuteAverage(testReadings);

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
        readingsByPhase: updatedMap,
        bestOneMinAvgPower: bestAvg,
        currentHeartRate: currentHr,
        maxHeartRate: maxHr,
      );
    });

    _connectionSubscription ??=
        _trainerRepository.connectionStateStream.listen((connState) {
      if (state.lifecycle != TestLifecycle.running) return;
      final disconnected = connState == TrainerConnectionState.disconnected;
      if (state.trainerDisconnected != disconnected) {
        state = state.copyWith(trainerDisconnected: disconnected);
      }
    });

    _dataStaleSubscription ??=
        _trainerRepository.dataStaleStream.listen((isStale) {
      if (state.lifecycle != TestLifecycle.running) return;
      if (state.dataStale != isStale) {
        state = state.copyWith(dataStale: isStale);
      }
    });
  }

  void _unsubscribeSensors() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _hrSubscription?.cancel();
    _hrSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _dataStaleSubscription?.cancel();
    _dataStaleSubscription = null;
  }

  void _cleanup() {
    _timer?.cancel();
    _timer = null;
    _unsubscribeSensors();
  }

  bool _isTestPhaseId(String phaseId) {
    // The protocol's initial *test* phase is identified via the
    // [TestPhase.isTestPhase] flag, but we don't have a direct lookup
    // by id on the protocol. The state's currentPhase is the safest
    // source of truth — but here we need to evaluate arbitrary phase
    // ids. Cheat: check whether the id matches the current phase if
    // it's a test phase, OR fall back to the protocol's known test
    // phase ids. For both protocols those are 'ramping' / 'sustained'.
    if (state.currentPhase.id == phaseId && state.currentPhase.isTestPhase) {
      return true;
    }
    return phaseId == 'ramping' || phaseId == 'sustained';
  }

  void _sendTargetPower(int watts) {
    _trainerRepository.setTargetPower(watts).then((success) {
      if (!success && state.lifecycle == TestLifecycle.running) {
        developer.log(
          'Failed to set target power to ${watts}W',
          name: 'RampTestController',
        );
      }
    });
  }
}

final rampTestControllerProvider =
    NotifierProvider<RampTestController, TestRunState>(
  RampTestController.new,
);
