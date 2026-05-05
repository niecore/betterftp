import 'dart:io';

import 'package:device_preview/device_preview.dart';
import 'package:device_preview_screenshot/device_preview_screenshot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'features/bluetooth/data/device_storage_service.dart';

Future<void> _saveScreenshot(BuildContext context, DeviceScreenshot screenshot) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/screenshots');
  if (!await dir.exists()) await dir.create(recursive: true);
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${dir.path}/${screenshot.device.identifier}_$timestamp.png');
  await file.writeAsBytes(screenshot.bytes);
  debugPrint('Screenshot saved: ${file.path}');
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved: ${file.path.split('/').last}')),
    );
  }
}

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
      tools: [
        ...DevicePreview.defaultTools,
        DevicePreviewScreenshot(onScreenshot: _saveScreenshot),
      ],
      builder: (context) => ProviderScope(
        overrides: [
          deviceStorageServiceProvider.overrideWithValue(deviceStorage),
        ],
        child: const BetterFtpApp(),
      ),
    ),
  );
}
