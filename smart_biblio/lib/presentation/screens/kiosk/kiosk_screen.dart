import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/window_service.dart';
import '../../providers/kiosk_provider.dart';
import '../../widgets/kiosk_top_bar.dart';
import 'borrow_scanning_view.dart';
import 'idle_welcome_view.dart';
import 'return_scanning_view.dart';
import 'student_home_view.dart';
import 'success_receipt_view.dart';

class KioskScreen extends StatelessWidget {
  final VoidCallback onOpenAdmin;

  const KioskScreen({super.key, required this.onOpenAdmin});

  @override
  Widget build(BuildContext context) {
    final kiosk = context.watch<KioskProvider>();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA, control: true, shift: true):
            onOpenAdmin,
        const SingleActivator(LogicalKeyboardKey.f11):
            WindowService.toggleFullScreen,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true):
            WindowService.toggleFullScreen,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => kiosk.resetTimer(), // Any touch interaction resets the 45s timer!
            child: Column(
              children: [
                // Top Header Bar
                KioskTopBar(onOpenAdmin: onOpenAdmin),

                // Main Dynamic Content Area
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildCurrentView(kiosk.step),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(KioskStep step) {
    switch (step) {
      case KioskStep.idle:
        return const IdleWelcomeView(key: ValueKey('idle'));
      case KioskStep.studentHome:
        return const StudentHomeView(key: ValueKey('studentHome'));
      case KioskStep.borrowScanning:
        return const BorrowScanningView(key: ValueKey('borrowScanning'));
      case KioskStep.returnScanning:
        return const ReturnScanningView(key: ValueKey('returnScanning'));
      case KioskStep.successReceipt:
        return const SuccessReceiptView(key: ValueKey('successReceipt'));
    }
  }
}
