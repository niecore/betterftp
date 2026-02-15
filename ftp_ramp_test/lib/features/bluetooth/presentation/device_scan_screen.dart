import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/trainer_repository.dart';
import '../domain/trainer.dart';

class DeviceScanScreen extends ConsumerStatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  ConsumerState<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends ConsumerState<DeviceScanScreen> {
  List<Trainer> _devices = [];
  bool _isScanning = false;
  String? _errorMessage;
  StreamSubscription? _scanSubscription;
  Trainer? _connectingTo;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // Request Bluetooth permissions
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    if (bluetoothScan.isDenied ||
        bluetoothConnect.isDenied ||
        location.isDenied) {
      setState(() {
        _errorMessage = 'Bluetooth and location permissions are required';
      });
      return;
    }
  }

  Future<void> _startScan() async {
    await _requestPermissions();

    final repository = ref.read(trainerRepositoryProvider);

    // Check if Bluetooth is available
    final isAvailable = await repository.isBluetoothAvailable();
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
    _scanSubscription = repository.scanForDevices().listen(
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

  Future<void> _connectToDevice(Trainer trainer) async {
    setState(() {
      _connectingTo = trainer;
    });

    final repository = ref.read(trainerRepositoryProvider);
    final success = await repository.connect(trainer);

    setState(() {
      _connectingTo = null;
    });

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to ${trainer.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final trainerData = ref.watch(trainerDataProvider);

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
              trainerData: trainerData.valueOrNull,
              onDisconnect: () {
                ref.read(trainerRepositoryProvider).disconnect();
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
                label: Text(_isScanning ? 'Stop Scan' : 'Scan for Trainers'),
              ),
            ),
          ),

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Text(
                      _isScanning
                          ? 'Searching for FTMS trainers...'
                          : 'Tap "Scan" to find trainers',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isConnecting = _connectingTo?.id == device.id;

                      return ListTile(
                        leading: const Icon(Icons.directions_bike),
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
                            : () => _connectToDevice(device),
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
  final VoidCallback onDisconnect;

  const _ConnectionStatusCard({
    required this.state,
    required this.trainerData,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    if (state == TrainerConnectionState.disconnected) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      ? 'Connected'
                      : state == TrainerConnectionState.connecting
                          ? 'Connecting...'
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
                  _DataDisplay(
                    label: 'Speed',
                    value: trainerData!.speed.toStringAsFixed(1),
                    unit: 'km/h',
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
