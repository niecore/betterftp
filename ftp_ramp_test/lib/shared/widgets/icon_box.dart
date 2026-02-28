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

/// An IconBox whose content pulses (scales up/down) — used for live HR display.
class PulsingIconBox extends StatefulWidget {
  final String emoji;
  final Color backgroundColor;

  const PulsingIconBox({
    super.key,
    required this.emoji,
    required this.backgroundColor,
  });

  const PulsingIconBox.hr({super.key})
      : emoji = '\u2665',
        backgroundColor = AppColors.hrBg;

  @override
  State<PulsingIconBox> createState() => _PulsingIconBoxState();
}

class _PulsingIconBoxState extends State<PulsingIconBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: Border.all(color: AppColors.dark, width: 2.5),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Text(widget.emoji, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}

/// An IconBox whose content spins — used for live cadence display.
class SpinningIconBox extends StatefulWidget {
  final String emoji;
  final Color backgroundColor;

  const SpinningIconBox({
    super.key,
    required this.emoji,
    required this.backgroundColor,
  });

  const SpinningIconBox.trainer({super.key})
      : emoji = '\u26A1',
        backgroundColor = AppColors.trainerBg;

  @override
  State<SpinningIconBox> createState() => _SpinningIconBoxState();
}

class _SpinningIconBoxState extends State<SpinningIconBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: Border.all(color: AppColors.dark, width: 2.5),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: RotationTransition(
        turns: _controller,
        child: Text(widget.emoji, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
