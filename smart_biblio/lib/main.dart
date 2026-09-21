import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/database/seed_data.dart';
import 'domain/rfid/rfid_manager.dart';
import 'domain/services/circulation_service.dart';
import 'presentation/providers/kiosk_provider.dart';
import 'presentation/screens/admin/admin_login_dialog.dart';
import 'presentation/screens/admin/admin_screen.dart';
import 'presentation/screens/kiosk/kiosk_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for Windows desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Initialize database and populate seed data if empty
  final db = AppDatabase();
  await SeedData.populateIfEmpty(db);

  // Initialize RFID manager and attempt auto-connect
  final rfidManager = RfidManager();
  await rfidManager.connect();

  final circulationService = CirculationService(db: db);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<RfidManager>.value(value: rfidManager),
        Provider<CirculationService>.value(value: circulationService),
        ChangeNotifierProvider(
          create: (_) => KioskProvider(
            db: db,
            circulation: circulationService,
            rfid: rfidManager,
          ),
        ),
      ],
      child: const SmartBiblioApp(),
    ),
  );
}

class SmartBiblioApp extends StatelessWidget {
  const SmartBiblioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Biblio - Premium RFID Library Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Builder(
        builder: (navContext) {
          return KioskScreen(
            onOpenAdmin: () {
              showDialog(
                context: navContext,
                builder: (dialogCtx) {
                  return AdminLoginDialog(
                    onLoginSuccess: () {
                      Navigator.of(navContext).push(
                        MaterialPageRoute(
                          builder: (_) => AdminScreen(
                            onExitToKiosk: () =>
                                Navigator.of(navContext).pop(),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
