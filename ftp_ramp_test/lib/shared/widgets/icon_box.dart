import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class IconBox extends StatelessWidget {
  final String emoji;
  final Color backgroundColor;

  const IconBox({
    super.key,
    required this.emoji,
    required this.backgroundColor,
  });

  const IconBox.trainer({super.key})
      : emoji = '\u26A1',
        backgroundColor = AppColors.trainerBg;

  const IconBox.hr({super.key})
      : emoji = '\u2665',
        backgroundColor = AppColors.hrBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: AppColors.dark, width: 2.5),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 15)),
    );
  }
}
