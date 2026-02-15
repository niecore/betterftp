import 'package:flutter/foundation.dart';

@immutable
class RampTestConfig {
  final int startPower; // Watts
  final int increment; // Watts per stage
  final int stageDuration; // Seconds per stage
  final int warmupDuration; // Seconds
  final int warmupPower; // Watts

  const RampTestConfig({
    this.startPower = 100,
    this.increment = 20,
    this.stageDuration = 60,
    this.warmupDuration = 300, // 5 minutes
    this.warmupPower = 100,
  });
}
