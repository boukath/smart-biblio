import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/kiosk_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/rfid_radar_animation.dart';

class IdleWelcomeView extends StatelessWidget {
  const IdleWelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final kiosk = Provider.of<KioskProvider?>(context);
    final cardErrorMessage = kiosk?.cardErrorMessage;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Welcome Header Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.contactless_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    locale.t('kiosk_badge'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              locale.t('welcome_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              locale.t('welcome_subtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),

            // Prominent Language Switcher on First Screen
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLangChoiceChip(
                    context: context,
                    flag: '🇫🇷',
                    title: 'Français',
                    isSelected: locale.isFrench,
                    onTap: () => locale.setLanguage('fr'),
                  ),
                  const SizedBox(width: 6),
                  _buildLangChoiceChip(
                    context: context,
                    flag: '🇬🇧',
                    title: 'English',
                    isSelected: locale.isEnglish,
                    onTap: () => locale.setLanguage('en'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Pulsing Radar Wave
            RfidRadarAnimation(size: 260, label: locale.t('radar_scan_card')),

            if (cardErrorMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        locale.t(cardErrorMessage),
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                      onPressed: kiosk?.clearCardError,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 48),

            // Process Steps
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStepPill('1', locale.t('step1'), Icons.credit_card_rounded),
                _buildStepArrow(),
                _buildStepPill('2', locale.t('step2'), Icons.touch_app_rounded),
                _buildStepArrow(),
                _buildStepPill('3', locale.t('step3'), Icons.auto_stories_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildLangChoiceChip({
    required BuildContext context,
    required String flag,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.black : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStepPill(String number, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStepArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textMuted),
    );
  }
}
