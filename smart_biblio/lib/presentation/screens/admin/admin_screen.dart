import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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
    return Scaffold(
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ADMIN CENTER',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Smart Biblio Backoffice',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Navigation Items
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard Overview',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.menu_book_rounded,
                  label: 'Catalog & Copies',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.people_alt_rounded,
                  label: 'Students & Cards',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.sync_alt_rounded,
                  label: 'Circulation & Fines',
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.sensors_rounded,
                  label: 'RFID Center & Audit',
                ),
                _buildNavItem(
                  index: 5,
                  icon: Icons.settings_suggest_rounded,
                  label: 'Settings & Reports',
                ),

                const Spacer(),

                // Exit to Kiosk Mode Button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: FilledButton.icon(
                    onPressed: widget.onExitToKiosk,
                    icon: const Icon(Icons.touch_app_rounded, size: 18),
                    label: const Text(
                      'STUDENT KIOSK',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
