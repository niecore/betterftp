import 'ramp_test_state.dart';

class FtpCalculator {
  FtpCalculator._();

  /// Compute the best rolling 1-minute average power from a list of readings.
  /// Returns 0 if there are fewer than 60 seconds of data.
  static double bestOneMinuteAverage(List<PowerReading> readings) {
    if (readings.length < 2) return 0;

    double bestAvg = 0;

    // Sliding window: find the window of readings spanning ~60 seconds
    // with the highest average power.
    for (int i = 0; i < readings.length; i++) {
      final windowStart = readings[i].timestamp;
      final windowEnd = windowStart.add(const Duration(seconds: 60));

      // Collect all readings within this 60-second window
      double sum = 0;
      int count = 0;
      for (int j = i; j < readings.length; j++) {
        if (readings[j].timestamp.isAfter(windowEnd)) break;
        sum += readings[j].power;
        count++;
      }

      // Only consider windows that span at least 50 seconds of data
      if (count > 0) {
        final windowDuration = readings[
                (i + count - 1).clamp(0, readings.length - 1)]
            .timestamp
            .difference(windowStart)
            .inSeconds;
        if (windowDuration >= 50) {
          final avg = sum / count;
          if (avg > bestAvg) {
            bestAvg = avg;
          }
        }
      }
    }

    return bestAvg;
  }

  /// Average power across all readings.
  static double averagePower(List<PowerReading> readings) {
    if (readings.isEmpty) return 0;
    final sum = readings.fold<int>(0, (s, r) => s + r.power);
    return sum / readings.length;
  }

  /// Calculate FTP based on protocol:
  /// - Ramp: best 1-min avg × 0.75
  /// - 20 min: avg power × 0.95
  /// - 8 min: avg power × 0.90
  static int calculateFtp(
    List<PowerReading> readings, [
    TestProtocol protocol = TestProtocol.ramp,
  ]) {
    switch (protocol) {
      case TestProtocol.ramp:
        final best = bestOneMinuteAverage(readings);
        return (best * 0.75).round();
      case TestProtocol.twentyMin:
        final avg = averagePower(readings);
        return (avg * 0.95).round();
      case TestProtocol.eightMin:
        final avg = averagePower(readings);
        return (avg * 0.90).round();
    }
  }
}
