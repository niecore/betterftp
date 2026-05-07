import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/ftp_result_block.dart';
import '../../../shared/widgets/page_max_width.dart';
import '../../../shared/widgets/responsive_screen_body.dart';
import '../../ramp_test/domain/protocol_registry.dart';
import '../../ramp_test/domain/ramp_test_state.dart';
import '../../ramp_test/domain/test_phase.dart';
import '../../ramp_test/presentation/ramp_test_controller.dart';
import '../data/fit_share_service.dart';

/// Results interstitial — shown while the FSM sits in the paused
/// `results` phase between the test and (optional) cooldown, and again
/// after cooldown. Buttons drive the FSM via [UserAction]; phase-change
/// listeners route to the next screen.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _isExporting = false;

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSummaryRows(TestRunState state) {
    final protocol = ProtocolRegistry.get(state.protocol);
    final extraMetrics = protocol.resultMetrics(state);

    final rows = <Map<String, String>>[
      for (final metric in extraMetrics)
        {'label': metric.label, 'value': metric.value},
      {'label': 'Max Power', 'value': '${state.maxPower} W'},
      if (state.maxHeartRate != null)
        {'label': 'Max Heart Rate', 'value': '${state.maxHeartRate} BPM'},
      if (state.averageHeartRate != null)
        {'label': 'Avg Heart Rate', 'value': '${state.averageHeartRate} BPM'},
      {'label': 'Protocol', 'value': state.protocol.label},
    ];

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++)
          _DetailRow(
            label: rows[i]['label']!,
            value: rows[i]['value']!,
            isLast: i == rows.length - 1,
          ),
      ],
    );
  }

  Future<void> _shareFitFile(TestRunState state) async {
    setState(() => _isExporting = true);
    try {
      await FitShareService().shareTestResult(state);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rampTestControllerProvider);
    final controller = ref.read(rampTestControllerProvider.notifier);

    // Phase-driven navigation: leaving the `results` phase always means
    // the user pressed a button — route to the new owning screen.
    ref.listen(rampTestControllerProvider, (previous, next) {
      if (previous?.currentPhase.id == next.currentPhase.id) return;
      switch (next.currentPhase.id) {
        case 'done':
          WakelockPlus.disable();
          context.go('/');
          break;
      }
    });

    return Scaffold(
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
              // Result cards — centred on tablets, top-aligned on
              // phones, scrollable when they overflow.
              ResponsiveScreenBody(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      // Header
                      const Center(
                        child: Column(
                          children: [
                            SizedBox(height: 8),
                            Text(
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
                      FtpResultBlock(ftp: state.calculatedFtp ?? 0),
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
                                            state.maxHeartRate != null
                                                ? '${state.maxHeartRate}'
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
                                            _formatTime(state.elapsedSeconds),
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
                                child: _buildSummaryRows(state),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Buttons pinned at bottom
              const SizedBox(height: 10),
              AppButton(
                label: _isExporting ? 'Saving...' : 'Save .FIT',
                variant: AppButtonVariant.teal,
                onPressed: _isExporting ? null : () => _shareFitFile(state),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Discard & Back to Home',
                variant: AppButtonVariant.outline,
                onPressed: () =>
                    controller.onUserAction(UserAction.finish),
              ),
            ],
          ),
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
