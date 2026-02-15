import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trainer.dart';

/// Repository for managing FTMS trainer connections
class TrainerRepository {
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;

  final _trainerDataController = StreamController<TrainerData>.broadcast();
  final _connectionStateController =
      StreamController<TrainerConnectionState>.broadcast();

  Stream<TrainerData> get trainerDataStream => _trainerDataController.stream;
  Stream<TrainerConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  TrainerConnectionState _currentState = TrainerConnectionState.disconnected;
  TrainerConnectionState get currentState => _currentState;

  /// Scan for FTMS-compatible devices
  Stream<List<Trainer>> scanForDevices() {
    final devices = <String, Trainer>{};
    final controller = StreamController<List<Trainer>>();

    // Start scanning
    FTMS.scanForBluetoothDevices();

    // Listen to scan results
    _scanSubscription = FTMS.scanResults.listen((scanResults) {
      for (final scanResult in scanResults) {
        final device = scanResult.device;
        final trainer = Trainer(
          id: device.remoteId.str,
          name: device.platformName.isNotEmpty
              ? device.platformName
              : 'Unknown Device',
        );
        devices[trainer.id] = trainer;
      }
      controller.add(devices.values.toList());
    });

    controller.onCancel = () {
      _scanSubscription?.cancel();
      _scanSubscription = null;
    };

    return controller.stream;
  }

  /// Stop scanning for devices
  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// Check if Bluetooth is available and on
  Future<bool> isBluetoothAvailable() async {
    return await FTMS.isBluetoothEnabled();
  }

  /// Connect to a trainer device
  Future<bool> connect(Trainer trainer) async {
    try {
      _updateConnectionState(TrainerConnectionState.connecting);

      // Find the device from scan results
      final device = await _findDevice(trainer.id);
      if (device == null) {
        _updateConnectionState(TrainerConnectionState.disconnected);
        return false;
      }

      _connectedDevice = device;

      // Connect to the FTMS device
      await FTMS.connectToFTMSDevice(device);

      // Subscribe to device data
      await FTMS.useDeviceDataCharacteristic(
        device,
        (data) => _handleDeviceData(data),
      );

      _updateConnectionState(TrainerConnectionState.connected);
      return true;
    } catch (e) {
      developer.log('Connection error: $e', name: 'TrainerRepository');
      _updateConnectionState(TrainerConnectionState.disconnected);
      return false;
    }
  }

  /// Find a device by ID from a fresh scan
  Future<BluetoothDevice?> _findDevice(String deviceId) async {
    final completer = Completer<BluetoothDevice?>();

    // Start scanning
    await FTMS.scanForBluetoothDevices();

    StreamSubscription? subscription;
    Timer? timeout;

    subscription = FTMS.scanResults.listen((scanResults) {
      for (final scanResult in scanResults) {
        if (scanResult.device.remoteId.str == deviceId) {
          timeout?.cancel();
          subscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(scanResult.device);
          }
          return;
        }
      }
    });

    // Timeout after 10 seconds
    timeout = Timer(const Duration(seconds: 10), () {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// Handle incoming data from the trainer
  void _handleDeviceData(DeviceData data) {
    // Extract power, cadence, and speed from device data parameters
    final powerParam =
        data.getParameterValueByName(DeviceDataParameterName.instPower);
    final cadenceParam =
        data.getParameterValueByName(DeviceDataParameterName.instCadence);
    final speedParam =
        data.getParameterValueByName(DeviceDataParameterName.instSpeed);

    final trainerData = TrainerData(
      power: powerParam?.value.toInt() ?? 0,
      cadence: cadenceParam?.value.toInt() ?? 0,
      speed: speedParam?.value.toDouble() ?? 0.0,
      timestamp: DateTime.now(),
    );
    _trainerDataController.add(trainerData);
  }

  /// Set target power (ERG mode)
  Future<bool> setTargetPower(int watts) async {
    if (_connectedDevice == null ||
        _currentState != TrainerConnectionState.connected) {
      return false;
    }

    try {
      // Request control first, then set target power
      await FTMS.writeMachineControlPointCharacteristic(
        _connectedDevice!,
        MachineControlPoint.requestControl(),
      );

      await FTMS.writeMachineControlPointCharacteristic(
        _connectedDevice!,
        MachineControlPoint.setTargetPower(power: watts),
      );
      return true;
    } catch (e) {
      developer.log('Error setting target power: $e', name: 'TrainerRepository');
      return false;
    }
  }

  /// Disconnect from the trainer
  Future<void> disconnect() async {
    _updateConnectionState(TrainerConnectionState.disconnecting);

    if (_connectedDevice != null) {
      try {
        await FTMS.disconnectFromFTMSDevice(_connectedDevice!);
      } catch (e) {
        developer.log('Disconnect error: $e', name: 'TrainerRepository');
      }
      _connectedDevice = null;
    }

    _updateConnectionState(TrainerConnectionState.disconnected);
  }

  void _updateConnectionState(TrainerConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  /// Clean up resources
  void dispose() {
    _scanSubscription?.cancel();
    _trainerDataController.close();
    _connectionStateController.close();
  }
}

/// Provider for the trainer repository
final trainerRepositoryProvider = Provider<TrainerRepository>((ref) {
  final repository = TrainerRepository();
  ref.onDispose(() => repository.dispose());
  return repository;
});

/// Provider for the current connection state
final connectionStateProvider = StreamProvider<TrainerConnectionState>((ref) {
  final repository = ref.watch(trainerRepositoryProvider);
  return repository.connectionStateStream;
});

/// Provider for trainer data stream
final trainerDataProvider = StreamProvider<TrainerData>((ref) {
  final repository = ref.watch(trainerRepositoryProvider);
  return repository.trainerDataStream;
});
