/// FTMS (Fitness Machine Service) Bluetooth UUIDs and constants
class FtmsConstants {
  FtmsConstants._();

  /// FTMS Service UUID
  static const String ftmsServiceUuid = '00001826-0000-1000-8000-00805f9b34fb';

  /// Indoor Bike Data Characteristic UUID - for reading power, cadence, speed
  static const String indoorBikeDataUuid = '00002AD2-0000-1000-8000-00805f9b34fb';

  /// Fitness Machine Control Point Characteristic UUID - for setting target power
  static const String controlPointUuid = '00002AD9-0000-1000-8000-00805f9b34fb';

  /// Op code for setting target power in ERG mode
  static const int setTargetPowerOpCode = 0x05;

  /// Op code for requesting control
  static const int requestControlOpCode = 0x00;

  /// Op code for reset
  static const int resetOpCode = 0x01;
}
