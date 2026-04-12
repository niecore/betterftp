import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum Phase { warmup, testing }

class PhaseBadge extends StatefulWidget {
  final Phase phase;

  const PhaseBadge({super.key, required this.phase});

  @override
  State<PhaseBadge> createState() => _PhaseBadgeState();
}

class _PhaseBadgeState extends State<PhaseBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.5,
      upperBound: 1.0,
    );
    if (widget.phase == Phase.warmup) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(PhaseBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase == Phase.warmup) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWarmup = widget.phase == Phase.warmup;
    final color = isWarmup ? AppColors.pink : AppColors.teal;
    final bgColor = isWarmup ? AppColors.pinkBg : AppColors.tealBg;
    final label = isWarmup ? 'WARMUP' : 'TESTING';

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: color,
        ),
      ),
    );

    if (isWarmup) {
      return FadeTransition(
        opacity: _pulseController,
        child: badge,
      );
    }

    return badge;
  }
}
