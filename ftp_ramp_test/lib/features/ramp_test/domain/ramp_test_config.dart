import 'package:flutter/foundation.dart';

import 'ramp_test_state.dart';

@immutable
class RampTestConfig {
  final int startPower; // Watts
  final int increment; // Watts per stage
  final int stageDuration; // Seconds per stage
  final int warmupDuration; // Seconds
  final int warmupPower; // Watts
  final int testDuration; // Seconds (0 = unlimited/ramp)

  const RampTestConfig({
    this.startPower = 100,
    this.increment = 20,
    this.stageDuration = 60,
    this.warmupDuration = 300, // 5 minutes
    this.warmupPower = 100,
    this.testDuration = 0,
  });

  const RampTestConfig.twentyMin()
      : startPower = 150,
        increment = 0,
        stageDuration = 0,
        warmupDuration = 300,
        warmupPower = 100,
        testDuration = 1200; // 20 minutes

  const RampTestConfig.eightMin()
      : startPower = 150,
        increment = 0,
        stageDuration = 0,
        warmupDuration = 300,
        warmupPower = 100,
        testDuration = 480; // 8 minutes

  factory RampTestConfig.forProtocol(TestProtocol protocol) {
    switch (protocol) {
      case TestProtocol.ramp:
        return const RampTestConfig();
      case TestProtocol.twentyMin:
        return const RampTestConfig.twentyMin();
      case TestProtocol.eightMin:
        return const RampTestConfig.eightMin();
    }
  }
}
