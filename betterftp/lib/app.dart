import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/bluetooth/data/ble_debug_logger.dart';

class BetterFtpApp extends ConsumerWidget {
  const BetterFtpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly construct the BLE debug logger so it starts capturing events
    // before the first scan or connect.
    ref.watch(bleDebugLoggerProvider);

    return MaterialApp.router(
      title: 'BETTER.FTP',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
      // device_preview hooks — make the previewed device frame, locale,
      // and text scale flow into the app.
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
    );
  }
}
