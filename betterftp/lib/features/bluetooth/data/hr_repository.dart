import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/ble_constants.dart';
import '../domain/hr_monitor.dart';
import 'ble_scanner_service.dart';

/// Repository for managing BLE Heart Rate monitor connections
class HrRepository {
  final BleScannerService _scannerService;

  BluetoothDevice? _connectedDevice;
  String? _connectedDeviceName;
  StreamSubscription? _hrSubscription;
  StreamSubscription? _disconnectSubscription;

  final _hrDataController = StreamController<HrData>.broadcast();
  final _connectionStateController =
      StreamController<HrConnectionState>.broadcast();

  Stream<HrData> get hrDataStream => _hrDataController.stream;
  Stream<HrConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  HrConnectionState _currentState = HrConnectionState.disconnected;
  HrConnectionState get currentState => _currentState;
  String? get connectedDeviceName => _connectedDeviceName;

  HrRepository(this._scannerService);

  /// Connect to a heart rate monitor discovered via scan
  Future<bool> connect(HrMonitor monitor) async {
    final device = _scannerService.getDevice(monitor.id);
    if (device == null) {
      developer.log('Device not found in cache: ${monitor.id}',
          name: 'HrRepository');
      return false;
    }

    return _connectToDevice(device, monitor.name);
  }

  /// Connect to an HR monitor by its BLE remote ID (no scan needed).
  /// Used for auto-reconnecting to a previously paired device.
  Future<bool> connectById(String id, String name) async {
    final device = BluetoothDevice.fromId(id);
    return _connectToDevice(device, name);
  }

  Future<bool> _connectToDevice(BluetoothDevice device, String name) async {
    try {
      _updateConnectionState(HrConnectionState.connecting);

      _connectedDevice = device;
      _connectedDeviceName = name;

      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );

      // Listen for unexpected disconnects
      _disconnectSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            _currentState == HrConnectionState.connected) {
          developer.log('Unexpected HR disconnect', name: 'HrRepository');
          _cleanup();
          _updateConnectionState(HrConnectionState.disconnected);
        }
      });

      final services = await device.discoverServices();

      // Find the Heart Rate service
      BluetoothCharacteristic? hrMeasurementChar;
      for (final service in services) {
        if (_uuidMatches(
            service.uuid.str, BleConstants.heartRateServiceShortUuid)) {
          for (final char in service.characteristics) {
            if (_uuidMatches(
                char.uuid.str, BleConstants.heartRateMeasurementShortUuid)) {
              hrMeasurementChar = char;
            }
          }
          break;
        }
      }

      if (hrMeasurementChar == null) {
        developer.log('Heart Rate Measurement characteristic not found',
            name: 'HrRepository');
        await device.disconnect();
        _updateConnectionState(HrConnectionState.disconnected);
        return false;
      }

      // Subscribe to Heart Rate Measurement notifications
      await hrMeasurementChar.setNotifyValue(true);
      _hrSubscription = hrMeasurementChar.onValueReceived.listen((data) {
        final hrData = _parseHeartRateMeasurement(data);
        _hrDataController.add(hrData);
      });

      _updateConnectionState(HrConnectionState.connected);
      return true;
    } catch (e, stackTrace) {
      developer.log('HR connection error: $e\n$stackTrace',
          name: 'HrRepository');
      _updateConnectionState(HrConnectionState.disconnected);
      return false;
    }
  }

  /// Parse Heart Rate Measurement characteristic data.
  ///
  /// Byte 0: Flags
  ///   - Bit 0: HR Value Format (0 = uint8, 1 = uint16)
  /// Byte 1 (or 1-2): Heart Rate value
  HrData _parseHeartRateMeasurement(List<int> data) {
    if (data.isEmpty) return HrData.zero();

    final flags = data[0];
    int heartRate = 0;

    if ((flags & 0x01) == 0) {
      // HR is uint8
      if (data.length > 1) {
        heartRate = data[1];
      }
    } else {
      // HR is uint16 LE
      if (data.length > 2) {
        heartRate = data[1] | (data[2] << 8);
      }
    }

    return HrData(
      heartRate: heartRate,
      timestamp: DateTime.now(),
    );
  }

  /// Disconnect from the HR monitor
  Future<void> disconnect() async {
    _updateConnectionState(HrConnectionState.disconnecting);

    _cleanup();

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        developer.log('HR disconnect error: $e', name: 'HrRepository');
      }
      _connectedDevice = null;
      _connectedDeviceName = null;
    }

    _updateConnectionState(HrConnectionState.disconnected);
  }

  void _cleanup() {
    _hrSubscription?.cancel();
    _hrSubscription = null;
    _disconnectSubscription?.cancel();
    _disconnectSubscription = null;
  }

  void _updateConnectionState(HrConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  /// Match a UUID string against a short 16-bit UUID, handling both
  /// short ("2a37") and full 128-bit ("00002a37-0000-1000-...") formats.
  static bool _uuidMatches(String uuid, String shortUuid) {
    final lower = uuid.toLowerCase();
    return lower == shortUuid || lower.startsWith('0000$shortUuid-');
  }

  /// Clean up resources
  void dispose() {
    _cleanup();
    _hrDataController.close();
    _connectionStateController.close();
  }
}

/// Provider for the HR repository
final hrRepositoryProvider = Provider<HrRepository>((ref) {
  final scannerService = ref.watch(bleScannerServiceProvider);
  final repository = HrRepository(scannerService);
  ref.onDispose(() => repository.dispose());
  return repository;
});

/// Provider for the HR connection state
final hrConnectionStateProvider = StreamProvider<HrConnectionState>((ref) {
  final repository = ref.watch(hrRepositoryProvider);
  return repository.connectionStateStream;
});

/// Provider for HR data stream
final hrDataProvider = StreamProvider<HrData>((ref) {
  final repository = ref.watch(hrRepositoryProvider);
  return repository.hrDataStream;
});

/// Provider for connected HR device name
final connectedHrNameProvider = Provider<String?>((ref) {
  // Re-evaluate when connection state changes
  ref.watch(hrConnectionStateProvider);
  return ref.watch(hrRepositoryProvider).connectedDeviceName;
});
