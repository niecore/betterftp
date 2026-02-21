import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum BlockHeaderColor { teal, pink, dark }

class BlockCard extends StatelessWidget {
  final String headerLabel;
  final BlockHeaderColor headerColor;
  final Widget child;
  final bool interactive;
  final VoidCallback? onTap;

  const BlockCard({
    super.key,
    required this.headerLabel,
    this.headerColor = BlockHeaderColor.teal,
    required this.child,
    this.interactive = false,
    this.onTap,
  });

  Color get _headerBg => switch (headerColor) {
        BlockHeaderColor.teal => AppColors.teal,
        BlockHeaderColor.pink => AppColors.pink,
        BlockHeaderColor.dark => AppColors.dark,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: interactive ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.dark, width: 3),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: AppSpacing.lg,
                ),
                color: _headerBg,
                child: Text(
                  headerLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
              // Body
              Container(
                color: AppColors.card,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
