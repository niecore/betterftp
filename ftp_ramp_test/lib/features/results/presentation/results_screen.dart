import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../ramp_test/domain/ramp_test_state.dart';

class ResultsScreen extends StatelessWidget {
  final RampTestState testState;

  const ResultsScreen({super.key, required this.testState});

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.teal,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '\u2713 TEST COMPLETE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Your Results',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                color: AppColors.dark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // FTP result block
                      Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: AppColors.dark, width: 3),
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
                                color: AppColors.pink,
                                width: double.infinity,
                                child: const Text(
                                  'ESTIMATED FTP',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                color: AppColors.card,
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                  horizontal: 16,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${testState.calculatedFtp ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 68,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -3,
                                        height: 1,
                                        color: AppColors.dark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'WATTS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                        letterSpacing: 2,
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

                      // Max HR + Duration stat cards
                      Row(
                        children: [
                          // Max HR
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppColors.dark, width: 3),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 7,
                                        horizontal: 10,
                                      ),
                                      color: AppColors.pink,
                                      width: double.infinity,
                                      child: const Row(
                                        children: [
                                          Text(
                                            '\u2665',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'MAX HR',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      color: AppColors.card,
                                      padding: const EdgeInsets.all(12),
                                      width: double.infinity,
                                      child: Column(
                                        children: [
                                          Text(
                                            testState.maxHeartRate != null
                                                ? '${testState.maxHeartRate}'
                                                : '--',
                                            style: const TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -1,
                                              height: 1,
                                              color: AppColors.dark,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          const Text(
                                            'BPM',
                                            style: TextStyle(
                                              fontSize: 9,
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
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Duration
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppColors.dark, width: 3),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 7,
                                        horizontal: 10,
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
                                          SizedBox(width: 5),
                                          Text(
                                            'DURATION',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      color: AppColors.card,
                                      padding: const EdgeInsets.all(12),
                                      width: double.infinity,
                                      child: Column(
                                        children: [
                                          Text(
                                            _formatTime(
                                                testState.elapsedSeconds),
                                            style: const TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -1,
                                              height: 1,
                                              color: AppColors.dark,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          const Text(
                                            'MINUTES',
                                            style: TextStyle(
                                              fontSize: 9,
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Test Summary block
                      Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: AppColors.dark, width: 3),
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
                                color: AppColors.dark,
                                width: double.infinity,
                                child: const Text(
                                  'TEST SUMMARY',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                color: AppColors.card,
                                child: Column(
                                  children: [
                                    if (testState.protocol ==
                                        TestProtocol.ramp)
                                      _DetailRow(
                                        label: 'Best 1-min Avg',
                                        value:
                                            '${testState.bestOneMinAvgPower.round()} W',
                                      ),
                                    _DetailRow(
                                      label: 'Max Power',
                                      value:
                                          '${testState.maxPower} W',
                                    ),
                                    if (testState.maxHeartRate != null)
                                      _DetailRow(
                                        label: 'Max Heart Rate',
                                        value:
                                            '${testState.maxHeartRate} BPM',
                                      ),
                                    if (testState.averageHeartRate != null)
                                      _DetailRow(
                                        label: 'Avg Heart Rate',
                                        value:
                                            '${testState.averageHeartRate} BPM',
                                      ),
                                    if (testState.protocol ==
                                        TestProtocol.ramp)
                                      _DetailRow(
                                        label: 'Stages Completed',
                                        value:
                                            '${testState.currentStage + 1}',
                                      ),
                                    _DetailRow(
                                      label: 'Protocol',
                                      value: testState.protocol.label,
                                      isLast: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Buttons pinned at bottom
              const SizedBox(height: 10),
              AppButton(
                label: 'Save Result',
                variant: AppButtonVariant.teal,
                prefixIcon: '\u2713',
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: '\u2190 Back to Home',
                variant: AppButtonVariant.outline,
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom:
                    BorderSide(color: AppColors.borderLight, width: 2),
              ),
      ),
      padding:
          const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.dark,
            ),
          ),
        ],
      ),
    );
  }
}
