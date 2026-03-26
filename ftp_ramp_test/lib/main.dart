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
    ProviderScope(
      overrides: [
        deviceStorageServiceProvider.overrideWithValue(deviceStorage),
      ],
      child: const FtpRampTestApp(),
    ),
  );
}
