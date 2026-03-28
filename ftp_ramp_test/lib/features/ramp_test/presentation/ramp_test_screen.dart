import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/hud_interval_section.dart';
import '../../../shared/widgets/hud_power_section.dart';
import '../../../shared/widgets/hud_stepped_progress.dart';
import '../../../shared/widgets/hud_summary_pills.dart';
import '../../../shared/widgets/hud_vitals_row.dart';
import '../../../shared/widgets/live_badge.dart';
import '../domain/protocol_registry.dart';
import '../domain/protocols/twenty_min_protocol.dart';
import '../domain/ramp_test_state.dart';
import '../domain/test_phase.dart';
import 'ramp_test_controller.dart';

class RampTestScreen extends ConsumerStatefulWidget {
  final bool autoStart;
  final TestProtocol protocol;

  const RampTestScreen({
    super.key,
    this.autoStart = false,
    this.protocol = TestProtocol.ramp,
  });

  @override
  ConsumerState<RampTestScreen> createState() => _RampTestScreenState();
}

class _RampTestScreenState extends ConsumerState<RampTestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Reset state so a fresh test can start
      ref.invalidate(rampTestControllerProvider);
      if (widget.autoStart) {
        WakelockPlus.enable();
        ref.read(rampTestControllerProvider.notifier).start(widget.protocol);
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

  /// Compute efficiency: avg power / target power as percentage.
  String _efficiency(TestRunState state) {
    if (state.targetPower <= 0) return '--';
    final avg = _avgPower(state);
    final eff = ((avg / state.targetPower) * 100).round();
    return '$eff%';
  }

  /// Estimated total stages for a ramp test (for progress display).
  int get _totalStages => 15;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rampTestControllerProvider);
    final controller = ref.read(rampTestControllerProvider.notifier);
    final protocol = ProtocolRegistry.get(widget.protocol);

    ref.listen(rampTestControllerProvider, (previous, next) {
      if (next.lifecycle == TestLifecycle.completed &&
          previous?.lifecycle != TestLifecycle.completed) {
        context.go('/results', extra: next);
      }
    });

    final isRunning = state.lifecycle == TestLifecycle.running;
    final isWarmup = state.currentPhase.isWarmup;
    final progressType = protocol.progressWidgetType(state.currentPhase);

    // Interval timing (warmup + ramp stages)
    final intervalDone =
        isWarmup ? state.warmupElapsedSeconds : state.stageElapsedSeconds;
    final intervalTotal =
        isWarmup ? state.warmupDuration : 60; // stage duration for ramp
    final intervalLeft = (intervalTotal - intervalDone).clamp(0, 99999);

    // Sustained mode timing
    final sustainedDone = state.counters['sustainedElapsed'] ?? 0;
    final sustainedTotal =
        protocol is TwentyMinProtocol ? protocol.testDuration : 0;
    final sustainedLeft =
        sustainedTotal > 0 ? (sustainedTotal - sustainedDone).clamp(0, 99999) : 0;

    // Current stage (1-based for display)
    final displayStage = isWarmup ? 0 : state.currentStage + 1;

    // Summary values
    final avgPower = _avgPower(state);
    final avgHr = state.averageHeartRate;
    final maxHr = state.maxHeartRate;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
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
              // ── Top bar: title + Live badge ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${protocol.label} Test',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (isRunning) LiveBadge(isWarmup: isWarmup),
                ],
              ),
              const SizedBox(height: 14),

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
                            vertical: 10,
                            horizontal: 16,
                          ),
                          color: AppColors.teal,
                          child: Text(
                            protocol.headerText(state).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // ── Interval section ──
                        HudIntervalSection(
                          elapsedSeconds: progressType == ProgressWidgetType.linear
                              ? sustainedDone
                              : intervalDone,
                          remainingSeconds: progressType == ProgressWidgetType.linear
                              ? sustainedLeft
                              : intervalLeft,
                          totalDuration: progressType == ProgressWidgetType.linear
                              ? sustainedTotal
                              : intervalTotal,
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

                        // ── Progress footer (protocol-driven) ──
                        if (progressType == ProgressWidgetType.stepped)
                          HudSteppedProgress(
                            totalStages: _totalStages,
                            currentStage: displayStage,
                          ),

                        if (progressType == ProgressWidgetType.linear &&
                            !isWarmup &&
                            sustainedTotal > 0)
                          _SustainedProgressFooter(
                            elapsed: sustainedDone,
                            total: sustainedTotal,
                          ),
                      ],
                    ),
                  ),
                ),

              if (isRunning) const SizedBox(height: 10),

              // ── Warmup skip bar ──
              if (isWarmup) ...[
                _WarmupSkipBar(
                  targetPower: state.targetPower,
                  onAdjust: controller.adjustPower,
                  onSkip: controller.skipWarmup,
                ),
                const SizedBox(height: 10),
              ],

              // ── Summary pills ──
              if (isRunning)
                HudSummaryPills(
                  elapsed: _formatTime(state.elapsedSeconds),
                  avgPower: '$avgPower',
                  avgHr: avgHr != null ? '$avgHr' : '--',
                  maxHr: maxHr != null ? '$maxHr' : '--',
                  efficiency: _efficiency(state),
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
                AppButton(
                  label: 'Stop Test',
                  variant: AppButtonVariant.pink,
                  prefixIcon: '\u25A0',
                  onPressed: () {
                    WakelockPlus.disable();
                    controller.stop();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact warmup skip bar with -/+ power and skip button.
class _WarmupSkipBar extends StatelessWidget {
  final int targetPower;
  final void Function(int delta) onAdjust;
  final VoidCallback onSkip;

  const _WarmupSkipBar({
    required this.targetPower,
    required this.onAdjust,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.dark, width: 3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // - button
              GestureDetector(
                onTap: () => onAdjust(-10),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.dark, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '\u2212',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Iosevka'),
                  children: [
                    TextSpan(
                      text: '$targetPower',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark,
                      ),
                    ),
                    const TextSpan(
                      text: ' W',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // + button
              GestureDetector(
                onTap: () => onAdjust(10),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.dark, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '+',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: onSkip,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.dark,
                border: Border.all(color: AppColors.dark, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'SKIP \u203A\u203A',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sustained mode progress footer (continuous bar inside HUD).
class _SustainedProgressFooter extends StatelessWidget {
  final int elapsed;
  final int total;

  const _SustainedProgressFooter({
    required this.elapsed,
    required this.total,
  });

  String _fmtShort(int s) {
    final clamped = s.clamp(0, 99999);
    final m = clamped ~/ 60;
    final sec = clamped % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (total - elapsed).clamp(0, total);
    final fraction = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderLight, width: 2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TEST PROGRESS',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.muted,
                ),
              ),
              Text(
                '${_fmtShort(remaining)} left',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor: AppColors.borderLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}
