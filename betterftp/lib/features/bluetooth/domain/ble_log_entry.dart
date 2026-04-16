import 'dart:typed_data';

/// Classification of a BLE log entry.
enum BleLogKind { frame, event, error }

/// A single line item in the BLE debug log.
///
/// Instances are immutable — the logger only ever appends to its ring buffer.
class BleLogEntry {
  /// When the event was captured.
  final DateTime timestamp;

  /// High-level classification.
  final BleLogKind kind;

  /// Origin layer (e.g. `char`, `descriptor`, `scan`, `connection`, `mtu`,
  /// `discovery`, `bond`, `adapter`, `name`, `rssi`).
  final String source;

  /// BLE remote identifier of the originating device, or `null` for
  /// adapter-level / global-scan events.
  final String? deviceId;

  /// Short human-readable summary (e.g. a UUID pair or a state transition).
  final String message;

  /// `→` for outbound writes, `←` for inbound reads/notifications, `adv` for
  /// advertisements. Null for non-frame events.
  final String? direction;

  /// Raw payload bytes for frames. Null for pure events.
  final Uint8List? bytes;

  /// Structured metadata for events (service lists, MTU, error codes, etc.).
  final Map<String, String>? data;

  const BleLogEntry({
    required this.timestamp,
    required this.kind,
    required this.source,
    required this.message,
    this.deviceId,
    this.direction,
    this.bytes,
    this.data,
  });

  /// Format the entry as a multi-line text block suitable for inclusion in
  /// the shareable `.log` file.
  String format() {
    final buf = StringBuffer();
    final ts = timestamp.toUtc().toIso8601String();
    final label = switch (kind) {
      BleLogKind.frame => 'FRAME',
      BleLogKind.event => 'EVENT',
      BleLogKind.error => 'ERROR',
    };

    buf.write('[$ts] $label $source');
    if (direction != null) {
      buf.write(' $direction');
    }
    if (deviceId != null) {
      buf.write(' device=$deviceId');
    }
    if (message.isNotEmpty) {
      buf.write(' $message');
    }
    buf.writeln();

    if (bytes != null && bytes!.isNotEmpty) {
      buf.writeln('    hex: ${_hex(bytes!)}');
    }

    if (data != null && data!.isNotEmpty) {
      for (final entry in data!.entries) {
        buf.writeln('    ${entry.key}: ${entry.value}');
      }
    }

    return buf.toString();
  }

  /// Approximate byte cost of this entry for ring-buffer accounting.
  int estimatedSize() {
    int size = 64; // timestamp + enum + overhead
    size += source.length;
    size += message.length;
    if (deviceId != null) size += deviceId!.length;
    if (direction != null) size += direction!.length;
    if (bytes != null) size += bytes!.length;
    if (data != null) {
      for (final entry in data!.entries) {
        size += entry.key.length + entry.value.length + 4;
      }
    }
    return size;
  }

  static String _hex(Uint8List bytes) {
    final sb = StringBuffer();
    for (int i = 0; i < bytes.length; i++) {
      if (i > 0) sb.write(' ');
      sb.write(bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return sb.toString();
  }
}
