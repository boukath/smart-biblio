import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/audit_log.dart';
import '../../../domain/rfid/rfid_manager.dart';

class AdminDashboardView extends StatefulWidget {
  final Function(int) onNavigateTab;

  const AdminDashboardView({super.key, required this.onNavigateTab});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  Map<String, int>? _metrics;
  List<AuditLog> _recentLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = context.read<AppDatabase>();
    final metrics = await db.getDashboardMetrics();
    final logs = await db.getRecentAuditLogs(limit: 8);

    if (mounted) {
      setState(() {
        _metrics = metrics;
        _recentLogs = logs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _metrics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final rfid = context.watch<RfidManager>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Refresh
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYSTEM OVERVIEW & KPI METRICS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Library Operations Dashboard',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Metrics',
              ),
            ],
          ),

          const SizedBox(height: 28),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                children: [
                  _buildMetricCard(
                    title: 'Total Catalog Titles',
                    value: _metrics!['totalBooks']!.toString(),
                    subtitle: '${_metrics!['totalCopies']} Physical Copies',
                    icon: Icons.menu_book_rounded,
                    color: AppColors.primary,
                    onTap: () => widget.onNavigateTab(1), // Catalog tab
                  ),
                  _buildMetricCard(
                    title: 'Active Loans',
                    value: _metrics!['activeLoans']!.toString(),
                    subtitle: '${_metrics!['availableCopies']} on Shelf',
                    icon: Icons.sync_alt_rounded,
                    color: AppColors.secondary,
                    onTap: () => widget.onNavigateTab(3), // Circulation tab
                  ),
                  _buildMetricCard(
                    title: 'Overdue Books',
                    value: _metrics!['overdueLoans']!.toString(),
                    subtitle: _metrics!['overdueLoans']! > 0
                        ? 'Requires Attention'
                        : 'Zero Overdue',
                    icon: Icons.warning_amber_rounded,
                    color: _metrics!['overdueLoans']! > 0
                        ? AppColors.danger
                        : AppColors.success,
                    onTap: () => widget.onNavigateTab(3),
                  ),
                  _buildMetricCard(
                    title: 'Registered Students',
                    value: _metrics!['totalMembers']!.toString(),
                    subtitle: '${_metrics!['activeCards']} Active RFID Cards',
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () => widget.onNavigateTab(2), // Members tab
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // Hardware & Quick Actions Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: rfid.isConnected
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sensors_rounded,
                    color: rfid.isConnected ? AppColors.success : AppColors.danger,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rfid.isConnected
                          ? 'RFID Antenna Online: ${rfid.device.deviceName}'
                          : 'RFID Reader Offline',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rfid.isSimulated
                          ? 'Operating in Virtual Simulation Mode (Full test capability)'
                          : 'Hardware connected via USB/COM port at 115200 baud',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => widget.onNavigateTab(1), // Books
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Book'),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: () => widget.onNavigateTab(2), // Members
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Register Student'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Recent Audit Logs Section
          const Text(
            'Recent System Activity & Audit Trail',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          if (_recentLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                  'No transactions recorded yet.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentLogs.length,
                separatorBuilder: (_, _) =>
                    const Divider(color: AppColors.border, height: 1),
                itemBuilder: (context, index) {
                  final log = _recentLogs[index];

                  Color actionColor = AppColors.primary;
                  IconData actionIcon = Icons.info_outline_rounded;
                  if (log.action.contains('BORROW')) {
                    actionColor = AppColors.success;
                    actionIcon = Icons.file_download_rounded;
                  } else if (log.action.contains('RETURN')) {
                    actionColor = AppColors.secondary;
                    actionIcon = Icons.file_upload_rounded;
                  } else if (log.action.contains('CARD')) {
                    actionColor = const Color(0xFFF59E0B);
                    actionIcon = Icons.credit_card_rounded;
                  }

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(actionIcon, size: 18, color: actionColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.details,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Actor: ${log.actorType} (${log.actorId})  •  Entity: ${log.entityType}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm  •  dd MMM').format(log.timestamp),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
