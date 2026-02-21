import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ble_constants.dart';
import '../../../core/constants/ftms_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/icon_box.dart';
import '../../../shared/widgets/tag_widget.dart';
import '../data/ble_scanner_service.dart';
import '../data/hr_repository.dart';
import '../data/trainer_repository.dart';
import '../domain/hr_monitor.dart';
import '../domain/trainer.dart';

class DeviceScanScreen extends ConsumerStatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  ConsumerState<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends ConsumerState<DeviceScanScreen> {
  String? _connectingToId;
  String _selectedMode = 'Ramp Test';

  Future<void> _connectAsTrainer(ScannedDevice device) async {
    setState(() => _connectingToId = device.id);
    final repository = ref.read(trainerRepositoryProvider);
    final trainer = Trainer(id: device.id, name: device.name);
    final success = await repository.connect(trainer);
    if (mounted) {
      setState(() => _connectingToId = null);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to ${device.name}')),
        );
      }
    }
  }

  Future<void> _connectAsHrMonitor(ScannedDevice device) async {
    setState(() => _connectingToId = device.id);
    final repository = ref.read(hrRepositoryProvider);
    final monitor = HrMonitor(id: device.id, name: device.name);
    final success = await repository.connect(monitor);
    if (mounted) {
      setState(() => _connectingToId = null);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to ${device.name}')),
        );
      }
    }
  }

  bool _isTrainer(ScannedDevice device) =>
      device.serviceUuids.contains(FtmsConstants.ftmsServiceShortUuid);

  bool _isHrMonitor(ScannedDevice device) =>
      device.serviceUuids.contains(BleConstants.heartRateServiceShortUuid);

  void _showDeviceSheet({required bool forHr}) {
    final scannerService = ref.read(bleScannerServiceProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // Start a fresh scan and pipe results directly into the sheet via StreamBuilder
        final scanStream = scannerService.scanForDevices();

        return StreamBuilder<List<ScannedDevice>>(
          stream: scanStream,
          initialData: const [],
          builder: (ctx, snapshot) {
            final allDevices = snapshot.data ?? [];
            final relevantDevices = forHr
                ? allDevices.where((d) => _isHrMonitor(d) && !_isTrainer(d)).toList()
                : allDevices.where(_isTrainer).toList();
            final isScanning = snapshot.connectionState == ConnectionState.active;

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
                      Text(
                        forHr ? 'Select HR Monitor' : 'Select Trainer',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          scannerService.stopScan();
                          Navigator.pop(ctx);
                        },
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
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (isScanning && relevantDevices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.teal,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'SCANNING...',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ...relevantDevices.map((device) {
                    final isConnecting = _connectingToId == device.id;
                    return GestureDetector(
                      onTap: isConnecting
                          ? null
                          : () async {
                              scannerService.stopScan();
                              if (forHr) {
                                await _connectAsHrMonitor(device);
                              } else {
                                await _connectAsTrainer(device);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          border: Border.all(color: AppColors.dark, width: 3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.dark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    device.id,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isConnecting)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.teal,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() => scannerService.stopScan());
  }

  void _showModeSelector() {
    final modes = [
      ('Ramp Test', 'Incremental power every minute'),
      ('20 Min Test', 'Sustain max effort for 20 min'),
      ('8 Min Test', 'Two 8-minute max efforts'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
                  'Select Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                    letterSpacing: -0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
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
            ...modes.map((mode) {
              final isSelected = _selectedMode == mode.$1;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedMode = mode.$1);
                  Future.delayed(
                    const Duration(milliseconds: 200),
                    () {
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.tealBg : AppColors.card,
                    border: Border.all(
                      color: isSelected ? AppColors.teal : AppColors.dark,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode.$1,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mode.$2,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.teal
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.teal
                                : AppColors.dark,
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: isSelected
                            ? const Text(
                                '\u2713',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final hrConnectionState = ref.watch(hrConnectionStateProvider);

    final trainerConnected = connectionState.whenOrNull(
          data: (s) => s == TrainerConnectionState.connected,
        ) ??
        false;
    final trainerConnecting = connectionState.whenOrNull(
          data: (s) => s == TrainerConnectionState.connecting,
        ) ??
        false;

    final hrConnected = hrConnectionState.whenOrNull(
          data: (s) => s == HrConnectionState.connected,
        ) ??
        false;
    final hrConnecting = hrConnectionState.whenOrNull(
          data: (s) => s == HrConnectionState.connecting,
        ) ??
        false;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            AppSpacing.lg,
            AppSpacing.screenSide,
            AppSpacing.screenBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              _buildLogo(),
              const SizedBox(height: 22),

              // Mode selector block
              _buildModeSelector(),

              // Pairing block
              _buildPairingBlock(
                trainerConnected: trainerConnected,
                trainerConnecting: trainerConnecting,
                hrConnected: hrConnected,
                hrConnecting: hrConnecting,
              ),

              const Spacer(),

              // Start Test button
              AppButton(
                label: 'Start Test',
                variant: AppButtonVariant.primary,
                prefixIcon: '\u25B6',
                onPressed: trainerConnected
                    ? () => context.go('/ramp-test')
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Iosevka',
              fontSize: 52,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              height: 0.92,
            ),
            children: [
              TextSpan(
                text: 'FTP',
                style: TextStyle(color: AppColors.teal),
              ),
              TextSpan(
                text: '.',
                style: TextStyle(color: AppColors.pink),
              ),
              TextSpan(text: '\n'),
              TextSpan(
                text: 'TEST',
                style: TextStyle(color: AppColors.teal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'POWER LAB',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 4,
            color: Color(0xFFCCCCCC),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return GestureDetector(
      onTap: _showModeSelector,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.dark, width: 3),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: AppColors.teal,
              child: const Text(
                'SELECT MODE',
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
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedMode,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: AppColors.dark,
                    ),
                  ),
                  const Text(
                    '\u203A',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.muted,
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

  Widget _buildPairingBlock({
    required bool trainerConnected,
    required bool trainerConnecting,
    required bool hrConnected,
    required bool hrConnecting,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dark, width: 3),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: AppColors.pink,
            child: const Text(
              'PAIRING',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
          // Trainer row
          Container(
            color: AppColors.card,
            child: Column(
              children: [
                _buildPairRow(
                  icon: const IconBox.trainer(),
                  name: 'Trainer',
                  isConnected: trainerConnected,
                  isConnecting: trainerConnecting,
                  onTap: trainerConnected
                      ? () => ref.read(trainerRepositoryProvider).disconnect()
                      : () => _showDeviceSheet(forHr: false),
                ),
                Container(
                  height: 2,
                  color: AppColors.borderLight,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                _buildPairRow(
                  icon: const IconBox.hr(),
                  name: 'Heart Rate',
                  isConnected: hrConnected,
                  isConnecting: hrConnecting,
                  onTap: hrConnected
                      ? () => ref.read(hrRepositoryProvider).disconnect()
                      : () => _showDeviceSheet(forHr: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairRow({
    required Widget icon,
    required String name,
    required bool isConnected,
    required bool isConnecting,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isConnected
                        ? '\u25CF Connected'
                        : isConnecting
                            ? '\u25CB Connecting...'
                            : '\u25CB Tap to scan',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1,
                      color: isConnected ? AppColors.teal : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (isConnecting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.teal,
                ),
              )
            else
              TagWidget(isOn: isConnected),
          ],
        ),
      ),
    );
  }
}
