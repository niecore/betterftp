import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/ftp_result_block.dart';
import '../../../shared/widgets/page_max_width.dart';
import '../../../shared/widgets/hud_interval_section.dart';
import '../../../shared/widgets/hud_power_section.dart';
import '../../../shared/widgets/hud_stepped_progress.dart';
import '../../../shared/widgets/hud_summary_pills.dart';
import '../../../shared/widgets/hud_vitals_row.dart';
import '../../../shared/widgets/live_badge.dart';
import '../../../shared/widgets/test_control_box.dart';
import '../domain/protocol_registry.dart';
import '../domain/ramp_test_state.dart';
import '../domain/test_phase.dart';
import 'ramp_test_controller.dart';

/// Active-workout screen — renders any *recording* phase of the FSM
/// (warmup, ramping/sustained, cooldown). Title, badge, HUD content,
/// and buttons all switch off `state.currentPhase.id`. Paused/terminal
/// phases (results, done) live on their own screens; this one routes
/// to them via the phase-change listener.
class WorkoutScreen extends ConsumerStatefulWidget {
  final bool autoStart;
  final TestProtocol protocol;

  const WorkoutScreen({
    super.key,
    this.autoStart = false,
    this.protocol = TestProtocol.ramp,
  });

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(rampTestControllerProvider);
      // Only reset+autoStart on a fresh entry. If we land here mid-FSM
      // (e.g. cooldown phase navigated from /results), preserve all
      // accumulated readings — invalidating would wipe the FIT export.
      if (state.lifecycle == TestLifecycle.idle ||
          state.lifecycle == TestLifecycle.completed) {
        ref.invalidate(rampTestControllerProvider);
        if (widget.autoStart) {
          WakelockPlus.enable();
          ref.read(rampTestControllerProvider.notifier).start(widget.protocol);
        }
      } else {
        WakelockPlus.enable();
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final clamped = totalSeconds.clamp(0, 99999);
    final minutes = clamped ~/ 60;
    final seconds = clamped % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Compute average power across all power readings.
  int _avgPower(TestRunState state) {
    final all = state.allReadings;
    if (all.isEmpty) return 0;
    final sum = all.fold<int>(0, (s, r) => s + r.power);
    return (sum / all.length).round();
  }

  void _confirmFinishTest(RampTestController controller) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenSide,
          AppSpacing.xxl,
          AppSpacing.screenSide,
          40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'FINISH TEST?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                    letterSpacing: 1,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.dark, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '✕',
                      style: TextStyle(fontSize: 16, color: AppColors.dark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'I am done.',
              variant: AppButtonVariant.pink,
              prefixIcon: '■',
              onPressed: () {
                Navigator.pop(ctx);
                controller.onUserAction(UserAction.endEffort);
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Keep Going',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rampTestControllerProvider);
    final controller = ref.read(rampTestControllerProvider.notifier);
    final protocol = ProtocolRegistry.get(state.protocol);

    // Phase-driven navigation: leave for the screen that owns the new
    // phase. Cooldown stays right here.
    ref.listen(rampTestControllerProvider, (previous, next) {
      if (previous?.currentPhase.id == next.currentPhase.id) return;
      switch (next.currentPhase.id) {
        case 'results':
          context.go('/results');
          break;
        case 'done':
          WakelockPlus.disable();
          context.go('/');
          break;
      }
    });

    final isRunning = state.lifecycle == TestLifecycle.running;
    final phase = state.currentPhase;
    final isWarmup = phase.id == 'warmup';
    final isCooldown = phase.id == 'cooldown';
    // On small phones (iPhone SE + iPhone mini line) we tighten
    // paddings and font sizes throughout the HUD. The pills row is
    // only dropped when the manual power control box is also visible
    // — the two together don't fit, but either alone does.
    final isCompact = context.isCompactHeight;
    final isTablet = context.isTablet;
    final showsControlBox = isRunning && phase.allowsManualPower;
    // Pills are passive info (averages, also shown on the result screen);
    // the control box is the actionable element. When forced to choose,
    // keep the controls and drop the pills. Cooldown skips them entirely
    // — averages aren't meaningful post-effort.
    final showPills =
        isRunning && !isCooldown && !(isCompact && showsControlBox);
    // Per-stage progress only makes sense for the test phase ladder.
    final showProgressFooter = isRunning && !isCooldown;

    // Top-bar title flips for cooldown so the user knows where they are.
    final title = isCooldown ? 'Cooldown' : '${protocol.label} Test';

    // Interval timing — for stepped phases (ramp's `ramping`) the
    // protocol returns the per-stage duration; otherwise the phase
    // duration. `stageElapsedSeconds` resets on phase change AND on
    // stage advance, so the bar fills correctly in both cases.
    final intervalDone = state.stageElapsedSeconds;
    final intervalTotal = protocol.currentIntervalDurationSeconds(state);
    final intervalLeft = (intervalTotal - intervalDone).clamp(0, 99999);

    // Current stage (1-based for display)
    final displayStage = isWarmup ? 0 : state.currentStage + 1;

    // Summary values
    final avgPower = _avgPower(state);
    final avgHr = state.averageHeartRate;
    final maxHr = state.maxHeartRate;

    return PopScope(
      // Block back-gesture only during cooldown so an accidental swipe
      // doesn't wipe the recording. Skip cleanly via the FSM.
      canPop: !isCooldown,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        controller.onUserAction(UserAction.skip);
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: PageMaxWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenSide,
              AppSpacing.lg,
              AppSpacing.screenSide,
              AppSpacing.screenBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Top spacer — only on tablets while running. Combined
              // with the Spacer above the buttons it pulls the title
              // row + HUD group toward the vertical center of the
              // canvas, instead of leaving it pinned to the top with
              // a yawning gap below. Phones keep the title at the top
              // so the layout stays compact.
              if (isRunning && isTablet) const Spacer(),

              // ── Top bar: title + Live badge ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (isRunning)
                    LiveBadge(isWarmup: isWarmup, isCooldown: isCooldown),
                ],
              ),
              SizedBox(height: isCompact ? 8 : 14),

              // ── FTP result preview (cooldown only) ──
              // FTP is calculated at the test→cooldown boundary, so we
              // can give the rider instant gratification while they
              // spin down. Full stats wait for the results screen.
              if (isCooldown && state.calculatedFtp != null) ...[
                FtpResultBlock(
                  ftp: state.calculatedFtp!,
                  size: FtpResultBlockSize.compact,
                ),
                const SizedBox(height: 10),
              ],

              // ── Unified HUD Block ──
              if (isRunning)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.dark, width: 3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Teal header: phase name ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          color: AppColors.teal,
                          child: Text(
                            protocol.headerText(state).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // ── Interval section ──
                        HudIntervalSection(
                          elapsedSeconds: intervalDone,
                          remainingSeconds: intervalLeft,
                          totalDuration: intervalTotal,
                        ),

                        // ── Power zone ──
                        HudPowerSection(
                          currentPower: state.currentPower,
                          targetPower: state.targetPower,
                        ),

                        // ── HR + Cadence row ──
                        HudVitalsRow(
                          heartRate: state.currentHeartRate,
                          cadence: state.currentCadence,
                        ),

                        // ── Progress footer (test phases only) ──
                        if (showProgressFooter)
                          HudSteppedProgress(
                            totalStages: protocol.totalStages,
                            currentStage: displayStage,
                          ),
                      ],
                    ),
                  ),
                ),

              if (isRunning) const SizedBox(height: 10),

              // ── Test control box (any phase that allows manual power) ──
              if (showsControlBox) ...[
                TestControlBox(onAdjust: controller.adjustPower),
                const SizedBox(height: 10),
              ],

              // ── Summary pills ── (hidden during cooldown, and when
              // forced to share space with the control box on a small phone)
              if (showPills)
                HudSummaryPills(
                  elapsed: _formatTime(state.elapsedSeconds),
                  avgPower: '$avgPower',
                  avgHr: avgHr != null ? '$avgHr' : '--',
                  maxHr: maxHr != null ? '$maxHr' : '--',
                  compact: isCompact,
                ),

              // ── Idle state: prompt ──
              if (state.lifecycle == TestLifecycle.idle) ...[
                const Spacer(),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'READY TO START',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        protocol.label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: AppColors.dark,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],

              if (isRunning) const Spacer(),

              // ── Buttons ──
              if (state.lifecycle == TestLifecycle.idle) ...[
                AppButton(
                  label: 'Start Test',
                  variant: AppButtonVariant.primary,
                  prefixIcon: '\u25B6',
                  onPressed: () {
                    WakelockPlus.enable();
                    controller.start(widget.protocol);
                  },
                ),
              ] else if (isRunning) ...[
                // Each running phase exposes exactly one forward action:
                //   warmup   → Start Test       (skip → ramping/sustained)
                //   test     → Finish Test      (endEffort → cooldown)
                //   cooldown → Finish Cooldown  (skip → results)
                AppButton(
                  label: isWarmup
                      ? 'Skip warmup'
                      : isCooldown
                          ? 'Skip Cooldown'
                          : 'Finish Test',
                  variant: isWarmup
                      ? AppButtonVariant.primary
                      : AppButtonVariant.pink,
                  prefixIcon: isWarmup ? '\u25B6' : '\u25A0',
                  onPressed: () {
                    if (isWarmup || isCooldown) {
                      controller.onUserAction(UserAction.skip);
                    } else {
                      _confirmFinishTest(controller);
                    }
                  },
                ),
              ],
            ],
          ),
          ),
        ),
      ),
      ),
    );
  }
}
