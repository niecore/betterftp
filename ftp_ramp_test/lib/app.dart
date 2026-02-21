import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class FtpRampTestApp extends StatelessWidget {
  const FtpRampTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FTP.TEST',
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
