import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/phase_badge.dart';
import '../../../shared/widgets/stat_card.dart';
import '../domain/ramp_test_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rampTestControllerProvider);
    final controller = ref.read(rampTestControllerProvider.notifier);

    ref.listen(rampTestControllerProvider, (previous, next) {
      if (next.phase == RampTestPhase.completed &&
          previous?.phase != RampTestPhase.completed) {
        context.go('/results', extra: next);
      }
    });

    final isRunning = state.phase == RampTestPhase.warmup ||
        state.phase == RampTestPhase.ramping ||
        state.phase == RampTestPhase.sustained;
    final isWarmup = state.phase == RampTestPhase.warmup;
    final isRamping = state.phase == RampTestPhase.ramping;
    final isSustained = state.phase == RampTestPhase.sustained;

    // Countdown values
    final warmupRemaining =
        state.warmupDuration - state.stageElapsedSeconds;
    final stageRemaining =
        state.stageDuration - state.stageElapsedSeconds;
    final sustainedRemaining = state.testDuration > 0
        ? state.testDuration - state.sustainedElapsedSeconds
        : 0;

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
              // Title bar with phase badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Test Running',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (isRunning)
                    PhaseBadge(
                      phase: isWarmup ? Phase.warmup : Phase.testing,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Timer block
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.dark, width: 3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        color: AppColors.teal,
                        width: double.infinity,
                        child: const Row(
                          children: [
                            Text(
                              '\u23F1',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'ELAPSED TIME',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: AppColors.card,
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 16),
                        width: double.infinity,
                        child: Column(
                          children: [
                            Text(
                              _formatTime(state.elapsedSeconds),
                              style: const TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2,
                                height: 1,
                                color: AppColors.dark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isWarmup
                                  ? 'WARMUP PHASE'
                                  : isRamping
                                      ? 'RAMP PHASE'
                                      : isSustained
                                          ? '${state.protocol.label.toUpperCase()} PHASE'
                                          : 'READY',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Warmup bar (only during warmup) — countdown
              if (isWarmup)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
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
                          Text(
                            _formatTime(warmupRemaining),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // - button
                          GestureDetector(
                            onTap: () =>
                                controller.adjustPower(-10),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppColors.dark, width: 2),
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
                              style:
                                  const TextStyle(fontFamily: 'Iosevka'),
                              children: [
                                TextSpan(
                                  text: '${state.targetPower}',
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
                            onTap: () =>
                                controller.adjustPower(10),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppColors.dark, width: 2),
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
                        onTap: () => controller.skipWarmup(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.dark,
                            border: Border.all(
                                color: AppColors.dark, width: 2),
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
                ),

              // Stage bar (only during ramping) — with countdown
              if (isRamping)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tealBg,
                    border: Border.all(color: AppColors.teal, width: 3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'STAGE ${state.currentStage + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '\u2014',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${state.targetPower} W',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '\u2014',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(stageRemaining),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),

              // Sustained bar (20min/8min) — power control + progress
              if (isSustained)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.dark, width: 3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => controller.adjustPower(-10),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppColors.dark, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '\u2212',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.dark,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          RichText(
                            text: TextSpan(
                              style:
                                  const TextStyle(fontFamily: 'Iosevka'),
                              children: [
                                TextSpan(
                                  text: '${state.targetPower}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.dark,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' W',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => controller.adjustPower(10),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppColors.dark, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '+',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.dark,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (state.testDuration > 0) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: state.sustainedElapsedSeconds /
                                state.testDuration,
                            minHeight: 8,
                            backgroundColor: AppColors.borderLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.teal),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatTime(sustainedRemaining)} remaining',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Single row of 3 stat cards
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      type: StatCardType.power,
                      value: '${state.currentPower}',
                      unit: 'Watts',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      type: StatCardType.hr,
                      value: '${state.currentHeartRate ?? '--'}',
                      unit: 'BPM',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      type: StatCardType.cadence,
                      value: '${state.currentCadence}',
                      unit: 'RPM',
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Buttons
              if (state.phase == RampTestPhase.idle) ...[
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
                const SizedBox(height: 8),
                AppButton(
                  label: 'Finish & Calculate',
                  variant: AppButtonVariant.outline,
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
