import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_biblio/core/theme/app_theme.dart';
import 'package:smart_biblio/presentation/screens/kiosk/idle_welcome_view.dart';
import 'package:smart_biblio/presentation/widgets/rfid_radar_animation.dart';

void main() {
  testWidgets('Renders IdleWelcomeView with RFID radar and instructions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: IdleWelcomeView(),
        ),
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify header text
    expect(find.text('CONTACTLESS SMART BIBLIO KIOSK'), findsOneWidget);
    expect(find.text('Welcome to the University Library'), findsOneWidget);
    expect(find.text('Tap Student Card'), findsOneWidget);
    expect(find.text('Select Borrow or Return'), findsOneWidget);
    expect(find.text('Place RFID Books'), findsOneWidget);
    expect(find.byType(RfidRadarAnimation), findsOneWidget);

    // Unmount widget so repeating animation controller is cleanly disposed
    await tester.pumpWidget(const SizedBox());
  });
}
