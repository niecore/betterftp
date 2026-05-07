import 'package:go_router/go_router.dart';

import '../../features/bluetooth/presentation/device_scan_screen.dart';
import '../../features/ramp_test/domain/ramp_test_state.dart';
import '../../features/ramp_test/presentation/test_instructions_screen.dart';
import '../../features/ramp_test/presentation/workout_screen.dart';
import '../../features/results/presentation/results_screen.dart';

TestProtocol _parseProtocol(Object? extra) {
  final map = extra as Map<String, dynamic>? ?? {};
  final protocolStr = map['protocol'] as String? ?? 'ramp';
  return TestProtocol.values.firstWhere(
    (p) => p.name == protocolStr,
    orElse: () => TestProtocol.ramp,
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DeviceScanScreen(),
    ),
    GoRoute(
      path: '/test-instructions',
      builder: (context, state) {
        final protocol = _parseProtocol(state.extra);
        return TestInstructionsScreen(protocol: protocol);
      },
    ),
    GoRoute(
      path: '/workout',
      builder: (context, state) {
        final map = state.extra as Map<String, dynamic>? ?? {};
        final autoStart = map['autoStart'] as bool? ?? false;
        final protocol = _parseProtocol(state.extra);
        return WorkoutScreen(autoStart: autoStart, protocol: protocol);
      },
    ),
    GoRoute(
      path: '/results',
      builder: (context, state) => const ResultsScreen(),
    ),
  ],
);
