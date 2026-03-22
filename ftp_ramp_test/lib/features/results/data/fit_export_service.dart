import 'dart:typed_data';

import 'package:fit_sdk/fit_sdk.dart';

import '../../ramp_test/domain/ramp_test_state.dart';

/// Converts a completed [RampTestState] into FIT binary bytes.
class FitExportService {
  /// FIT epoch offset: FIT timestamps = Unix seconds − 631065600.
  static const int _fitEpochOffset = 631065600;

  static int _toFitTimestamp(DateTime dt) =>
      (dt.millisecondsSinceEpoch ~/ 1000) - _fitEpochOffset;

  /// Encodes the test state into a valid FIT activity file.
  Uint8List encode(RampTestState state) {
    final readings = state.powerReadings;
    if (readings.isEmpty) {
      throw StateError('No power readings to export');
    }

    final startTime = readings.first.timestamp;
    final endTime = readings.last.timestamp;
    final fitStart = _toFitTimestamp(startTime);
    final fitEnd = _toFitTimestamp(endTime);
    final totalElapsed =
        endTime.difference(startTime).inMilliseconds / 1000.0;

    final encoder = Encode();
    encoder.open();

    // --- FileId (must be first) ---
    _writeFileId(encoder, fitStart);

    // --- Record messages (one per PowerReading) ---
    _writeRecords(encoder, readings);

    // --- Lap (one covering entire activity) ---
    _writeLap(encoder, state, fitStart, fitEnd, totalElapsed);

    // --- Session ---
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
    RampTestState state,
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
    RampTestState state,
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

    // Power stats
    final avgPower = state.powerReadings.isEmpty
        ? 0
        : state.powerReadings.fold<int>(0, (s, r) => s + r.power) ~/
            state.powerReadings.length;
    mesg.setFieldValue(20, avgPower); // avg_power
    mesg.setFieldValue(21, state.maxPower); // max_power

    // HR stats
    if (state.averageHeartRate != null) {
      mesg.setFieldValue(16, state.averageHeartRate!); // avg_heart_rate
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
