import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/ftms_constants.dart';
import '../domain/trainer.dart';
import 'ble_scanner_service.dart';

/// Repository for managing FTMS trainer connections
class TrainerRepository {
  final BleScannerService _scannerService;

  BluetoothDevice? _connectedDevice;
  StreamSubscription? _bikeDataSubscription;
  StreamSubscription? _disconnectSubscription;

  /// Cached FTMS characteristics after service discovery
  BluetoothCharacteristic? _bikeDataChar;
  BluetoothCharacteristic? _controlPointChar;

  final _trainerDataController = StreamController<TrainerData>.broadcast();
  final _connectionStateController =
      StreamController<TrainerConnectionState>.broadcast();

  Stream<TrainerData> get trainerDataStream => _trainerDataController.stream;
  Stream<TrainerConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  TrainerConnectionState _currentState = TrainerConnectionState.disconnected;
  TrainerConnectionState get currentState => _currentState;

  TrainerRepository(this._scannerService);

  /// Connect to a trainer device
  Future<bool> connect(Trainer trainer) async {
    try {
      _updateConnectionState(TrainerConnectionState.connecting);

      _scannerService.stopScan();

      final device = _scannerService.getDevice(trainer.id);
      if (device == null) {
        developer.log('Device not found in cache: ${trainer.id}',
            name: 'TrainerRepository');
        _updateConnectionState(TrainerConnectionState.disconnected);
        return false;
      }

      _connectedDevice = device;

      await device.connect(timeout: const Duration(seconds: 15));

      // Listen for unexpected disconnects
      _disconnectSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            _currentState == TrainerConnectionState.connected) {
          developer.log('Unexpected disconnect', name: 'TrainerRepository');
          _cleanup();
          _updateConnectionState(TrainerConnectionState.disconnected);
        }
      });

      final services = await device.discoverServices();

      // Find the FTMS service and cache characteristics
      _bikeDataChar = null;
      _controlPointChar = null;
      for (final service in services) {
        if (service.uuid.str.toLowerCase() ==
            FtmsConstants.ftmsServiceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            final uuid = char.uuid.str.toLowerCase();
            if (uuid == FtmsConstants.indoorBikeDataUuid.toLowerCase()) {
              _bikeDataChar = char;
            } else if (uuid == FtmsConstants.controlPointUuid.toLowerCase()) {
              _controlPointChar = char;
            }
          }
          break;
        }
      }

      if (_bikeDataChar == null) {
        developer.log('FTMS Indoor Bike Data characteristic not found',
            name: 'TrainerRepository');
        await device.disconnect();
        _updateConnectionState(TrainerConnectionState.disconnected);
        return false;
      }

      // Subscribe to Indoor Bike Data notifications
      await _bikeDataChar!.setNotifyValue(true);
      _bikeDataSubscription = _bikeDataChar!.onValueReceived.listen((data) {
        final trainerData = _parseIndoorBikeData(data);
        _trainerDataController.add(trainerData);
      });

      _updateConnectionState(TrainerConnectionState.connected);
      return true;
    } catch (e) {
      developer.log('Connection error: $e', name: 'TrainerRepository');
      _updateConnectionState(TrainerConnectionState.disconnected);
      return false;
    }
  }

  /// Parse raw Indoor Bike Data characteristic bytes into TrainerData.
  ///
  /// The Indoor Bike Data characteristic (0x2AD2) layout:
  /// - Bytes 0-1: Flags (16-bit, little-endian)
  /// - Remaining bytes: optional fields based on flag bits
  ///
  /// Flag bits (per FTMS spec, note bit 0 is inverted):
  /// - Bit 0: 0 = Instantaneous Speed present (2 bytes, uint16, 0.01 km/h)
  /// - Bit 1: Average Speed present (2 bytes)
  /// - Bit 2: Instantaneous Cadence present (2 bytes, uint16, 0.5 rpm)
  /// - Bit 3: Average Cadence present (2 bytes)
  /// - Bit 4: Total Distance present (3 bytes)
  /// - Bit 5: Resistance Level present (2 bytes)
  /// - Bit 6: Instantaneous Power present (2 bytes, sint16, watts)
  /// - Bit 7: Average Power present (2 bytes)
  TrainerData _parseIndoorBikeData(List<int> data) {
    if (data.length < 2) return TrainerData.zero();

    final flags = data[0] | (data[1] << 8);
    int offset = 2;

    int power = 0;
    int cadence = 0;

    // Bit 0 inverted: if bit 0 is 0, speed is present (2 bytes)
    if ((flags & 0x01) == 0) {
      offset += 2;
    }

    // Bit 1: Average Speed (2 bytes)
    if ((flags & 0x02) != 0) {
      offset += 2;
    }

    // Bit 2: Instantaneous Cadence (2 bytes, 0.5 rpm resolution)
    if ((flags & 0x04) != 0) {
      if (offset + 2 <= data.length) {
        final rawCadence = data[offset] | (data[offset + 1] << 8);
        cadence = rawCadence ~/ 2;
      }
      offset += 2;
    }

    // Bit 3: Average Cadence (2 bytes)
    if ((flags & 0x08) != 0) {
      offset += 2;
    }

    // Bit 4: Total Distance (3 bytes)
    if ((flags & 0x10) != 0) {
      offset += 3;
    }

    // Bit 5: Resistance Level (2 bytes)
    if ((flags & 0x20) != 0) {
      offset += 2;
    }

    // Bit 6: Instantaneous Power (2 bytes, sint16)
    if ((flags & 0x40) != 0) {
      if (offset + 2 <= data.length) {
        power = data[offset] | (data[offset + 1] << 8);
        // Handle signed 16-bit
        if (power >= 0x8000) power -= 0x10000;
      }
      offset += 2;
    }

    return TrainerData(
      power: power,
      cadence: cadence,
      timestamp: DateTime.now(),
    );
  }

  /// Set target power (ERG mode)
  Future<bool> setTargetPower(int watts) async {
    if (_connectedDevice == null ||
        _currentState != TrainerConnectionState.connected) {
      return false;
    }

    if (_controlPointChar == null) {
      developer.log('Control Point characteristic not found',
          name: 'TrainerRepository');
      return false;
    }

    try {
      // Request control first
      await _controlPointChar!
          .write([FtmsConstants.requestControlOpCode], withoutResponse: false);

      // Set target power: opcode + 2 bytes little-endian watts
      final lowByte = watts & 0xFF;
      final highByte = (watts >> 8) & 0xFF;
      await _controlPointChar!.write(
        [FtmsConstants.setTargetPowerOpCode, lowByte, highByte],
        withoutResponse: false,
      );
      return true;
    } catch (e) {
      developer.log('Error setting target power: $e',
          name: 'TrainerRepository');
      return false;
    }
  }

  /// Disconnect from the trainer
  Future<void> disconnect() async {
    _updateConnectionState(TrainerConnectionState.disconnecting);

    _cleanup();

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        developer.log('Disconnect error: $e', name: 'TrainerRepository');
      }
      _connectedDevice = null;
    }

    _updateConnectionState(TrainerConnectionState.disconnected);
  }

  void _cleanup() {
    _bikeDataSubscription?.cancel();
    _bikeDataSubscription = null;
    _disconnectSubscription?.cancel();
    _disconnectSubscription = null;
    _bikeDataChar = null;
    _controlPointChar = null;
  }

  void _updateConnectionState(TrainerConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  /// Clean up resources
  void dispose() {
    _cleanup();
    _trainerDataController.close();
    _connectionStateController.close();
  }
}

/// Provider for the trainer repository
final trainerRepositoryProvider = Provider<TrainerRepository>((ref) {
  final scannerService = ref.watch(bleScannerServiceProvider);
  final repository = TrainerRepository(scannerService);
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
