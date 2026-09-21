import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/csv_export_service.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/audit_log.dart';
import '../../../data/models/system_settings.dart';

class AdminSettingsAndAuditView extends StatefulWidget {
  const AdminSettingsAndAuditView({super.key});

  @override
  State<AdminSettingsAndAuditView> createState() => _AdminSettingsAndAuditViewState();
}

class _AdminSettingsAndAuditViewState extends State<AdminSettingsAndAuditView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Settings form state
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _libraryNameCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _loanDurationCtrl;
  late TextEditingController _maxLoansCtrl;
  late TextEditingController _finePerDayCtrl;
  late TextEditingController _gracePeriodCtrl;
  late TextEditingController _autoTimeoutCtrl;
  late TextEditingController _debounceCtrl;
  bool _allowReturnOthers = false;
  int _readerPort = 100;
  int _readerBaud = 115200;

  bool _isSavingSettings = false;
  String? _settingsFeedback;

  // Audit Logs state
  List<AuditLog> _auditLogs = [];
  bool _isLoadingAudit = false;
  String _selectedActionFilter = 'ALL';
  final _auditSearchCtrl = TextEditingController();

  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final def = SystemSettings();
    _libraryNameCtrl = TextEditingController(text: def.libraryName);
    _currencyCtrl = TextEditingController(text: def.currency);
    _loanDurationCtrl = TextEditingController(text: def.loanDurationDays.toString());
    _maxLoansCtrl = TextEditingController(text: def.maxLoansPerStudent.toString());
    _finePerDayCtrl = TextEditingController(text: def.finePerDay.toStringAsFixed(0));
    _gracePeriodCtrl = TextEditingController(text: def.gracePeriodDays.toString());
    _autoTimeoutCtrl = TextEditingController(text: def.autoTimeoutSeconds.toString());
    _debounceCtrl = TextEditingController(text: def.debounceMs.toString());
    _allowReturnOthers = def.allowReturnOtherMemberBooks;
    _readerPort = def.readerPort;
    _readerBaud = def.readerBaud;

    _loadSettings();
    _loadAuditLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _libraryNameCtrl.dispose();
    _currencyCtrl.dispose();
    _loanDurationCtrl.dispose();
    _maxLoansCtrl.dispose();
    _finePerDayCtrl.dispose();
    _gracePeriodCtrl.dispose();
    _autoTimeoutCtrl.dispose();
    _debounceCtrl.dispose();
    _auditSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = context.read<AppDatabase>();
    final settings = await db.getSettings();

    if (mounted) {
      setState(() {
        _libraryNameCtrl.text = settings.libraryName;
        _currencyCtrl.text = settings.currency;
        _loanDurationCtrl.text = settings.loanDurationDays.toString();
        _maxLoansCtrl.text = settings.maxLoansPerStudent.toString();
        _finePerDayCtrl.text = settings.finePerDay.toStringAsFixed(0);
        _gracePeriodCtrl.text = settings.gracePeriodDays.toString();
        _autoTimeoutCtrl.text = settings.autoTimeoutSeconds.toString();
        _debounceCtrl.text = settings.debounceMs.toString();
        _allowReturnOthers = settings.allowReturnOtherMemberBooks;
        _readerPort = settings.readerPort;
        _readerBaud = settings.readerBaud;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final db = context.read<AppDatabase>();
    setState(() {
      _isSavingSettings = true;
      _settingsFeedback = null;
    });

    final updated = SystemSettings(
      libraryName: _libraryNameCtrl.text.trim(),
      currency: _currencyCtrl.text.trim().toUpperCase(),
      loanDurationDays: int.tryParse(_loanDurationCtrl.text) ?? 14,
      maxLoansPerStudent: int.tryParse(_maxLoansCtrl.text) ?? 5,
      finePerDay: double.tryParse(_finePerDayCtrl.text) ?? 50.0,
      gracePeriodDays: int.tryParse(_gracePeriodCtrl.text) ?? 2,
      autoTimeoutSeconds: int.tryParse(_autoTimeoutCtrl.text) ?? 45,
      debounceMs: int.tryParse(_debounceCtrl.text) ?? 1200,
      allowReturnOtherMemberBooks: _allowReturnOthers,
      readerPort: _readerPort,
      readerBaud: _readerBaud,
    );

    await db.saveSettings(updated);

    if (mounted) {
      setState(() {
        _isSavingSettings = false;
        _settingsFeedback = 'System settings successfully saved and applied!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _restoreDefaults() {
    final def = SystemSettings();
    setState(() {
      _libraryNameCtrl.text = def.libraryName;
      _currencyCtrl.text = def.currency;
      _loanDurationCtrl.text = def.loanDurationDays.toString();
      _maxLoansCtrl.text = def.maxLoansPerStudent.toString();
      _finePerDayCtrl.text = def.finePerDay.toStringAsFixed(0);
      _gracePeriodCtrl.text = def.gracePeriodDays.toString();
      _autoTimeoutCtrl.text = def.autoTimeoutSeconds.toString();
      _debounceCtrl.text = def.debounceMs.toString();
      _allowReturnOthers = def.allowReturnOtherMemberBooks;
      _readerPort = def.readerPort;
      _readerBaud = def.readerBaud;
      _settingsFeedback = 'Defaults restored. Click [ SAVE SETTINGS ] to persist.';
    });
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingAudit = true);
    final db = context.read<AppDatabase>();
    final logs = await db.getFilteredAuditLogs(
      action: _selectedActionFilter,
      searchTerm: _auditSearchCtrl.text.trim(),
      limit: 200,
    );

    if (mounted) {
      setState(() {
        _auditLogs = logs;
        _isLoadingAudit = false;
      });
    }
  }

  Future<void> _exportAuditCsv() async {
    final file = await CsvExportService.saveCsvToFile(
      filenamePrefix: 'smart_biblio_audit_logs',
      csvContent: CsvExportService.generateAuditLogCsv(_auditLogs),
    );

    if (mounted) {
      _showExportSuccessDialog('Audit Trail Export', file.path, _auditLogs.length);
    }
  }

  Future<void> _exportLoansCsv() async {
    final db = context.read<AppDatabase>();
    final loans = await db.getDetailedLoansReport();

    final file = await CsvExportService.saveCsvToFile(
      filenamePrefix: 'smart_biblio_circulation_report',
      csvContent: CsvExportService.generateLoansReportCsv(loans),
    );

    if (mounted) {
      _showExportSuccessDialog('Circulation & Loans Report', file.path, loans.length);
    }
  }

  Future<void> _exportCatalogCsv() async {
    final db = context.read<AppDatabase>();
    final items = await db.getCatalogInventoryReport();

    final file = await CsvExportService.saveCsvToFile(
      filenamePrefix: 'smart_biblio_catalog_inventory',
      csvContent: CsvExportService.generateCatalogInventoryCsv(items),
    );

    if (mounted) {
      _showExportSuccessDialog('Catalog Inventory Report', file.path, items.length);
    }
  }

  void _showExportSuccessDialog(String title, String path, int recordCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.file_download_done_rounded, color: AppColors.success, size: 28),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully generated CSV with $recordCount records!'),
            const SizedBox(height: 12),
            const Text('Saved to disk at:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                path,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GOVERNANCE & CONFIGURATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'System Policies, Audit Trail & Data Exports',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Sub Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            dividerColor: AppColors.border,
            tabs: const [
              Tab(
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('System Policies & Hardware Defaults'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Audit Trail & CSV Reports'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSettingsTab(),
                _buildAuditTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: SYSTEM SETTINGS
  // ==========================================
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_settingsFeedback != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _settingsFeedback!,
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Section 1: Library Identity & Circulation Rules
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Library Identity & Lending Rules',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _libraryNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Library / Institution Name *',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _currencyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Currency Code *',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _loanDurationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Standard Loan Duration (Days) *',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) =>
                              val == null || int.tryParse(val) == null ? 'Valid integer' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _maxLoansCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Max Concurrent Loans / Student *',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) =>
                              val == null || int.tryParse(val) == null ? 'Valid integer' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _finePerDayCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Overdue Fine / Day *',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) =>
                              val == null || double.tryParse(val) == null ? 'Valid number' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _gracePeriodCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Grace Period (Days) *',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) =>
                              val == null || int.tryParse(val) == null ? 'Valid integer' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Switch(
                        value: _allowReturnOthers,
                        onChanged: (val) => setState(() => _allowReturnOthers = val),
                        activeThumbColor: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Allow Returning Other Members\' Books',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'When enabled, any student can drop off a book borrowed by a peer at the self-service kiosk',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 2: Hardware & Interactive Kiosk Preferences
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hardware & Kiosk Terminal Behavior',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _autoTimeoutCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Kiosk Auto-Timeout (Seconds) *',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) =>
                              val == null || int.tryParse(val) == null ? 'Valid integer' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _debounceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'RFID Debounce Window (ms) *',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) =>
                              val == null || int.tryParse(val) == null ? 'Valid integer' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _readerPort,
                          decoration: const InputDecoration(
                            labelText: 'Default Reader Port',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          items: const [
                            DropdownMenuItem(value: 100, child: Text('USB Port 100 (Default)')),
                            DropdownMenuItem(value: 0, child: Text('Serial COM1 (Port 0)')),
                            DropdownMenuItem(value: 1, child: Text('Serial COM2 (Port 1)')),
                            DropdownMenuItem(value: 2, child: Text('Serial COM3 (Port 2)')),
                            DropdownMenuItem(value: 3, child: Text('Serial COM4 (Port 3)')),
                          ],
                          onChanged: (val) => setState(() => _readerPort = val ?? 100),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _readerBaud,
                          decoration: const InputDecoration(
                            labelText: 'Default Baud Rate',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                          items: const [
                            DropdownMenuItem(value: 115200, child: Text('115200 bps')),
                            DropdownMenuItem(value: 57600, child: Text('57600 bps')),
                            DropdownMenuItem(value: 38400, child: Text('38400 bps')),
                            DropdownMenuItem(value: 9600, child: Text('9600 bps')),
                          ],
                          onChanged: (val) => setState(() => _readerBaud = val ?? 115200),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Actions Bar
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isSavingSettings ? null : _saveSettings,
                  icon: _isSavingSettings
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('SAVE SETTINGS'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _restoreDefaults,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('RESTORE FACTORY DEFAULTS'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: AUDIT TRAIL & CSV EXPORTS
  // ==========================================
  Widget _buildAuditTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Export Action Buttons Bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Data Export Center',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              const Text(
                'Export comprehensive reports in standard CSV format for Excel/PowerBI',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _exportAuditCsv,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('EXPORT AUDIT LOGS'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _exportLoansCsv,
                    icon: const Icon(Icons.table_chart_rounded, size: 18),
                    label: const Text('EXPORT CIRCULATION (CSV)'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _exportCatalogCsv,
                    icon: const Icon(Icons.inventory_2_rounded, size: 18),
                    label: const Text('EXPORT INVENTORY (CSV)'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Filter Controls
        Row(
          children: [
            // Search Input
            Expanded(
              flex: 2,
              child: TextField(
                controller: _auditSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search audit trail by detail keyword, student ID, copy ID...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _auditSearchCtrl.clear();
                      _loadAuditLogs();
                    },
                  ),
                ),
                onSubmitted: (_) => _loadAuditLogs(),
              ),
            ),
            const SizedBox(width: 16),

            // Action Filter Dropdown
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedActionFilter,
                decoration: const InputDecoration(
                  labelText: 'Filter by Action',
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                ),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Actions')),
                  DropdownMenuItem(value: 'BOOK_BORROWED', child: Text('Book Borrowed')),
                  DropdownMenuItem(value: 'BOOK_RETURNED', child: Text('Book Returned')),
                  DropdownMenuItem(value: 'LOAN_RENEWED', child: Text('Loan Renewed')),
                  DropdownMenuItem(value: 'TAG_WRITTEN', child: Text('Tag Written / Encoded')),
                  DropdownMenuItem(value: 'CARD_ASSIGNED', child: Text('Card Assigned')),
                  DropdownMenuItem(value: 'CARD_REPLACED', child: Text('Card Replaced')),
                  DropdownMenuItem(value: 'FINE_PAID', child: Text('Fine Paid')),
                  DropdownMenuItem(value: 'FINE_WAIVED', child: Text('Fine Waived')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedActionFilter = val);
                    _loadAuditLogs();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),

            // Refresh Button
            IconButton.filledTonal(
              onPressed: _loadAuditLogs,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Audit Trail',
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Audit Table / List
        Expanded(
          child: _isLoadingAudit
              ? const Center(child: CircularProgressIndicator())
              : _auditLogs.isEmpty
                  ? const Center(
                      child: Text('No audit log entries found matching criteria.',
                          style: TextStyle(color: AppColors.textMuted)),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          itemCount: _auditLogs.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final log = _auditLogs[index];
                            return _buildAuditRow(log);
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildAuditRow(AuditLog log) {
    Color badgeColor = AppColors.primary;
    IconData actionIcon = Icons.info_outline_rounded;

    switch (log.action) {
      case 'BOOK_BORROWED':
        badgeColor = AppColors.primary;
        actionIcon = Icons.arrow_upward_rounded;
        break;
      case 'BOOK_RETURNED':
        badgeColor = AppColors.success;
        actionIcon = Icons.arrow_downward_rounded;
        break;
      case 'LOAN_RENEWED':
        badgeColor = AppColors.secondary;
        actionIcon = Icons.update_rounded;
        break;
      case 'TAG_WRITTEN':
        badgeColor = AppColors.warning;
        actionIcon = Icons.nfc_rounded;
        break;
      case 'CARD_ASSIGNED':
      case 'CARD_REPLACED':
        badgeColor = AppColors.secondary;
        actionIcon = Icons.credit_card_rounded;
        break;
      case 'FINE_PAID':
        badgeColor = AppColors.success;
        actionIcon = Icons.payment_rounded;
        break;
      case 'FINE_WAIVED':
        badgeColor = AppColors.danger;
        actionIcon = Icons.money_off_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Action Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(actionIcon, size: 18, color: badgeColor),
          ),
          const SizedBox(width: 14),

          // Action Tag
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    log.action,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateFormat.format(log.timestamp),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          // Actor
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.actorType.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  log.actorId,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Details
          Expanded(
            child: Text(
              log.details,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
