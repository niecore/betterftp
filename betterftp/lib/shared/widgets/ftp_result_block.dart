import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum FtpResultBlockSize { large, compact }

/// Hero card showing the calculated FTP value. Reused on the results
/// screen (large) and inline during cooldown (compact).
///
/// Visual treatment: teal header strip, pink body, white digits with a
/// hard offset text shadow, dark 3px "border" (rendered as a padded
/// dark fill — not Border.all — so there's no transparent ring at the
/// rounded corners for the drop shadow to bleed through), and a teal
/// hard offset drop shadow underneath.
///
/// The widget reserves the shadow's footprint inside its own reported
/// layout size via a Padding wrapper, so an ancestor with a clipping
/// scroll viewport (e.g. [SingleChildScrollView]) can't cut off the
/// right or bottom edge of the shadow.
///
/// The number counts up from 0 to the final FTP over ~1.1s (ease-out
/// cubic) when the widget first mounts.
class FtpResultBlock extends StatefulWidget {
  final int ftp;
  final FtpResultBlockSize size;

  const FtpResultBlock({
    super.key,
    required this.ftp,
    this.size = FtpResultBlockSize.large,
  });

  @override
  State<FtpResultBlock> createState() => _FtpResultBlockState();
}

class _FtpResultBlockState extends State<FtpResultBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countController;
  late final Animation<double> _count;

  static const double _cornerRadius = 14.0;
  static const double _borderWidth = 3.0;

  @override
  void initState() {
    super.initState();
    _countController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _count = CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOutCubic,
    );
    _countController.forward();
  }

  @override
  void didUpdateWidget(covariant FtpResultBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ftp != widget.ftp) {
      _countController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.size == FtpResultBlockSize.compact;
    final valueFontSize = isCompact ? 56.0 : 92.0;
    final valueLetterSpacing = isCompact ? -2.5 : -4.0;
    final bodyVerticalPadding = isCompact ? 16.0 : 28.0;
    final headerVerticalPadding = isCompact ? 8.0 : 10.0;
    final shadowOffset = isCompact ? 4.0 : 6.0;
    final textShadowOffset = isCompact ? 2.5 : 4.0;

    return AnimatedBuilder(
      animation: _count,
      builder: (context, _) {
        final displayValue = (widget.ftp * _count.value).round();

        return Padding(
          // Reserve shadow footprint inside the widget's own reported
          // size so a clipping ancestor can't cut off its right or
          // bottom edge.
          padding: EdgeInsets.only(
            right: shadowOffset,
            bottom: shadowOffset,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.circular(_cornerRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(shadowOffset, shadowOffset),
                  blurRadius: 0,
                ),
              ],
            ),
            padding: const EdgeInsets.all(_borderWidth),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(_cornerRadius - _borderWidth),
              child: Column(
                children: [
                  // Header — teal
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: headerVerticalPadding,
                      horizontal: 16,
                    ),
                    color: AppColors.pink,
                    width: double.infinity,
                    child: const Text(
                      'ESTIMATED FTP',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: bodyVerticalPadding,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$displayValue',
                          style: TextStyle(
                            fontSize: valueFontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: valueLetterSpacing,
                            height: 1,
                            color: Colors.black
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'WATTS',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
