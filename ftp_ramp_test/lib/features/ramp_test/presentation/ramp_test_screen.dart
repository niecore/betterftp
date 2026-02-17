import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/ramp_test_state.dart';
import 'ramp_test_controller.dart';

class RampTestScreen extends ConsumerStatefulWidget {
  const RampTestScreen({super.key});

  @override
  ConsumerState<RampTestScreen> createState() => _RampTestScreenState();
}

class _RampTestScreenState extends ConsumerState<RampTestScreen> {
  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _phaseLabel(RampTestPhase phase) {
    switch (phase) {
      case RampTestPhase.idle:
        return 'Ready';
      case RampTestPhase.warmup:
        return 'Warm Up';
      case RampTestPhase.ramping:
        return 'Ramping';
      case RampTestPhase.completed:
        return 'Completed';
      case RampTestPhase.failed:
        return 'Failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rampTestControllerProvider);
    final controller = ref.read(rampTestControllerProvider.notifier);

    // Navigate to results when completed
    ref.listen(rampTestControllerProvider, (previous, next) {
      if (next.phase == RampTestPhase.completed && previous?.phase != RampTestPhase.completed) {
        context.go('/results', extra: next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ramp Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Phase indicator
            Card(
              color: _phaseColor(state.phase, context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                child: Text(
                  _phaseLabel(state.phase),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Main data display
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Current power (large)
                  Text(
                    '${state.currentPower}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 80,
                        ),
                  ),
                  Text(
                    'watts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Target power and cadence
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MetricTile(
                        label: 'Target',
                        value: '${state.targetPower}',
                        unit: 'W',
                      ),
                      _MetricTile(
                        label: 'Cadence',
                        value: '${state.currentCadence}',
                        unit: 'rpm',
                      ),
                      if (state.currentHeartRate != null)
                        _MetricTile(
                          label: 'HR',
                          value: '${state.currentHeartRate}',
                          unit: 'bpm',
                        ),
                      if (state.phase == RampTestPhase.ramping)
                        _MetricTile(
                          label: 'Stage',
                          value: '${state.currentStage + 1}',
                          unit: '',
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Timers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MetricTile(
                        label: 'Total Time',
                        value: _formatTime(state.elapsedSeconds),
                        unit: '',
                      ),
                      _MetricTile(
                        label: state.phase == RampTestPhase.warmup
                            ? 'Warmup Left'
                            : 'Stage Time',
                        value: state.phase == RampTestPhase.warmup
                            ? _formatTime((300 - state.stageElapsedSeconds).toInt())
                            : _formatTime(state.stageElapsedSeconds),
                        unit: '',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Best 1-min avg
                  if (state.bestOneMinAvgPower > 0)
                    Text(
                      'Best 1-min avg: ${state.bestOneMinAvgPower.round()}W',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                ],
              ),
            ),

            // Start/Stop buttons
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: state.phase == RampTestPhase.idle
                    ? ElevatedButton(
                        onPressed: () {
                          WakelockPlus.enable();
                          controller.start();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Start Test',
                          style: TextStyle(fontSize: 20),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          WakelockPlus.disable();
                          controller.stop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Stop Test',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _phaseColor(RampTestPhase phase, BuildContext context) {
    switch (phase) {
      case RampTestPhase.idle:
        return Colors.grey;
      case RampTestPhase.warmup:
        return Colors.orange;
      case RampTestPhase.ramping:
        return Colors.blue;
      case RampTestPhase.completed:
        return Colors.green;
      case RampTestPhase.failed:
        return Colors.red;
    }
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                unit,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
