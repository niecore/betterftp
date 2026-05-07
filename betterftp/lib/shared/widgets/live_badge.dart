import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Phase badge with blinking dot — shows "WARMUP" / "COOLDOWN" (teal) or
/// "LIVE" (pink).
class LiveBadge extends StatefulWidget {
  final bool isWarmup;
  final bool isCooldown;

  const LiveBadge({
    super.key,
    this.isWarmup = false,
    this.isCooldown = false,
  });

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      lowerBound: 0.3,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = widget.isWarmup || widget.isCooldown;
    final color = isMuted ? AppColors.teal : AppColors.pink;
    final dotColor = isMuted ? AppColors.tealLight : AppColors.pinkLight;
    final bgColor = isMuted ? AppColors.tealBg : AppColors.pinkBg;
    final label = widget.isWarmup
        ? 'WARMUP'
        : widget.isCooldown
            ? 'COOLDOWN'
            : 'LIVE';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _controller,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
