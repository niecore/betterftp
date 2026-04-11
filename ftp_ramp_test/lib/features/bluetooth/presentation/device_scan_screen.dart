import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/ble_constants.dart';
import '../../../core/constants/ftms_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/icon_box.dart';
import '../../../shared/widgets/tag_widget.dart';
import '../data/ble_scanner_service.dart';
import '../data/device_storage_service.dart';
import '../data/hr_repository.dart';
import '../data/trainer_repository.dart';
import '../domain/hr_monitor.dart';
import '../domain/trainer.dart';

class DeviceScanScreen extends ConsumerStatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  ConsumerState<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends ConsumerState<DeviceScanScreen>
    with SingleTickerProviderStateMixin {
  String _selectedMode = 'Ramp Test';
  late final VideoPlayerController _hamsterController;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  @override
  void initState() {
    super.initState();
    _hamsterController =
        VideoPlayerController.asset('assets/animations/hamster.mp4')
          ..setLooping(true)
          ..setVolume(0)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _hamsterController.play();
            }
          });

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeOut,
    ));

    // Auto-reconnect to previously paired devices
    _autoReconnect();
  }

  Future<void> _autoReconnect() async {
    final storage = ref.read(deviceStorageServiceProvider);
    final savedTrainer = storage.getSavedTrainer();
    final savedHr = storage.getSavedHrMonitor();

    if (savedTrainer == null && savedHr == null) return;

    // Wait for Bluetooth adapter to be ready before connecting
    try {
      final adapterState = await FlutterBluePlus.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          .timeout(const Duration(seconds: 5));
      if (adapterState != BluetoothAdapterState.on) return;
    } catch (e) {
      developer.log('Auto-reconnect: Bluetooth not ready, skipping',
          name: 'DeviceScanScreen');
      return;
    }

    if (!mounted) return;

    if (savedTrainer != null) {
      ref
          .read(trainerRepositoryProvider)
          .connectById(savedTrainer.id, savedTrainer.name);
    }

    if (savedHr != null) {
      ref
          .read(hrRepositoryProvider)
          .connectById(savedHr.id, savedHr.name);
    }
  }

  void _shakePairingBlock() {
    _shakeController.forward(from: 0);
  }

  @override
  void dispose() {
    _hamsterController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _connectAsTrainer(ScannedDevice device) async {
    final repository = ref.read(trainerRepositoryProvider);
    final trainer = Trainer(id: device.id, name: device.name);
    final success = await repository.connect(trainer);
    if (success) {
      ref.read(deviceStorageServiceProvider).saveTrainer(device.id, device.name);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to ${device.name}')),
      );
    }
  }

  Future<void> _connectAsHrMonitor(ScannedDevice device) async {
    final repository = ref.read(hrRepositoryProvider);
    final monitor = HrMonitor(id: device.id, name: device.name);
    final success = await repository.connect(monitor);
    if (success) {
      ref.read(deviceStorageServiceProvider).saveHrMonitor(device.id, device.name);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to ${device.name}')),
      );
    }
  }

  bool _isTrainer(ScannedDevice device) =>
      device.serviceUuids.contains(FtmsConstants.ftmsServiceShortUuid);

  bool _isHrMonitor(ScannedDevice device) =>
      device.serviceUuids.contains(BleConstants.heartRateServiceShortUuid);

  /// Build signal bars widget based on RSSI value
  Widget _buildSignalBars(int rssi) {
    // RSSI ranges: excellent > -50, good > -70, fair > -85, weak <= -85
    final int bars;
    if (rssi > -50) {
      bars = 4;
    } else if (rssi > -70) {
      bars = 3;
    } else if (rssi > -85) {
      bars = 2;
    } else {
      bars = 1;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < 4; i++)
          Container(
            width: 3,
            height: 4.0 + (i * 3),
            margin: const EdgeInsets.only(right: 1.5),
            decoration: BoxDecoration(
              color: i < bars ? AppColors.teal : const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          '$rssi dBm',
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  void _showDeviceSheet({required bool forHr}) {
    final scannerService = ref.read(bleScannerServiceProvider);
    final scanStream = scannerService.scanForDevices();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _DeviceScanSheet(
          scanStream: scanStream,
          scannerService: scannerService,
          forHr: forHr,
          isTrainer: _isTrainer,
          isHrMonitor: _isHrMonitor,
          buildSignalBars: _buildSignalBars,
          onDeviceSelected: (device) {
            scannerService.stopScan();
            Navigator.pop(ctx);
            if (forHr) {
              _connectAsHrMonitor(device);
            } else {
              _connectAsTrainer(device);
            }
          },
          onClose: () {
            scannerService.stopScan();
            Navigator.pop(ctx);
          },
        );
      },
    ).whenComplete(() => scannerService.stopScan());
  }

  void _showModeSelector() {
    final modes = [
      ('Ramp Test', 'Incremental power every minute'),
      ('20 Min Test', 'Sustain max effort for 20 min'),
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
                  'Select Protocol',
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

    // Live data
    final trainerData = ref.watch(trainerDataProvider);
    final hrData = ref.watch(hrDataProvider);
    final trainerName = ref.watch(connectedTrainerNameProvider);
    final hrName = ref.watch(connectedHrNameProvider);

    final liveCadence = trainerConnected
        ? trainerData.whenOrNull(data: (d) => d.cadence)
        : null;
    final liveHr =
        hrConnected ? hrData.whenOrNull(data: (d) => d.heartRate) : null;

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
              _buildLogo(),
              const SizedBox(height: 22),
              _buildModeSelector(),
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                ),
                child: _buildPairingBlock(
                  trainerConnected: trainerConnected,
                  trainerConnecting: trainerConnecting,
                  hrConnected: hrConnected,
                  hrConnecting: hrConnecting,
                  trainerName: trainerName,
                  hrName: hrName,
                  liveCadence: liveCadence,
                  liveHr: liveHr,
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'Start Test',
                variant: AppButtonVariant.primary,
                prefixIcon: '\u25B6',
                onPressed: trainerConnected
                    ? () => context.go('/test-instructions', extra: {
                          'protocol': _selectedMode == '20 Min Test'
                              ? 'twentyMin'
                              : 'ramp',
                        })
                    : () => _shakePairingBlock(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    const double badgeSize = 200;

    return Center(
      child: Column(
        children: [
          // Circle video badge
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bg,
              border: Border.all(color: AppColors.dark, width: 4),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.dark,
                  offset: Offset(4, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 0,
                  bottom: 16,
                  left: 32,
                  right: 32,
                ),
                child: _hamsterController.value.isInitialized
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        AppColors.bg,
                        BlendMode.multiply,
                      ),
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _hamsterController.value.size.width,
                          height: _hamsterController.value.size.height,
                          child: VideoPlayer(_hamsterController),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Wordmark
          RichText(
            textAlign: TextAlign.center,
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
                  text: 'BETTER',
                  style: TextStyle(color: AppColors.teal),
                ),
                TextSpan(
                  text: '.',
                  style: TextStyle(color: AppColors.pink),
                ),
                TextSpan(
                  text: 'FTP',
                  style: TextStyle(color: AppColors.teal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'betterftp.cc',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 4,
              color: Color(0xFFCCCCCC),
            ),
          ),
        ],
      ),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: AppColors.teal,
                child: const Text(
                  'SELECT PROTOCOL',
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
      ),
    );
  }

  Widget _buildPairingBlock({
    required bool trainerConnected,
    required bool trainerConnecting,
    required bool hrConnected,
    required bool hrConnecting,
    required String? trainerName,
    required String? hrName,
    required int? liveCadence,
    required int? liveHr,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dark, width: 3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
            Container(
              color: AppColors.card,
              child: Column(
                children: [
                  _buildPairRow(
                    icon: trainerConnected &&
                            liveCadence != null &&
                            liveCadence > 0
                        ? const SpinningIconBox.trainer()
                        : const IconBox.trainer(),
                    name: 'Trainer',
                    deviceName: trainerName,
                    isConnected: trainerConnected,
                    isConnecting: trainerConnecting,
                    liveValue: trainerConnected && liveCadence != null
                        ? '$liveCadence RPM'
                        : null,
                    onTap: trainerConnected
                        ? () =>
                            ref.read(trainerRepositoryProvider).disconnect()
                        : () => _showDeviceSheet(forHr: false),
                  ),
                  Container(
                    height: 2,
                    color: AppColors.borderLight,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  _buildPairRow(
                    icon: hrConnected && liveHr != null && liveHr > 0
                        ? const PulsingIconBox.hr()
                        : const IconBox.hr(),
                    name: 'Heart Rate',
                    deviceName: hrName,
                    isConnected: hrConnected,
                    isConnecting: hrConnecting,
                    liveValue: hrConnected && liveHr != null
                        ? '$liveHr BPM'
                        : null,
                    onTap: hrConnected
                        ? () => ref.read(hrRepositoryProvider).disconnect()
                        : () => _showDeviceSheet(forHr: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairRow({
    required Widget icon,
    required String name,
    required String? deviceName,
    required bool isConnected,
    required bool isConnecting,
    required VoidCallback onTap,
    String? liveValue,
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
                    isConnected && deviceName != null ? deviceName : name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    liveValue ??
                        (isConnected
                            ? '\u25CF Connected'
                            : isConnecting
                                ? '\u25CB Connecting...'
                                : '\u25CB Tap to scan'),
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

/// Stateful bottom sheet that subscribes to the scan stream and rebuilds
/// as new devices are discovered.
class _DeviceScanSheet extends StatefulWidget {
  final Stream<List<ScannedDevice>> scanStream;
  final BleScannerService scannerService;
  final bool forHr;
  final bool Function(ScannedDevice) isTrainer;
  final bool Function(ScannedDevice) isHrMonitor;
  final Widget Function(int rssi) buildSignalBars;
  final void Function(ScannedDevice device) onDeviceSelected;
  final VoidCallback onClose;

  const _DeviceScanSheet({
    required this.scanStream,
    required this.scannerService,
    required this.forHr,
    required this.isTrainer,
    required this.isHrMonitor,
    required this.buildSignalBars,
    required this.onDeviceSelected,
    required this.onClose,
  });

  @override
  State<_DeviceScanSheet> createState() => _DeviceScanSheetState();
}

class _DeviceScanSheetState extends State<_DeviceScanSheet> {
  List<ScannedDevice> _devices = [];
  bool _isScanning = true;
  late final StreamSubscription<List<ScannedDevice>> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.scanStream.listen(
      (devices) {
        if (mounted) {
          setState(() {
            _devices = devices;
          });
        }
      },
      onDone: () {
        if (mounted) setState(() => _isScanning = false);
      },
      onError: (_) {
        if (mounted) setState(() => _isScanning = false);
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final relevantDevices = widget.forHr
        ? _devices
            .where((d) => widget.isHrMonitor(d) && !widget.isTrainer(d))
            .toList()
        : _devices.where(widget.isTrainer).toList();

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
                widget.forHr ? 'Select HR Monitor' : 'Select Trainer',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                  letterSpacing: -0.5,
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
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
          if (_isScanning && relevantDevices.isEmpty)
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
            return GestureDetector(
              onTap: () => widget.onDeviceSelected(device),
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
                    widget.buildSignalBars(device.rssi),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

