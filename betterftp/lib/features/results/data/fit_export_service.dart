import 'dart:typed_data';

import 'package:fit_sdk/fit_sdk.dart';

import '../../ramp_test/domain/ftp_calculator.dart';
import '../../ramp_test/domain/ramp_test_state.dart';

/// Converts a completed [TestRunState] into FIT binary bytes.
class FitExportService {
  /// FIT epoch offset: FIT timestamps = Unix seconds − 631065600.
  static const int _fitEpochOffset = 631065600;

  static int _toFitTimestamp(DateTime dt) =>
      (dt.millisecondsSinceEpoch ~/ 1000) - _fitEpochOffset;

  /// Encodes the test state into a valid FIT activity file.
  ///
  /// All readings (including warmup) are written as Record messages so the
  /// FIT file reflects the full ride. Session-level averages also cover the
  /// full activity for accurate import into Garmin Connect, Strava, etc.
  Uint8List encode(TestRunState state) {
    final allReadings = state.allReadings;
    if (allReadings.isEmpty) {
      throw StateError('No power readings to export');
    }

    final startTime = allReadings.first.timestamp;
    final endTime = allReadings.last.timestamp;
    final fitStart = _toFitTimestamp(startTime);
    final fitEnd = _toFitTimestamp(endTime);
    final totalElapsed =
        endTime.difference(startTime).inMilliseconds / 1000.0;

    final encoder = Encode();
    encoder.open();

    // --- FileId (must be first) ---
    _writeFileId(encoder, fitStart);

    // --- Record messages (one per PowerReading, all phases) ---
    _writeRecords(encoder, allReadings);

    // --- Lap (one covering entire activity) ---
    _writeLap(encoder, state, fitStart, fitEnd, totalElapsed);

    // --- Session (averages cover full activity) ---
    _writeSession(encoder, state, fitStart, fitEnd, totalElapsed);

    // --- Activity (must be last) ---
    _writeActivity(encoder, fitEnd, totalElapsed);

    return encoder.close();
  }

  void _writeFileId(Encode encoder, int fitTimestamp) {
    final mesg = Mesg.fromMesgNum(MesgNum.fileId);
    mesg.setFieldValue(0, 4); // type = activity
    mesg.setFieldValue(1, 255); // manufacturer = development
    mesg.setFieldValue(2, 0); // product
    mesg.setFieldValue(3, 12345); // serial_number
    mesg.setFieldValue(4, fitTimestamp); // time_created

    final def = MesgDefinition.fromMesg(mesg);
    encoder.writeMesgDefinition(def);
    encoder.writeMesg(mesg);
  }

  void _writeRecords(Encode encoder, List<PowerReading> readings) {
    bool definitionWritten = false;

    for (final reading in readings) {
      final mesg = Mesg.fromMesgNum(MesgNum.record);
      mesg.setFieldValue(253, _toFitTimestamp(reading.timestamp)); // timestamp
      mesg.setFieldValue(7, reading.power); // power (watts)
      if (reading.heartRate != null) {
        mesg.setFieldValue(3, reading.heartRate!); // heart_rate (bpm)
      }

      if (!definitionWritten) {
        final def = MesgDefinition.fromMesg(mesg);
        encoder.writeMesgDefinition(def);
        definitionWritten = true;
      }
      encoder.writeMesg(mesg);
    }
  }

  void _writeLap(
    Encode encoder,
    TestRunState state,
    int fitStart,
    int fitEnd,
    double totalElapsed,
  ) {
    final mesg = Mesg.fromMesgNum(MesgNum.lap);
    mesg.setFieldValue(253, fitEnd); // timestamp
    mesg.setFieldValue(0, 9); // event = lap
    mesg.setFieldValue(1, 1); // event_type = stop
    mesg.setFieldValue(2, fitStart); // start_time
    mesg.setFieldValue(7, (totalElapsed * 1000).round()); // total_elapsed_time
    mesg.setFieldValue(8, (totalElapsed * 1000).round()); // total_timer_time

    final def = MesgDefinition.fromMesg(mesg);
    encoder.writeMesgDefinition(def);
    encoder.writeMesg(mesg);
  }

  void _writeSession(
    Encode encoder,
    TestRunState state,
    int fitStart,
    int fitEnd,
    double totalElapsed,
  ) {
    final mesg = Mesg.fromMesgNum(MesgNum.session);
    mesg.setFieldValue(253, fitEnd); // timestamp
    mesg.setFieldValue(0, 9); // event = lap
    mesg.setFieldValue(1, 1); // event_type = stop
    mesg.setFieldValue(2, fitStart); // start_time
    mesg.setFieldValue(5, 2); // sport = cycling
    mesg.setFieldValue(6, 6); // sub_sport = indoor_cycling
    mesg.setFieldValue(7, (totalElapsed * 1000).round()); // total_elapsed_time
    mesg.setFieldValue(8, (totalElapsed * 1000).round()); // total_timer_time

    // Power stats (time-weighted)
    final avgPower =
        FtpCalculator.averagePower(state.allReadings).round();
    mesg.setFieldValue(20, avgPower); // avg_power
    mesg.setFieldValue(21, state.maxPower); // max_power

    // HR stats (time-weighted)
    final avgHr = FtpCalculator.averageHeartRate(state.allReadings);
    if (avgHr != null) {
      mesg.setFieldValue(16, avgHr.round()); // avg_heart_rate
    }
    if (state.maxHeartRate != null) {
      mesg.setFieldValue(17, state.maxHeartRate!); // max_heart_rate
    }

    final def = MesgDefinition.fromMesg(mesg);
    encoder.writeMesgDefinition(def);
    encoder.writeMesg(mesg);
  }

  void _writeActivity(Encode encoder, int fitEnd, double totalElapsed) {
    final mesg = Mesg.fromMesgNum(MesgNum.activity);
    mesg.setFieldValue(253, fitEnd); // timestamp
    mesg.setFieldValue(0, (totalElapsed * 1000).round()); // total_timer_time
    mesg.setFieldValue(1, 1); // num_sessions
    mesg.setFieldValue(3, 26); // event = activity
    mesg.setFieldValue(4, 1); // event_type = stop

    final def = MesgDefinition.fromMesg(mesg);
    encoder.writeMesgDefinition(def);
    encoder.writeMesg(mesg);
  }
}
