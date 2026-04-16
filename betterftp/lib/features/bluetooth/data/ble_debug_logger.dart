import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/ble_log_entry.dart';

/// Centralized capture of every GATT-level BLE operation in the app.
///
/// Subscribes to the global broadcast streams on [FlutterBluePlus.events] as
/// well as [FlutterBluePlus.adapterState] and [FlutterBluePlus.onScanResults].
/// Every event is converted into a [BleLogEntry] and pushed into an in-memory
/// ring buffer capped at [maxBytes].
///
/// Consumers never push entries directly — all capture happens here. The BLE
/// repositories (trainer, hr, scanner) are unaware of the logger.
class BleDebugLogger {
  /// Maximum buffer size before oldest entries are evicted.
  static const int maxBytes = 5 * 1024 * 1024;

  final Queue<BleLogEntry> _entries = Queue<BleLogEntry>();
  int _totalBytes = 0;

  final List<StreamSubscription<dynamic>> _subs = [];

  /// Per-device last-seen scan data — used to throttle duplicate advertisement
  /// log entries.
  final Map<String, _LastAdv> _lastAdvByDevice = {};

  BleDebugLogger() {
    _subscribe();
  }

  // ── Public API ────────────────────────────────────────────────────────

  int get entryCount => _entries.length;
  int get bufferBytes => _totalBytes;

  /// Remove all entries and reset the byte counter.
  void clear() {
    _entries.clear();
    _totalBytes = 0;
    _lastAdvByDevice.clear();
  }

  /// Format the entire buffer as a shareable text report.
  String formatReport() {
    final buf = StringBuffer();
    buf.writeln('=== BetterFTP BLE Debug Log ===');
    buf.writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}');
    buf.writeln('Platform: ${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion}');
    buf.writeln('Dart: ${Platform.version}');
    buf.writeln(
        'Entries: ${_entries.length} · Buffer: ${(_totalBytes / 1024).toStringAsFixed(1)} / ${maxBytes ~/ 1024} KB');
    buf.writeln('================================');
    buf.writeln();

    for (final e in _entries) {
      buf.write(e.format());
    }
    return buf.toString();
  }

  /// Write the report to a temp `.log` file and open the native share sheet.
  Future<void> shareLog() async {
    final report = formatReport();
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final filePath = '${tempDir.path}/betterftp_ble_$timestamp.log';
    final file = File(filePath);
    await file.writeAsString(report);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'text/plain')],
      ),
    );
  }

  /// Cancel all subscriptions. Called when the provider is disposed.
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  // ── Subscriptions ─────────────────────────────────────────────────────

  void _subscribe() {
    final events = FlutterBluePlus.events;

    _subs.add(events.onCharacteristicWritten.listen((e) {
      _pushFrame(
        source: 'char',
        direction: '→',
        deviceId: e.device.remoteId.str,
        message: _charLabel(e.characteristic),
        bytes: e.value,
        error: e.error,
      );
    }));

    _subs.add(events.onCharacteristicReceived.listen((e) {
      _pushFrame(
        source: 'char',
        direction: '←',
        deviceId: e.device.remoteId.str,
        message: _charLabel(e.characteristic),
        bytes: e.value,
        error: e.error,
      );
    }));

    _subs.add(events.onDescriptorWritten.listen((e) {
      _pushFrame(
        source: 'descriptor',
        direction: '→',
        deviceId: e.device.remoteId.str,
        message: _descLabel(e.descriptor),
        bytes: e.value,
        error: e.error,
      );
    }));

    _subs.add(events.onDescriptorRead.listen((e) {
      _pushFrame(
        source: 'descriptor',
        direction: '←',
        deviceId: e.device.remoteId.str,
        message: _descLabel(e.descriptor),
        bytes: e.value,
        error: e.error,
      );
    }));

    _subs.add(events.onConnectionStateChanged.listen((e) {
      _push(BleLogEntry(
        timestamp: DateTime.now(),
        kind: BleLogKind.event,
        source: 'connection',
        deviceId: e.device.remoteId.str,
        message: e.connectionState.name,
      ));
    }));

    _subs.add(events.onMtuChanged.listen((e) {
      _push(BleLogEntry(
        timestamp: DateTime.now(),
        kind: BleLogKind.event,
        source: 'mtu',
        deviceId: e.device.remoteId.str,
        message: '',
        data: {'mtu': e.mtu.toString()},
      ));
      _maybePushError(
        source: 'mtu',
        deviceId: e.device.remoteId.str,
        error: e.error,
      );
    }));

    _subs.add(events.onDiscoveredServices.listen((e) {
      _push(BleLogEntry(
        timestamp: DateTime.now(),
        kind: BleLogKind.event,
        source: 'discovery',
        deviceId: e.device.remoteId.str,
        message: '',
        data: {'services': _formatServices(e.services)},
      ));
      _maybePushError(
        source: 'discovery',
        deviceId: e.device.remoteId.str,
        error: e.error,
      );
    }));

    _subs.add(events.onServicesReset.listen((e) {
      _push(BleLogEntry(
        timestamp: DateTime.now(),
        kind: BleLogKind.event,
        source: 'discovery',
        deviceId: e.device.remoteId.str,
        message: 'services reset',
      ));
    }));

    _subs.add(events.onBondStateChanged.listen((e) {
      _push(BleLogEntry(
        timestamp: DateTime.now(),
        kind: BleLogKind.event,
        source: 'bond',
        deviceId: e.device.remoteId.str,
        message: '',
        data: {'bondState': e.bondState.name},
      ));
    }));

    _subs.add(events.onNameChanged.listen((e) {
      _push(BleLogEntry(
        timestamp: DateTime.now(),
        kind: BleLogKind.event,
        source: 'name',
        deviceId: e.device.remoteId.str,
        message: '',
        data: {'name': e.name ?? ''},
      ));
    }));

    _subs.add(events.onReadRssi.listen((e) {
      _push(BleLogEntry(
        timestamp: DateTime.now(),
        kind: BleLogKind.event,
        source: 'rssi',
        deviceId: e.device.remoteId.str,
        message: '',
        data: {'rssi': e.rssi.toString()},
      ));
      _maybePushError(
        source: 'rssi',
        deviceId: e.device.remoteId.str,
        error: e.error,
      );
    }));

    _subs.add(FlutterBluePlus.adapterState.listen((state) {
      _push(BleLogEntry(
        timestamp: DateTime.now(),
        kind: BleLogKind.event,
        source: 'adapter',
        message: state.name,
      ));
    }));

    _subs.add(FlutterBluePlus.onScanResults.listen(_handleScanResults));
  }

  // ── Scan throttling ───────────────────────────────────────────────────

  void _handleScanResults(List<ScanResult> results) {
    for (final r in results) {
      final id = r.device.remoteId.str;
      final adv = r.advertisementData;
      final payloadHash = _advPayloadHash(adv);
      final last = _lastAdvByDevice[id];
      final rssiDelta = last == null ? 999 : (last.rssi - r.rssi).abs();
      if (last != null &&
          rssiDelta < 5 &&
          last.payloadHash == payloadHash) {
        continue;
      }
      _lastAdvByDevice[id] = _LastAdv(r.rssi, payloadHash);

      _push(BleLogEntry(
        timestamp: DateTime.now(),
        kind: BleLogKind.event,
        source: 'scan',
        deviceId: id,
        message: '',
        data: {
          'advName': adv.advName,
          'serviceUuids':
              adv.serviceUuids.map((g) => g.str).toList().toString(),
          'rssi': r.rssi.toString(),
          'connectable': adv.connectable.toString(),
        },
      ));

      final advBytes = _flattenAdvPayload(adv);
      if (advBytes.isNotEmpty) {
        _push(BleLogEntry(
          timestamp: DateTime.now(),
          kind: BleLogKind.frame,
          source: 'scan',
          direction: 'adv',
          deviceId: id,
          message: '',
          bytes: advBytes,
        ));
      }
    }
  }

  int _advPayloadHash(AdvertisementData adv) {
    int h = adv.advName.hashCode;
    adv.manufacturerData.forEach((k, v) {
      h = h ^ k.hashCode ^ Object.hashAll(v);
    });
    adv.serviceData.forEach((k, v) {
      h = h ^ k.hashCode ^ Object.hashAll(v);
    });
    return h;
  }

  Uint8List _flattenAdvPayload(AdvertisementData adv) {
    final builder = BytesBuilder();
    adv.manufacturerData.forEach((manufacturerId, payload) {
      builder.addByte(manufacturerId & 0xFF);
      builder.addByte((manufacturerId >> 8) & 0xFF);
      builder.add(payload);
    });
    adv.serviceData.forEach((_, payload) {
      builder.add(payload);
    });
    return builder.toBytes();
  }

  // ── Ring buffer ───────────────────────────────────────────────────────

  void _pushFrame({
    required String source,
    required String direction,
    required String deviceId,
    required String message,
    required List<int> bytes,
    FbpError? error,
  }) {
    _push(BleLogEntry(
      timestamp: DateTime.now(),
      kind: BleLogKind.frame,
      source: source,
      direction: direction,
      deviceId: deviceId,
      message: message,
      bytes: Uint8List.fromList(bytes),
    ));
    _maybePushError(source: source, deviceId: deviceId, error: error);
  }

  void _maybePushError({
    required String source,
    required String deviceId,
    required FbpError? error,
  }) {
    if (error == null) return;
    _push(BleLogEntry(
      timestamp: DateTime.now(),
      kind: BleLogKind.error,
      source: source,
      deviceId: deviceId,
      message: '',
      data: {
        'errorCode': error.errorCode.toString(),
        'errorString': error.errorString,
        'platform': error.platform.name,
      },
    ));
  }

  void _push(BleLogEntry entry) {
    _entries.add(entry);
    _totalBytes += entry.estimatedSize();
    while (_totalBytes > maxBytes && _entries.isNotEmpty) {
      final removed = _entries.removeFirst();
      _totalBytes -= removed.estimatedSize();
      if (_totalBytes < 0) _totalBytes = 0;
    }
  }

  // ── Labels ────────────────────────────────────────────────────────────

  String _charLabel(BluetoothCharacteristic c) {
    final svc = c.serviceUuid.str;
    final chr = c.characteristicUuid.str;
    final friendly = _uuidName[chr.toLowerCase()];
    final base = '$svc/$chr';
    return friendly != null ? '$base ($friendly)' : base;
  }

  String _descLabel(BluetoothDescriptor d) {
    return '${d.characteristicUuid.str}/${d.descriptorUuid.str}';
  }

  String _formatServices(List<BluetoothService> services) {
    final parts = <String>[];
    for (final s in services) {
      final chars = s.characteristics.map((c) => c.uuid.str).join(',');
      parts.add('${s.uuid.str}:[$chars]');
    }
    return parts.join(' ');
  }

  /// Small lookup of the handful of FTMS/HR UUIDs this app works with.
  static const Map<String, String> _uuidName = {
    '2ad2': 'Indoor Bike Data',
    '2ad9': 'Control Point',
    '2a37': 'HR Measurement',
    '2a39': 'Heart Rate Control Point',
    '2acc': 'Fitness Machine Feature',
    '2ad8': 'Supported Power Range',
    '2a00': 'Device Name',
    '2a01': 'Appearance',
    '2902': 'CCCD',
  };
}

class _LastAdv {
  final int rssi;
  final int payloadHash;
  const _LastAdv(this.rssi, this.payloadHash);
}

/// Eagerly-initialised singleton. Construct on app start so captures begin
/// before the first scan or connect.
final bleDebugLoggerProvider = Provider<BleDebugLogger>((ref) {
  final logger = BleDebugLogger();
  ref.onDispose(logger.dispose);
  return logger;
});
