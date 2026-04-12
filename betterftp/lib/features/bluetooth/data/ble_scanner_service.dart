import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A discovered BLE device with its advertised service UUIDs
@immutable
class ScannedDevice {
  final String id;
  final String name;
  final List<String> serviceUuids;
  final int rssi;

  const ScannedDevice({
    required this.id,
    required this.name,
    this.serviceUuids = const [],
    this.rssi = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Shared BLE scanning service used by both trainer and HR monitor flows
class BleScannerService {
  StreamSubscription? _scanSubscription;
  StreamSubscription? _isScanningSubscription;
  final _discoveredDevices = <String, BluetoothDevice>{};

  /// Scan for BLE devices, returning a stream of discovered devices.
  /// Waits for the Bluetooth adapter to be ready before starting.
  Stream<List<ScannedDevice>> scanForDevices() {
    final devices = <String, ScannedDevice>{};
    final controller = StreamController<List<ScannedDevice>>();
    // `FlutterBluePlus.isScanning` is a re-emitting stream that immediately
    // pushes its latest value (`false`) to every new subscriber. We must not
    // treat that initial `false` as "scan stopped" — otherwise the controller
    // closes before the scan even starts on the second and subsequent scans.
    var sawScanning = false;

    // Cancel any lingering subscriptions from a previous scan before we
    // create new ones so we don't leak or cross-fire handlers.
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanningSubscription?.cancel();
    _isScanningSubscription = null;

    // Wait for adapter to be ready, then start scan.
    () async {
      try {
        final adapterState = await FlutterBluePlus.adapterState
            .firstWhere((s) => s == BluetoothAdapterState.on)
            .timeout(const Duration(seconds: 5));
        if (adapterState != BluetoothAdapterState.on) return;
        // If a previous scan is somehow still running (e.g. hot restart),
        // stop it first so startScan doesn't race against the old one.
        if (FlutterBluePlus.isScanningNow) {
          await FlutterBluePlus.stopScan();
        }
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 10),
        );
      } catch (e) {
        developer.log('Scan start error: $e', name: 'BleScannerService');
        if (!controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      }
    }();

    _scanSubscription = FlutterBluePlus.onScanResults.listen((scanResults) {
      for (final scanResult in scanResults) {
        final device = scanResult.device;
        if (device.platformName.isEmpty) continue;
        final id = device.remoteId.str;
        final ad = scanResult.advertisementData;

        developer.log(
          'Device: ${device.platformName} ($id)\n'
          '  serviceUuids: ${ad.serviceUuids.map((u) => u.str).toList()}\n'
          '  serviceData: ${ad.serviceData.map((k, v) => MapEntry(k.str, v))}\n'
          '  manufacturerData: ${ad.manufacturerData}\n'
          '  localName: ${ad.advName}\n'
          '  connectable: ${ad.connectable}\n'
          '  rssi: ${scanResult.rssi}',
          name: 'BleScannerService',
        );

        _discoveredDevices[id] = device;
        devices[id] = ScannedDevice(
          id: id,
          name: device.platformName,
          serviceUuids: ad.serviceUuids
              .map((u) => u.str.toLowerCase())
              .toList(),
          rssi: scanResult.rssi,
        );
      }
      if (!controller.isClosed) {
        controller.add(devices.values.toList());
      }
    });

    // Close the stream when scanning stops (timeout or manual stop), but
    // only after we've first seen it flip to `true`. This ignores the
    // initial re-emitted `false` from the FBP behavior-subject stream.
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (scanning) {
        sawScanning = true;
        return;
      }
      if (!sawScanning) return;
      if (!controller.isClosed) {
        controller.close();
      }
      _isScanningSubscription?.cancel();
      _isScanningSubscription = null;
    });

    controller.onCancel = () {
      _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanningSubscription?.cancel();
      _isScanningSubscription = null;
    };

    return controller.stream;
  }

  /// Stop the current scan
  Future<void> stopScan() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanningSubscription?.cancel();
    _isScanningSubscription = null;
    if (!FlutterBluePlus.isScanningNow) return;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  /// Check if Bluetooth is available and on
  Future<bool> isBluetoothAvailable() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  /// Get a cached BluetoothDevice by its ID
  BluetoothDevice? getDevice(String id) => _discoveredDevices[id];

  void dispose() {
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
  }
}

/// Provider for the shared BLE scanner service
final bleScannerServiceProvider = Provider<BleScannerService>((ref) {
  final service = BleScannerService();
  ref.onDispose(() => service.dispose());
  return service;
});
