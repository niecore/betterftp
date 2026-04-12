/// FTMS (Fitness Machine Service) Bluetooth UUIDs and constants
class FtmsConstants {
  FtmsConstants._();

  /// FTMS Service UUID (short 16-bit)
  static const String ftmsServiceShortUuid = '1826';

  /// Indoor Bike Data Characteristic UUID (short 16-bit)
  static const String indoorBikeDataShortUuid = '2ad2';

  /// Fitness Machine Control Point Characteristic UUID (short 16-bit)
  static const String controlPointShortUuid = '2ad9';

  /// Op code for setting target power in ERG mode
  static const int setTargetPowerOpCode = 0x05;

  /// Op code for requesting control
  static const int requestControlOpCode = 0x00;

  /// Op code for reset
  static const int resetOpCode = 0x01;
}
