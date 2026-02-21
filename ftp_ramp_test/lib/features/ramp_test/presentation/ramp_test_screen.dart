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
  const RampTestScreen({super.key});

  @override
  ConsumerState<RampTestScreen> createState() => _RampTestScreenState();
}

class _RampTestScreenState extends ConsumerState<RampTestScreen> {
  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
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

    final isRunning =
        state.phase == RampTestPhase.warmup ||
        state.phase == RampTestPhase.ramping;
    final isWarmup = state.phase == RampTestPhase.warmup;
    final progress = state.elapsedSeconds > 0
        ? (state.elapsedSeconds / 1200).clamp(0.0, 1.0)
        : 0.0;
    final progressPct = (progress * 100).round();

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
                clipBehavior: Clip.antiAlias,
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
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
                            'of ~20:00 est.',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Warmup bar (only during warmup)
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
                          const Text(
                            'WARMUP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontFamily: 'Iosevka'),
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
                ),

              // 2x2 stat grid
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
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      type: StatCardType.cadence,
                      value: '${state.currentCadence}',
                      unit: 'RPM',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      type: StatCardType.speed,
                      value: '${state.currentStage + 1}',
                      unit: 'STAGE',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress bar
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PROGRESS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        '$progressPct%',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E5E0),
                      border: Border.all(color: AppColors.dark, width: 2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.toDouble(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
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
                    controller.start();
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
