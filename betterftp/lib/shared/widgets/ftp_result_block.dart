import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum FtpResultBlockSize { large, compact }

/// Pink-headed card showing the calculated FTP value. Reused on the
/// results screen (large) and inline during cooldown (compact).
class FtpResultBlock extends StatelessWidget {
  final int ftp;
  final FtpResultBlockSize size;

  const FtpResultBlock({
    super.key,
    required this.ftp,
    this.size = FtpResultBlockSize.large,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = size == FtpResultBlockSize.compact;
    final valueFontSize = isCompact ? 42.0 : 68.0;
    final bodyVerticalPadding = isCompact ? 12.0 : 24.0;
    final headerVerticalPadding = isCompact ? 8.0 : 10.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dark, width: 3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: [
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
              color: AppColors.card,
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: bodyVerticalPadding,
                horizontal: 16,
              ),
              child: Column(
                children: [
                  Text(
                    '$ftp',
                    style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3,
                      height: 1,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'WATTS',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      letterSpacing: 2,
                    ),
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
