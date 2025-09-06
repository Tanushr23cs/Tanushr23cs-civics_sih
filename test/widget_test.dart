import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/main.dart'; // Ensure main.dart defines MyApp

void main() {
  testWidgets('Complaints screen loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title "Complaints" is displayed.
    expect(find.text('Complaints'), findsOneWidget);

    // If there are no complaints, verify the "No complaints found" text.
    expect(find.text('No complaints found.'), findsOneWidget);
  });
}
