import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class BetterFtpApp extends StatelessWidget {
  const BetterFtpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BETTER.FTP',
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
