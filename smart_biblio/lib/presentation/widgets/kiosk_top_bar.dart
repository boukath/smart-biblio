import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/rfid/rfid_models.dart';
import '../providers/kiosk_provider.dart';
import '../providers/locale_provider.dart';

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
    final locale = context.watch<LocaleProvider>();
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
                    locale.t('kiosk_subtitle'),
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

          // Language Switcher (FR / EN)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLangButton(
                  label: 'FR',
                  flag: '🇫🇷',
                  isSelected: locale.isFrench,
                  onTap: () => locale.setLanguage('fr'),
                ),
                const SizedBox(width: 2),
                _buildLangButton(
                  label: 'EN',
                  flag: '🇬🇧',
                  isSelected: locale.isEnglish,
                  onTap: () => locale.setLanguage('en'),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // RFID Hardware Status (Icon only, clean and compact)
          StreamBuilder<RfidConnectionState>(
            stream: kiosk.rfid.onConnectionStateChanged,
            initialData: kiosk.rfid.isConnected
                ? RfidConnectionState.connected
                : RfidConnectionState.disconnected,
            builder: (context, snapshot) {
              final isConnected = kiosk.rfid.isConnected;
              final Color pillColor = isConnected ? AppColors.success : AppColors.danger;

              return Tooltip(
                message: isConnected ? locale.t('rfid_connected') : locale.t('rfid_disconnected'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: pillColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isConnected ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                      size: 18,
                      color: pillColor,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 16),

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
                  DateFormat('HH:mm:ss  •  dd/MM/yyyy').format(_now),
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
              label: Text(locale.t('exit_session'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Admin Access Button
          IconButton(
            tooltip: locale.t('admin_access_tooltip'),
            onPressed: widget.onOpenAdmin,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildLangButton({
    required String label,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.black : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
