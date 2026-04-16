import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/ble_debug_logger.dart';

/// Bottom sheet exposing BLE debug-log actions from the home screen's
/// gear icon.
class SettingsBottomSheet extends ConsumerStatefulWidget {
  const SettingsBottomSheet({super.key});

  @override
  ConsumerState<SettingsBottomSheet> createState() =>
      _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends ConsumerState<SettingsBottomSheet> {
  Timer? _refreshTimer;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _share() async {
    final logger = ref.read(bleDebugLoggerProvider);
    setState(() => _sharing = true);
    try {
      await logger.shareLog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share log: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _clear() {
    final logger = ref.read(bleDebugLoggerProvider);
    logger.clear();
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('BLE debug log cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logger = ref.read(bleDebugLoggerProvider);
    final kb = (logger.bufferBytes / 1024).toStringAsFixed(0);
    final maxKb = BleDebugLogger.maxBytes ~/ 1024;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenSide,
        AppSpacing.xxl,
        AppSpacing.screenSide,
        40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                  letterSpacing: -0.5,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.dark, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '\u2715',
                    style: TextStyle(fontSize: 16, color: AppColors.dark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'BLE DEBUG LOG',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${logger.entryCount} entries \u00B7 $kb/$maxKb KB',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.darkSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _sharing ? 'Sharing\u2026' : 'Share BLE Debug Log',
            variant: AppButtonVariant.outline,
            prefixIcon: '\u2191',
            onPressed: _sharing ? null : _share,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Clear Log',
            variant: AppButtonVariant.outline,
            prefixIcon: '\u2715',
            onPressed: logger.entryCount == 0 ? null : _clear,
          ),
        ],
      ),
    );
  }
}
