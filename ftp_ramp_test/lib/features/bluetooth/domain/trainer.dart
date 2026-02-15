import 'package:flutter/foundation.dart';

enum TrainerConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

@immutable
class Trainer {
  final String id;
  final String name;
  final TrainerConnectionState connectionState;

  const Trainer({
    required this.id,
    required this.name,
    this.connectionState = TrainerConnectionState.disconnected,
  });

  Trainer copyWith({
    String? id,
    String? name,
    TrainerConnectionState? connectionState,
  }) {
    return Trainer(
      id: id ?? this.id,
      name: name ?? this.name,
      connectionState: connectionState ?? this.connectionState,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Trainer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          connectionState == other.connectionState;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ connectionState.hashCode;

  @override
  String toString() => 'Trainer(id: $id, name: $name, state: $connectionState)';
}

@immutable
class TrainerData {
  final int power; // Watts
  final int cadence; // RPM
  final double speed; // km/h
  final DateTime timestamp;

  const TrainerData({
    required this.power,
    required this.cadence,
    required this.speed,
    required this.timestamp,
  });

  factory TrainerData.zero() => TrainerData(
        power: 0,
        cadence: 0,
        speed: 0,
        timestamp: DateTime.now(),
      );

  @override
  String toString() =>
      'TrainerData(power: ${power}W, cadence: ${cadence}rpm, speed: ${speed.toStringAsFixed(1)}km/h)';
}
