import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Persists last-paired BLE device IDs and names so the app can
/// auto-reconnect on next launch without scanning.
class DeviceStorageService {
  static const _boxName = 'paired_devices';
  static const _trainerIdKey = 'trainer_id';
  static const _trainerNameKey = 'trainer_name';
  static const _hrIdKey = 'hr_id';
  static const _hrNameKey = 'hr_name';

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Future<void> saveTrainer(String id, String name) async {
    await _box.put(_trainerIdKey, id);
    await _box.put(_trainerNameKey, name);
  }

  Future<void> saveHrMonitor(String id, String name) async {
    await _box.put(_hrIdKey, id);
    await _box.put(_hrNameKey, name);
  }

  ({String id, String name})? getSavedTrainer() {
    final id = _box.get(_trainerIdKey) as String?;
    final name = _box.get(_trainerNameKey) as String?;
    if (id == null || name == null) return null;
    return (id: id, name: name);
  }

  ({String id, String name})? getSavedHrMonitor() {
    final id = _box.get(_hrIdKey) as String?;
    final name = _box.get(_hrNameKey) as String?;
    if (id == null || name == null) return null;
    return (id: id, name: name);
  }

  Future<void> clearTrainer() async {
    await _box.delete(_trainerIdKey);
    await _box.delete(_trainerNameKey);
  }

  Future<void> clearHrMonitor() async {
    await _box.delete(_hrIdKey);
    await _box.delete(_hrNameKey);
  }
}

/// Provider for [DeviceStorageService]. Must be overridden in ProviderScope
/// with an already-initialized instance.
final deviceStorageServiceProvider = Provider<DeviceStorageService>((ref) {
  throw UnimplementedError(
    'deviceStorageServiceProvider must be overridden with an initialized instance',
  );
});
