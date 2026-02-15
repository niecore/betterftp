import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ramp_test/domain/ramp_test_state.dart';

class ResultsScreen extends StatelessWidget {
  final RampTestState testState;

  const ResultsScreen({super.key, required this.testState});

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),

            // FTP result (big)
            Text(
              'Your FTP',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${testState.calculatedFtp ?? 0}',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 96,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            Text(
              'watts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 48),

            // Summary stats
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Best 1-min Avg Power',
                      value: '${testState.bestOneMinAvgPower.round()} W',
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Max Power Reached',
                      value: '${testState.targetPower} W',
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Stages Completed',
                      value: '${testState.currentStage + 1}',
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Total Duration',
                      value: _formatTime(testState.elapsedSeconds),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Done button
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text(
                    'Done',
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
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
