import 'package:flutter/material.dart';

import 'core/router/app_router.dart';

class FtpRampTestApp extends StatelessWidget {
  const FtpRampTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FTP Ramp Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
