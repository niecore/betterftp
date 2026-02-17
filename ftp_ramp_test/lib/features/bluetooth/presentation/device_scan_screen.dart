import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  List<ScannedDevice> _devices = [];
  bool _isScanning = false;
  String? _errorMessage;
  StreamSubscription? _scanSubscription;
  String? _connectingToId;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    final scannerService = ref.read(bleScannerServiceProvider);

    // Check if Bluetooth is available
    final isAvailable = await scannerService.isBluetoothAvailable();
    if (!isAvailable) {
      setState(() {
        _errorMessage = 'Please enable Bluetooth';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _devices = [];
    });

    _scanSubscription?.cancel();
    _scanSubscription = scannerService.scanForDevices().listen(
      (devices) {
        setState(() {
          _devices = devices;
        });
      },
      onError: (error) {
        setState(() {
          _isScanning = false;
          _errorMessage = 'Scan error: $error';
        });
      },
    );

    // Stop scanning after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isScanning) {
        _stopScan();
      }
    });
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    setState(() {
      _isScanning = false;
    });
  }

  void _showDeviceTypeSheet(ScannedDevice device) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                device.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.directions_bike),
              title: const Text('Connect as Trainer'),
              onTap: () {
                Navigator.pop(context);
                _connectAsTrainer(device);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Connect as HR Monitor'),
              onTap: () {
                Navigator.pop(context);
                _connectAsHrMonitor(device);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _connectAsTrainer(ScannedDevice device) async {
    setState(() {
      _connectingToId = device.id;
    });

    final repository = ref.read(trainerRepositoryProvider);
    final trainer = Trainer(id: device.id, name: device.name);
    final success = await repository.connect(trainer);

    setState(() {
      _connectingToId = null;
    });

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to ${device.name}')),
      );
    }
  }

  Future<void> _connectAsHrMonitor(ScannedDevice device) async {
    setState(() {
      _connectingToId = device.id;
    });

    final repository = ref.read(hrRepositoryProvider);
    final monitor = HrMonitor(id: device.id, name: device.name);
    final success = await repository.connect(monitor);

    setState(() {
      _connectingToId = null;
    });

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to ${device.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final trainerData = ref.watch(trainerDataProvider);
    final hrConnectionState = ref.watch(hrConnectionStateProvider);
    final hrData = ref.watch(hrDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FTP Ramp Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Connection status card
          connectionState.when(
            data: (state) => _ConnectionStatusCard(
              state: state,
              trainerData: trainerData.value,
              hrState: hrConnectionState.value,
              hrData: hrData.value,
              onDisconnect: () {
                ref.read(trainerRepositoryProvider).disconnect();
              },
              onDisconnectHr: () {
                ref.read(hrRepositoryProvider).disconnect();
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Start Ramp Test button (visible when connected)
          connectionState.when(
            data: (state) {
              if (state == TrainerConnectionState.connected) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/ramp-test'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'Start Ramp Test',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Error message
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade100,
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),

          // Scan button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? _stopScan : _startScan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_isScanning ? 'Stop Scan' : 'Scan for Devices'),
              ),
            ),
          ),

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Text(
                      _isScanning
                          ? 'Searching for devices...'
                          : 'Tap "Scan" to find devices',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isConnecting = _connectingToId == device.id;

                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name),
                        subtitle: Text(device.id),
                        trailing: isConnecting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: isConnecting
                            ? null
                            : () => _showDeviceTypeSheet(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  final TrainerConnectionState state;
  final TrainerData? trainerData;
  final HrConnectionState? hrState;
  final HrData? hrData;
  final VoidCallback onDisconnect;
  final VoidCallback onDisconnectHr;

  const _ConnectionStatusCard({
    required this.state,
    required this.trainerData,
    this.hrState,
    this.hrData,
    required this.onDisconnect,
    required this.onDisconnectHr,
  });

  @override
  Widget build(BuildContext context) {
    final showTrainer = state != TrainerConnectionState.disconnected;
    final showHr = hrState != null &&
        hrState != HrConnectionState.disconnected;

    if (!showTrainer && !showHr) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trainer status
            if (showTrainer) ...[
              Row(
                children: [
                  Icon(
                    state == TrainerConnectionState.connected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_searching,
                    color: state == TrainerConnectionState.connected
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state == TrainerConnectionState.connected
                        ? 'Trainer Connected'
                        : state == TrainerConnectionState.connecting
                            ? 'Connecting Trainer...'
                            : 'Disconnecting...',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (state == TrainerConnectionState.connected)
                    TextButton(
                      onPressed: onDisconnect,
                      child: const Text('Disconnect'),
                    ),
                ],
              ),
              if (state == TrainerConnectionState.connected &&
                  trainerData != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _DataDisplay(
                      label: 'Power',
                      value: '${trainerData!.power}',
                      unit: 'W',
                    ),
                    _DataDisplay(
                      label: 'Cadence',
                      value: '${trainerData!.cadence}',
                      unit: 'rpm',
                    ),
                  ],
                ),
              ],
            ],

            // HR status
            if (showHr) ...[
              if (showTrainer) const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: hrState == HrConnectionState.connected
                        ? Colors.red
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hrState == HrConnectionState.connected
                        ? 'HR: ${hrData?.heartRate ?? '--'} bpm'
                        : hrState == HrConnectionState.connecting
                            ? 'Connecting HR...'
                            : 'Disconnecting HR...',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (hrState == HrConnectionState.connected)
                    TextButton(
                      onPressed: onDisconnectHr,
                      child: const Text('Disconnect'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DataDisplay extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _DataDisplay({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}
