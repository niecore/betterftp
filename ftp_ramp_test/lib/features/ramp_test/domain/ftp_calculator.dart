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

  /// Calculate FTP as 75% of the best 1-minute average power.
  static int calculateFtp(List<PowerReading> readings) {
    final best = bestOneMinuteAverage(readings);
    return (best * 0.75).round();
  }
}
