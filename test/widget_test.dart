import 'package:expense_tracker/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';

void main() {
  testWidgets('Expense Tracker app loads', (WidgetTester tester) async {
    // The app now receives its database through AppServices, so the
    // test owns the connection and closes it in the body: the old
    // pending-Timer failure (a global database the test could never
    // close) no longer has a cause.
    final services = await tester.runAsync(createTestServices);
    await tester.pumpWidget(ExpenseTrackerApp(services: services!));
    await tester.pumpAndSettle();

    expect(find.text('Expense Tracker'), findsOneWidget);
    expect(find.text('Welcome! Add your first account'), findsOneWidget);

    await closeServices(tester, services);
  });
}
