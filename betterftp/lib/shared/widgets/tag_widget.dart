import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class TagWidget extends StatelessWidget {
  final bool isOn;
  final String? label;

  const TagWidget({super.key, required this.isOn, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: isOn ? AppColors.teal : const Color(0xFFDDDDDD),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
        color: isOn ? AppColors.tealBg : Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOn) ...[
            const Text(
              '\u2713',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label ?? (isOn ? 'CONNECTED' : '---'),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: isOn ? AppColors.teal : const Color(0xFFCCCCCC),
            ),
          ),
        ],
      ),
    );
  }
}
