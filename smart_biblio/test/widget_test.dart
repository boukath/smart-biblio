import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_biblio/core/theme/app_theme.dart';
import 'package:smart_biblio/presentation/providers/locale_provider.dart';
import 'package:smart_biblio/presentation/screens/kiosk/idle_welcome_view.dart';
import 'package:smart_biblio/presentation/widgets/rfid_radar_animation.dart';

void main() {
  testWidgets('Renders IdleWelcomeView with RFID radar and instructions in French & English',
      (WidgetTester tester) async {
    final localeProvider = LocaleProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleProvider>.value(
        value: localeProvider,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: IdleWelcomeView(),
          ),
        ),
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify header text in French by default
    expect(find.text('BORNE SANS CONTACT SMART BIBLIO'), findsOneWidget);
    expect(find.text('Bienvenue à la Bibliothèque'), findsOneWidget);
    expect(find.text('Posez votre carte'), findsOneWidget);
    expect(find.text('Emprunter ou Retourner'), findsOneWidget);
    expect(find.text('Déposez les livres RFID'), findsOneWidget);
    expect(find.byType(RfidRadarAnimation), findsOneWidget);

    // Tap English toggle
    await tester.tap(find.text('English'));
    await tester.pump();

    // Verify dynamic switch to English
    expect(find.text('SMART BIBLIO CONTACTLESS KIOSK'), findsOneWidget);
    expect(find.text('Welcome to the Library'), findsOneWidget);
    expect(find.text('Scan your card'), findsOneWidget);
    expect(find.text('Borrow or Return'), findsOneWidget);
    expect(find.text('Place RFID books'), findsOneWidget);

    // Unmount widget so repeating animation controller is cleanly disposed
    await tester.pumpWidget(const SizedBox());
  });
}
