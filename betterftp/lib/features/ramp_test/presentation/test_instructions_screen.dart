import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/page_max_width.dart';
import '../../../shared/widgets/responsive_screen_body.dart';
import '../domain/protocol_registry.dart';
import '../domain/ramp_test_state.dart';

/// Briefing screen shown after pairing and before the test starts.
/// Describes the selected test protocol and waits for user confirmation.
class TestInstructionsScreen extends StatelessWidget {
  final TestProtocol protocol;

  const TestInstructionsScreen({super.key, required this.protocol});

  @override
  Widget build(BuildContext context) {
    final protocolDef = ProtocolRegistry.get(protocol);

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
                // Back chrome + headline + instructions box are one
                // cluster: top-aligned on phones, vertically centred
                // on tablets. ResponsiveScreenBody handles both modes
                // and falls back to scroll-on-overflow.
                ResponsiveScreenBody(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Top bar: back button + title ──
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.go('/'),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                border: Border.all(
                                    color: AppColors.dark, width: 2.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '\u2039',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: AppColors.dark,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Test Protocol',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.dark,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // ── Protocol name headline ──
                      Text(
                        protocolDef.label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dark,
                          letterSpacing: -2,
                          height: 0.95,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        protocolDef.description.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Instructions block ──
                      Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: AppColors.dark, width: 3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                color: AppColors.teal,
                                child: const Text(
                                  'HOW IT WORKS',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                color: AppColors.card,
                                padding:
                                    const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    for (var i = 0;
                                        i < protocolDef.instructions.length;
                                        i++) ...[
                                      _InstructionItem(
                                        number: i + 1,
                                        text: protocolDef.instructions[i],
                                      ),
                                      if (i <
                                          protocolDef.instructions.length -
                                              1)
                                        const SizedBox(height: 14),
                                    ],
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

                const SizedBox(height: 10),

                // ── Confirmation button ──
                AppButton(
                  label: 'Start Protocol',
                  variant: AppButtonVariant.primary,
                  prefixIcon: '\u25B6',
                  onPressed: () => context.go('/workout', extra: {
                    'autoStart': true,
                    'protocol': protocol.name,
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single numbered instruction row.
class _InstructionItem extends StatelessWidget {
  final int number;
  final String text;

  const _InstructionItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.tealBg,
            border: Border.all(color: AppColors.teal, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.teal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.dark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
