import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'features/bluetooth/data/device_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize device storage for auto-reconnect
  final deviceStorage = DeviceStorageService();
  await deviceStorage.init();

  runApp(
    DevicePreview(
      // Only on in debug/profile builds — never ships to release.
      enabled: !kReleaseMode,
      builder: (context) => ProviderScope(
        overrides: [
          deviceStorageServiceProvider.overrideWithValue(deviceStorage),
        ],
        child: const BetterFtpApp(),
      ),
    ),
  );
}
