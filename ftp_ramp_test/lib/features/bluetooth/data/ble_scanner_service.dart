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

  const ScannedDevice({
    required this.id,
    required this.name,
    this.serviceUuids = const [],
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
  final _discoveredDevices = <String, BluetoothDevice>{};

  /// Scan for BLE devices, returning a stream of discovered devices
  Stream<List<ScannedDevice>> scanForDevices() {
    final devices = <String, ScannedDevice>{};
    final controller = StreamController<List<ScannedDevice>>();

    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
    );

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
        );
      }
      controller.add(devices.values.toList());
    });

    controller.onCancel = () {
      _scanSubscription?.cancel();
      _scanSubscription = null;
    };

    return controller.stream;
  }

  /// Stop the current scan
  Future<void> stopScan() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
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
  }
}

/// Provider for the shared BLE scanner service
final bleScannerServiceProvider = Provider<BleScannerService>((ref) {
  final service = BleScannerService();
  ref.onDispose(() => service.dispose());
  return service;
});
