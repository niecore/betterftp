import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/ftms_constants.dart';
import '../domain/trainer.dart';
import 'ble_scanner_service.dart';

/// Repository for managing FTMS trainer connections.
///
/// Robustness features:
/// - Retry with exponential back-off for control-point writes
/// - Control-point response indication parsing
/// - FTMS Start/Resume command after requesting control
/// - Data-staleness watchdog (emits on [dataStaleStream])
class TrainerRepository {
  final BleScannerService _scannerService;

  BluetoothDevice? _connectedDevice;
  String? _connectedDeviceName;
  StreamSubscription? _bikeDataSubscription;
  StreamSubscription? _disconnectSubscription;
  StreamSubscription? _controlPointSubscription;

  /// Cached FTMS characteristics after service discovery
  BluetoothCharacteristic? _bikeDataChar;
  BluetoothCharacteristic? _controlPointChar;
  bool _hasControl = false;

  // ── Control-point response handling ──────────────────────────────────
  /// Completer for the most recent control-point write, resolved when the
  /// trainer sends back a response indication.
  Completer<int>? _cpResponseCompleter;

  // ── Data watchdog ────────────────────────────────────────────────────
  Timer? _dataWatchdog;
  bool _isDataStale = false;
  final _dataStaleController = StreamController<bool>.broadcast();

  // ── Public streams ───────────────────────────────────────────────────
  final _trainerDataController = StreamController<TrainerData>.broadcast();
  final _connectionStateController =
      StreamController<TrainerConnectionState>.broadcast();

  Stream<TrainerData> get trainerDataStream => _trainerDataController.stream;
  Stream<TrainerConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Emits `true` when no BLE data has been received for
  /// [FtmsConstants.dataWatchdogTimeoutSeconds], and `false` when data
  /// resumes.
  Stream<bool> get dataStaleStream => _dataStaleController.stream;
  bool get isDataStale => _isDataStale;

  TrainerConnectionState _currentState = TrainerConnectionState.disconnected;
  TrainerConnectionState get currentState => _currentState;
  String? get connectedDeviceName => _connectedDeviceName;

  TrainerRepository(this._scannerService);

  // ═══════════════════════════════════════════════════════════════════════
  // Connection
  // ═══════════════════════════════════════════════════════════════════════

  /// Connect to a trainer device discovered via scan.
  Future<bool> connect(Trainer trainer) async {
    _scannerService.stopScan();

    final device = _scannerService.getDevice(trainer.id);
    if (device == null) {
      developer.log('Device not found in cache: ${trainer.id}',
          name: 'TrainerRepository');
      return false;
    }

    return _connectToDevice(device, trainer.name);
  }

  /// Connect to a trainer by its BLE remote ID (no scan needed).
  /// Used for auto-reconnecting to a previously paired device.
  Future<bool> connectById(String id, String name) async {
    final device = BluetoothDevice.fromId(id);
    return _connectToDevice(device, name);
  }

  Future<bool> _connectToDevice(BluetoothDevice device, String name) async {
    // Tear down any existing connection first — otherwise the previous
    // device's notification subscription keeps firing into the same data
    // stream and consumers see frames from both trainers interleaved.
    if (_connectedDevice != null || _bikeDataSubscription != null) {
      final old = _connectedDevice;
      _cleanup();
      _connectedDevice = null;
      _connectedDeviceName = null;
      if (old != null) {
        try {
          await old.disconnect();
        } catch (e) {
          developer.log('Pre-connect teardown disconnect error: $e',
              name: 'TrainerRepository');
        }
      }
    }

    try {
      _updateConnectionState(TrainerConnectionState.connecting);

      _connectedDevice = device;
      _connectedDeviceName = name;

      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );

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

      developer.log(
        'Discovered ${services.length} services:',
        name: 'TrainerRepository',
      );
      for (final service in services) {
        developer.log(
          '  Service: ${service.uuid.str}',
          name: 'TrainerRepository',
        );
        for (final char in service.characteristics) {
          developer.log(
            '    Char: ${char.uuid.str} (props: ${char.properties})',
            name: 'TrainerRepository',
          );
        }
      }

      // Find the FTMS service and cache characteristics
      _bikeDataChar = null;
      _controlPointChar = null;
      for (final service in services) {
        if (_uuidMatches(
            service.uuid.str, FtmsConstants.ftmsServiceShortUuid)) {
          for (final char in service.characteristics) {
            if (_uuidMatches(
                char.uuid.str, FtmsConstants.indoorBikeDataShortUuid)) {
              _bikeDataChar = char;
            } else if (_uuidMatches(
                char.uuid.str, FtmsConstants.controlPointShortUuid)) {
              _controlPointChar = char;
            }
          }
          break;
        }
      }

      developer.log(
        'FTMS lookup result: bikeDataChar=${_bikeDataChar != null}, '
        'controlPointChar=${_controlPointChar != null}',
        name: 'TrainerRepository',
      );

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
        _resetDataWatchdog();
        final trainerData = _parseIndoorBikeData(data);
        _trainerDataController.add(trainerData);
      });

      // Start the data watchdog now that we're receiving data
      _resetDataWatchdog();

      // Subscribe to Control Point indications and request control
      _hasControl = false;
      if (_controlPointChar != null) {
        await _controlPointChar!.setNotifyValue(true);
        _controlPointSubscription =
            _controlPointChar!.onValueReceived.listen(_handleControlPointResponse);

        await _requestControlAndStart();
      }

      _updateConnectionState(TrainerConnectionState.connected);
      return true;
    } catch (e, stackTrace) {
      developer.log('Connection error: $e\n$stackTrace',
          name: 'TrainerRepository');
      _updateConnectionState(TrainerConnectionState.disconnected);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FTMS Control
  // ═══════════════════════════════════════════════════════════════════════

  /// Request control of the trainer and send Start/Resume.
  Future<bool> _requestControlAndStart() async {
    // Step 1: Request Control (0x00)
    final controlResult = await _writeControlPointWithRetry(
      [FtmsConstants.requestControlOpCode],
      'Request Control',
    );
    if (!controlResult) {
      developer.log('Failed to acquire FTMS control', name: 'TrainerRepository');
      _hasControl = false;
      return false;
    }
    _hasControl = true;
    developer.log('FTMS control acquired', name: 'TrainerRepository');

    // Step 2: Start/Resume (0x07)
    final startResult = await _writeControlPointWithRetry(
      [FtmsConstants.startResumeOpCode],
      'Start/Resume',
    );
    if (!startResult) {
      // Some trainers don't support Start/Resume explicitly — log but don't
      // treat as fatal. The trainer may still accept Set Target Power.
      developer.log(
        'Start/Resume not acknowledged (trainer may auto-start)',
        name: 'TrainerRepository',
      );
    } else {
      developer.log('FTMS Start/Resume sent', name: 'TrainerRepository');
    }

    return true;
  }

  /// Set target power (ERG mode).
  ///
  /// Returns `true` if the command was acknowledged by the trainer.
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

    // Re-request control if we lost it (e.g. after reconnect)
    if (!_hasControl) {
      final ok = await _requestControlAndStart();
      if (!ok) return false;
    }

    // Set target power: opcode + 2 bytes little-endian watts
    final lowByte = watts & 0xFF;
    final highByte = (watts >> 8) & 0xFF;
    final success = await _writeControlPointWithRetry(
      [FtmsConstants.setTargetPowerOpCode, lowByte, highByte],
      'Set Target Power ${watts}W',
    );

    if (!success) {
      // Mark control as lost so we re-request on next attempt
      _hasControl = false;
    }

    return success;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Write retry
  // ═══════════════════════════════════════════════════════════════════════

  /// Write to the control point with retry and response-indication parsing.
  ///
  /// Returns `true` if the trainer acknowledged with [FtmsConstants.resultSuccess],
  /// or if the write completed without a GATT error (for trainers that don't
  /// send indications for every command).
  Future<bool> _writeControlPointWithRetry(
    List<int> data,
    String label,
  ) async {
    for (int attempt = 0;
        attempt < FtmsConstants.maxWriteRetries;
        attempt++) {
      try {
        // Prepare to receive the response indication
        _cpResponseCompleter = Completer<int>();

        await _controlPointChar!.write(data, withoutResponse: false);

        // Wait for the indication with a timeout
        final resultCode = await _cpResponseCompleter!.future
            .timeout(const Duration(seconds: 3), onTimeout: () {
          // Timeout waiting for indication — treat as success since some
          // trainers don't send indications for all commands.
          developer.log(
            '$label: no indication received (timeout), assuming OK',
            name: 'TrainerRepository',
          );
          return FtmsConstants.resultSuccess;
        });

        if (resultCode == FtmsConstants.resultSuccess) {
          return true;
        }

        developer.log(
          '$label: trainer responded with result code $resultCode '
          '(attempt ${attempt + 1}/${FtmsConstants.maxWriteRetries})',
          name: 'TrainerRepository',
        );
      } catch (e) {
        developer.log(
          '$label: write error (attempt ${attempt + 1}/'
          '${FtmsConstants.maxWriteRetries}): $e',
          name: 'TrainerRepository',
        );
      } finally {
        _cpResponseCompleter = null;
      }

      // Back off before retrying
      if (attempt < FtmsConstants.maxWriteRetries - 1) {
        await Future.delayed(
          FtmsConstants.retryBaseDelay * (attempt + 1),
        );
      }
    }

    developer.log('$label: all retries exhausted', name: 'TrainerRepository');
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Control-point response parsing
  // ═══════════════════════════════════════════════════════════════════════

  /// Handle a Control Point response indication from the trainer.
  ///
  /// Format: [0x80, requestedOpCode, resultCode]
  void _handleControlPointResponse(List<int> data) {
    if (data.length < 3 || data[0] != FtmsConstants.responseOpCode) {
      developer.log(
        'Unexpected control point data: $data',
        name: 'TrainerRepository',
      );
      return;
    }

    final requestedOp = data[1];
    final resultCode = data[2];

    developer.log(
      'Control Point response: op=0x${requestedOp.toRadixString(16)}, '
      'result=0x${resultCode.toRadixString(16)}',
      name: 'TrainerRepository',
    );

    // If we have a pending completer, resolve it
    if (_cpResponseCompleter != null && !_cpResponseCompleter!.isCompleted) {
      _cpResponseCompleter!.complete(resultCode);
    }

    // If control was revoked, mark it
    if (resultCode == FtmsConstants.resultControlNotPermitted) {
      _hasControl = false;
      developer.log(
        'Control revoked by trainer',
        name: 'TrainerRepository',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Data watchdog
  // ═══════════════════════════════════════════════════════════════════════

  /// Reset the watchdog timer. Called every time Indoor Bike Data arrives.
  void _resetDataWatchdog() {
    _dataWatchdog?.cancel();

    if (_isDataStale) {
      _isDataStale = false;
      _dataStaleController.add(false);
      developer.log('BLE data resumed', name: 'TrainerRepository');
    }

    _dataWatchdog = Timer(
      Duration(seconds: FtmsConstants.dataWatchdogTimeoutSeconds),
      () {
        _isDataStale = true;
        _dataStaleController.add(true);
        developer.log(
          'BLE data stale (no data for '
          '${FtmsConstants.dataWatchdogTimeoutSeconds}s)',
          name: 'TrainerRepository',
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Indoor Bike Data parsing
  // ═══════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════
  // Disconnect & cleanup
  // ═══════════════════════════════════════════════════════════════════════

  /// Disconnect from the trainer.
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
      _connectedDeviceName = null;
    }

    _updateConnectionState(TrainerConnectionState.disconnected);
  }

  void _cleanup() {
    _bikeDataSubscription?.cancel();
    _bikeDataSubscription = null;
    _disconnectSubscription?.cancel();
    _disconnectSubscription = null;
    _controlPointSubscription?.cancel();
    _controlPointSubscription = null;
    _bikeDataChar = null;
    _controlPointChar = null;
    _hasControl = false;
    _cpResponseCompleter = null;
    _dataWatchdog?.cancel();
    _dataWatchdog = null;
    if (_isDataStale) {
      _isDataStale = false;
      _dataStaleController.add(false);
    }
  }

  void _updateConnectionState(TrainerConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  /// Match a UUID string against a short 16-bit UUID, handling both
  /// short ("2ad2") and full 128-bit ("00002ad2-0000-1000-...") formats.
  static bool _uuidMatches(String uuid, String shortUuid) {
    final lower = uuid.toLowerCase();
    return lower == shortUuid || lower.startsWith('0000$shortUuid-');
  }

  /// Clean up resources.
  void dispose() {
    _cleanup();
    _trainerDataController.close();
    _connectionStateController.close();
    _dataStaleController.close();
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

/// Provider for connected trainer device name
final connectedTrainerNameProvider = Provider<String?>((ref) {
  // Re-evaluate when connection state changes
  ref.watch(connectionStateProvider);
  return ref.watch(trainerRepositoryProvider).connectedDeviceName;
});

/// Provider for data staleness
final trainerDataStaleProvider = StreamProvider<bool>((ref) {
  final repository = ref.watch(trainerRepositoryProvider);
  return repository.dataStaleStream;
});
