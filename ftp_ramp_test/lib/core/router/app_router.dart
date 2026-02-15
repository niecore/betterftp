import 'package:go_router/go_router.dart';

import '../../features/bluetooth/presentation/device_scan_screen.dart';
import '../../features/ramp_test/domain/ramp_test_state.dart';
import '../../features/ramp_test/presentation/ramp_test_screen.dart';
import '../../features/results/presentation/results_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DeviceScanScreen(),
    ),
    GoRoute(
      path: '/ramp-test',
      builder: (context, state) => const RampTestScreen(),
    ),
    GoRoute(
      path: '/results',
      builder: (context, state) {
        final testState = state.extra as RampTestState;
        return ResultsScreen(testState: testState);
      },
    ),
  ],
);
