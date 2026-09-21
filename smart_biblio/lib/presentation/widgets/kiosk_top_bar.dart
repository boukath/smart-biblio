import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/rfid/rfid_models.dart';
import '../providers/kiosk_provider.dart';

class KioskTopBar extends StatefulWidget {
  final VoidCallback onOpenAdmin;

  const KioskTopBar({super.key, required this.onOpenAdmin});

  @override
  State<KioskTopBar> createState() => _KioskTopBarState();
}

class _KioskTopBarState extends State<KioskTopBar> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kiosk = context.watch<KioskProvider>();
    final isStudentActive = kiosk.currentStudent != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Brand & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SMART BIBLIO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'UHF RFID Smart Self-Service Kiosk',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // RFID Hardware Status Pill
          StreamBuilder<RfidConnectionState>(
            stream: kiosk.rfid.onConnectionStateChanged,
            initialData: kiosk.rfid.isConnected
                ? RfidConnectionState.connected
                : RfidConnectionState.disconnected,
            builder: (context, snapshot) {
              final isConnected = kiosk.rfid.isConnected;
              final isSim = kiosk.rfid.isSimulated;

              Color pillColor = isConnected ? AppColors.success : AppColors.danger;
              String pillText = isConnected
                  ? (isSim ? 'Virtual RFID Simulator' : 'U1-CU-71 Connected')
                  : 'RFID Disconnected';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: pillColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: pillColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pillColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: pillColor.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pillText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pillColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(width: 20),

          // Real-time Clock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('HH:mm:ss  •  E, MMM d').format(_now),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Active Session Timer & Finish Button
          if (isStudentActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kiosk.timeoutSecondsRemaining <= 10
                    ? AppColors.danger.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: kiosk.timeoutSecondsRemaining <= 10
                      ? AppColors.danger.withValues(alpha: 0.4)
                      : AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: kiosk.timeoutSecondsRemaining <= 10
                        ? AppColors.danger
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${kiosk.timeoutSecondsRemaining}s',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kiosk.timeoutSecondsRemaining <= 10
                          ? AppColors.danger
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: kiosk.exitSession,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('FINISH / EXIT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger.withValues(alpha: 0.8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Admin Access Button
          IconButton(
            tooltip: 'Librarian & Admin Access (Ctrl+Shift+A)',
            onPressed: widget.onOpenAdmin,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
