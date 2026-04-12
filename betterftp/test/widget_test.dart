import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:betterftp/app.dart';

void main() {
  testWidgets('App loads and shows scan screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: BetterFtpApp(),
      ),
    );

    // Verify that the app title is shown
    expect(find.text('BETTER.FTP'), findsOneWidget);

    // Verify that the scan button is present
    expect(find.text('Scan for Trainers'), findsOneWidget);
  });
}
