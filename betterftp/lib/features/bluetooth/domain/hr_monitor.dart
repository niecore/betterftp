import 'package:flutter/foundation.dart';

enum HrConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

@immutable
class HrMonitor {
  final String id;
  final String name;
  final HrConnectionState connectionState;

  const HrMonitor({
    required this.id,
    required this.name,
    this.connectionState = HrConnectionState.disconnected,
  });

  HrMonitor copyWith({
    String? id,
    String? name,
    HrConnectionState? connectionState,
  }) {
    return HrMonitor(
      id: id ?? this.id,
      name: name ?? this.name,
      connectionState: connectionState ?? this.connectionState,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HrMonitor &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          connectionState == other.connectionState;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ connectionState.hashCode;

  @override
  String toString() =>
      'HrMonitor(id: $id, name: $name, state: $connectionState)';
}

@immutable
class HrData {
  final int heartRate; // BPM
  final DateTime timestamp;

  const HrData({
    required this.heartRate,
    required this.timestamp,
  });

  factory HrData.zero() => HrData(
        heartRate: 0,
        timestamp: DateTime.now(),
      );

  @override
  String toString() => 'HrData(heartRate: ${heartRate}bpm)';
}
