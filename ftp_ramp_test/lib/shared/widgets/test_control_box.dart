import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// "TEST CONTROL" box shown beneath the HUD when the current phase allows
/// manual power adjustment. Contains two oversized −/+ buttons sized for
/// bike use.
class TestControlBox extends StatelessWidget {
  final void Function(int delta) onAdjust;
  final int step;

  const TestControlBox({
    super.key,
    required this.onAdjust,
    this.step = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            // ── Pink headline ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 16,
              ),
              color: AppColors.pink,
              child: const Text(
                'TEST CONTROL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ),
            // ── Body: [−] [+] buttons ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BigPowerButton(
                    symbol: '\u2212',
                    onTap: () => onAdjust(-step),
                  ),
                  const SizedBox(width: 12),
                  _BigPowerButton(
                    symbol: '+',
                    onTap: () => onAdjust(step),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigPowerButton extends StatefulWidget {
  final String symbol;
  final VoidCallback onTap;

  const _BigPowerButton({
    required this.symbol,
    required this.onTap,
  });

  @override
  State<_BigPowerButton> createState() => _BigPowerButtonState();
}

class _BigPowerButtonState extends State<_BigPowerButton> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final bg = _pressing ? AppColors.yellow : AppColors.card;
    final border = _pressing ? AppColors.yellowDeep : AppColors.dark;

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) {
          setState(() => _pressing = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressing = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 3),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.symbol,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.dark,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
