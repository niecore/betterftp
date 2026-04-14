/// FTMS (Fitness Machine Service) Bluetooth UUIDs and constants
class FtmsConstants {
  FtmsConstants._();

  /// FTMS Service UUID (short 16-bit)
  static const String ftmsServiceShortUuid = '1826';

  /// Indoor Bike Data Characteristic UUID (short 16-bit)
  static const String indoorBikeDataShortUuid = '2ad2';

  /// Fitness Machine Control Point Characteristic UUID (short 16-bit)
  static const String controlPointShortUuid = '2ad9';

  // ── Control Point Op Codes ──────────────────────────────────────────

  /// Op code for requesting control
  static const int requestControlOpCode = 0x00;

  /// Op code for reset
  static const int resetOpCode = 0x01;

  /// Op code for setting target power in ERG mode
  static const int setTargetPowerOpCode = 0x05;

  /// Op code for starting or resuming the fitness machine
  static const int startResumeOpCode = 0x07;

  /// Op code for stopping or pausing the fitness machine
  static const int stopPauseOpCode = 0x08;

  // ── Control Point Response Codes ────────────────────────────────────

  /// Response op code sent by the trainer as an indication
  static const int responseOpCode = 0x80;

  /// Result: Success
  static const int resultSuccess = 0x01;

  /// Result: Op Code Not Supported
  static const int resultNotSupported = 0x02;

  /// Result: Invalid Parameter
  static const int resultInvalidParameter = 0x03;

  /// Result: Operation Failed
  static const int resultOperationFailed = 0x04;

  /// Result: Control Not Permitted
  static const int resultControlNotPermitted = 0x05;

  /// Seconds without BLE data before marking the stream as stale
  static const int dataWatchdogTimeoutSeconds = 5;

  /// Maximum number of write retries before giving up
  static const int maxWriteRetries = 3;

  /// Base delay between retries (multiplied by attempt number)
  static const Duration retryBaseDelay = Duration(milliseconds: 150);
}
