import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppButtonVariant { primary, teal, pink, outline }

class AppButton extends StatefulWidget {
  final String label;
  final AppButtonVariant variant;
  final VoidCallback? onPressed;
  final String? prefixIcon;

  const AppButton({
    super.key,
    required this.label,
    this.variant = AppButtonVariant.primary,
    this.onPressed,
    this.prefixIcon,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressing = false;

  Color get _defaultBg => switch (widget.variant) {
        AppButtonVariant.primary => AppColors.dark,
        AppButtonVariant.teal => AppColors.teal,
        AppButtonVariant.pink => AppColors.pink,
        AppButtonVariant.outline => Colors.transparent,
      };

  Color get _defaultBorder => switch (widget.variant) {
        AppButtonVariant.outline => AppColors.dark,
        _ => _defaultBg,
      };

  Color get _defaultText => switch (widget.variant) {
        AppButtonVariant.outline => AppColors.dark,
        _ => Colors.white,
      };

  double get _fontSize => switch (widget.variant) {
        AppButtonVariant.primary => 16,
        _ => 14,
      };

  @override
  Widget build(BuildContext context) {
    final bg = _pressing ? AppColors.yellow : _defaultBg;
    final border = _pressing ? AppColors.yellowDeep : _defaultBorder;
    final textColor = _pressing ? AppColors.dark : _defaultText;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 3),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          '${widget.prefixIcon != null ? '${widget.prefixIcon} ' : ''}${widget.label}',
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
