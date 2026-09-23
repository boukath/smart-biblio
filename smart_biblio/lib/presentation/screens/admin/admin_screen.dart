import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/window_service.dart';
import '../../providers/locale_provider.dart';
import 'admin_catalog_view.dart';
import 'admin_circulation_view.dart';
import 'admin_dashboard_view.dart';
import 'admin_members_view.dart';
import 'admin_rfid_center_view.dart';
import 'admin_settings_and_audit_view.dart';

class AdminScreen extends StatefulWidget {
  final VoidCallback onExitToKiosk;

  const AdminScreen({super.key, required this.onExitToKiosk});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f11): WindowService.toggleFullScreen,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true):
            WindowService.toggleFullScreen,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              // Sleek Admin Sidebar
              Container(
                width: 260,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    right: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Top Brand
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  locale.t('admin_center'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  locale.t('admin_subtitle'),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Navigation Items
                    _buildNavItem(
                      index: 0,
                      icon: Icons.dashboard_rounded,
                      label: locale.t('nav_dashboard'),
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.menu_book_rounded,
                      label: locale.t('nav_catalog'),
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.people_alt_rounded,
                      label: locale.t('nav_students'),
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.sync_alt_rounded,
                      label: locale.t('nav_circulation'),
                    ),
                    _buildNavItem(
                      index: 4,
                      icon: Icons.sensors_rounded,
                      label: locale.t('nav_rfid_center'),
                    ),
                    _buildNavItem(
                      index: 5,
                      icon: Icons.settings_suggest_rounded,
                      label: locale.t('nav_settings'),
                    ),

                    const Spacer(),

                    // Admin Language Toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => locale.setLanguage('fr'),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: locale.isFrench ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '🇫🇷 FR',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: locale.isFrench ? Colors.black : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () => locale.setLanguage('en'),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: locale.isEnglish ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '🇬🇧 EN',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: locale.isEnglish ? Colors.black : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Toggle Fullscreen (Admin Only)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: OutlinedButton.icon(
                        onPressed: WindowService.toggleFullScreen,
                        icon: const Icon(Icons.fullscreen_rounded, size: 18),
                        label: Text(
                          locale.t('fullscreen_btn'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Exit to Kiosk Mode Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: FilledButton.icon(
                        onPressed: widget.onExitToKiosk,
                        icon: const Icon(Icons.touch_app_rounded, size: 18),
                        label: Text(
                          locale.t('student_kiosk_btn'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main View Content
              Expanded(
                child: _buildActiveView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTabIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.secondary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AppColors.secondary.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.secondary : AppColors.textSecondary,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveView() {
    switch (_selectedTabIndex) {
      case 0:
        return AdminDashboardView(
          onNavigateTab: (index) => setState(() => _selectedTabIndex = index),
        );
      case 1:
        return const AdminCatalogView();
      case 2:
        return const AdminMembersView();
      case 3:
        return const AdminCirculationView();
      case 4:
        return const AdminRfidCenterView();
      case 5:
        return const AdminSettingsAndAuditView();
      default:
        return const AdminDashboardView(onNavigateTab: _dummyNav);
    }
  }

  static void _dummyNav(int _) {}
}
