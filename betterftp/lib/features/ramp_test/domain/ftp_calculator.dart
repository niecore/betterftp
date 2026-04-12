import 'dart:math' as math;

import 'ramp_test_state.dart';

class FtpCalculator {
  FtpCalculator._();

  /// Time-weighted average power for a contiguous slice of readings.
  ///
  /// Each reading is weighted by the duration until the next reading.
  /// The last reading in the slice is weighted by the gap to the next
  /// reading outside the slice (or 1 second as fallback).
  static double _timeWeightedAverage(
    List<PowerReading> readings,
    int start,
    int end,
  ) {
    if (start >= end) return 0;
    if (end - start == 1) return readings[start].power.toDouble();

    double weightedSum = 0;
    double totalDuration = 0;

    for (int i = start; i < end; i++) {
      final double dt;
      if (i + 1 < readings.length) {
        dt = readings[i + 1]
                .timestamp
                .difference(readings[i].timestamp)
                .inMilliseconds /
            1000.0;
      } else {
        // Last reading overall — assume 1 second
        dt = 1.0;
      }
      // Clamp to avoid outlier gaps (e.g. BLE reconnect) skewing the average.
      // Ignore zero-duration duplicates, cap at 5 seconds.
      final clamped = dt.clamp(0.001, 5.0);
      weightedSum += readings[i].power * clamped;
      totalDuration += clamped;
    }

    return totalDuration > 0 ? weightedSum / totalDuration : 0;
  }

  /// Compute the best rolling 1-minute time-weighted average power.
  /// Returns 0 if there are fewer than 50 seconds of data.
  static double bestOneMinuteAverage(List<PowerReading> readings) {
    if (readings.length < 2) return 0;

    double bestAvg = 0;
    int windowEnd = 0;

    for (int i = 0; i < readings.length; i++) {
      final windowStart = readings[i].timestamp;
      final windowCutoff = windowStart.add(const Duration(seconds: 60));

      // Advance windowEnd to cover 60 seconds
      while (windowEnd < readings.length &&
          !readings[windowEnd].timestamp.isAfter(windowCutoff)) {
        windowEnd++;
      }

      // Check that the window spans at least 50 seconds
      final lastIdx = math.min(windowEnd - 1, readings.length - 1);
      final span =
          readings[lastIdx].timestamp.difference(windowStart).inSeconds;
      if (span >= 50) {
        final avg = _timeWeightedAverage(readings, i, windowEnd);
        if (avg > bestAvg) bestAvg = avg;
      }
    }

    return bestAvg;
  }

  /// Time-weighted average power across all readings.
  static double averagePower(List<PowerReading> readings) {
    if (readings.isEmpty) return 0;
    return _timeWeightedAverage(readings, 0, readings.length);
  }

  /// Time-weighted average heart rate across all readings that have HR data.
  static double? averageHeartRate(List<PowerReading> readings) {
    final hrReadings = readings.where((r) => r.heartRate != null).toList();
    if (hrReadings.length < 2) {
      if (hrReadings.length == 1) return hrReadings.first.heartRate!.toDouble();
      return null;
    }

    double weightedSum = 0;
    double totalDuration = 0;

    for (int i = 0; i < hrReadings.length; i++) {
      final double dt;
      if (i + 1 < hrReadings.length) {
        dt = hrReadings[i + 1]
                .timestamp
                .difference(hrReadings[i].timestamp)
                .inMilliseconds /
            1000.0;
      } else {
        dt = 1.0;
      }
      final clamped = dt.clamp(0.001, 5.0);
      weightedSum += hrReadings[i].heartRate! * clamped;
      totalDuration += clamped;
    }

    return totalDuration > 0 ? weightedSum / totalDuration : null;
  }

  /// Time-weighted average power over a fixed duration window.
  ///
  /// If the actual riding time is shorter than [windowSeconds], the remaining
  /// time is treated as 0W (zero-filled). This ensures that stopping a 20-min
  /// test early penalises the result correctly.
  static double averagePowerOverWindow(
    List<PowerReading> readings,
    int windowSeconds,
  ) {
    if (readings.isEmpty) return 0;

    final ridingDuration = readings.last.timestamp
        .difference(readings.first.timestamp)
        .inMilliseconds /
        1000.0;
    final ridingAvg = _timeWeightedAverage(readings, 0, readings.length);

    if (ridingDuration >= windowSeconds) {
      // Rode the full window or longer — just use actual data
      return ridingAvg;
    }

    // Zero-fill: weight the actual riding average over ridingDuration,
    // and 0W over the remaining time.
    return (ridingAvg * ridingDuration) / windowSeconds;
  }

}
