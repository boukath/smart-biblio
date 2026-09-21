import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/fine.dart';
import '../../../data/models/loan.dart';

class AdminCirculationView extends StatefulWidget {
  const AdminCirculationView({super.key});

  @override
  State<AdminCirculationView> createState() => _AdminCirculationViewState();
}

class _AdminCirculationViewState extends State<AdminCirculationView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Loan> _loans = [];
  List<Fine> _fines = [];
  String _loanFilter = 'all'; // 'all', 'active', 'overdue', 'returned'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = context.read<AppDatabase>();
    final loans = await db.getAllLoans();
    final fines = await db.getAllFines();

    if (mounted) {
      setState(() {
        _loans = loans;
        _fines = fines;
        _isLoading = false;
      });
    }
  }

  List<Loan> get _filteredLoans {
    if (_loanFilter == 'all') return _loans;
    if (_loanFilter == 'overdue') {
      return _loans.where((l) => l.isOverdue).toList();
    }
    return _loans.where((l) => l.status.toLowerCase() == _loanFilter).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CIRCULATION & OVERDUE MANAGEMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Loans & Fines Center',
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
                tooltip: 'Refresh',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            dividerColor: AppColors.border,
            tabs: [
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.sync_alt_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('All Circulation Loans (${_loans.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text('Fines & Penalties (${_fines.length})'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Tab View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: LOANS
                _buildLoansTab(),

                // TAB 2: FINES
                _buildFinesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansTab() {
    final filtered = _filteredLoans;

    return Column(
      children: [
        // Filter Chips
        Row(
          children: [
            _buildFilterChip('all', 'All (${_loans.length})'),
            const SizedBox(width: 8),
            _buildFilterChip('active', 'Active (${_loans.where((l) => l.isActive).length})'),
            const SizedBox(width: 8),
            _buildFilterChip('overdue', 'Overdue (${_loans.where((l) => l.isOverdue).length})'),
            const SizedBox(width: 8),
            _buildFilterChip('returned', 'Returned (${_loans.where((l) => l.isReturned).length})'),
          ],
        ),
        const SizedBox(height: 16),

        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No loans in this category.',
                      style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final loan = filtered[index];
                    final isOverdue = loan.isOverdue;
                    final isReturned = loan.isReturned;

                    Color statusColor = AppColors.primary;
                    String statusLabel = 'ACTIVE';
                    if (isReturned) {
                      statusColor = AppColors.success;
                      statusLabel = 'RETURNED';
                    } else if (isOverdue) {
                      statusColor = AppColors.danger;
                      statusLabel = 'OVERDUE';
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOverdue ? AppColors.danger.withValues(alpha: 0.5) : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.bookmark_rounded, color: statusColor, size: 20),
                          ),
                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      loan.transactionNo,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Member: ${loan.memberId}  •  Copy: ${loan.copyId}  •  EPC: ${loan.rfidEpc}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Due: ${DateFormat('dd/MM/yyyy').format(loan.dueAt)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isOverdue ? AppColors.danger : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Borrowed: ${DateFormat('dd MMM yyyy').format(loan.borrowedAt)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),

                          if (!isReturned) ...[
                            const SizedBox(width: 16),
                            FilledButton.tonal(
                              onPressed: () async {
                                final db = context.read<AppDatabase>();
                                await db.renewLoan(loan.id, 14);
                                _loadData();
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              child: const Text('RENEW (+14D)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFinesTab() {
    if (_fines.isEmpty) {
      return const Center(
        child: Text('No fines recorded.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView.separated(
      itemCount: _fines.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final fine = _fines[index];
        final isPending = fine.isPending;

        Color statusColor = isPending ? AppColors.warning : AppColors.success;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 20),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fine.amount.toStringAsFixed(0)} ${fine.currency}  •  ${fine.reason}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member ID: ${fine.memberId}  •  Status: ${fine.status.toUpperCase()}  •  Date: ${DateFormat('dd MMM yyyy').format(fine.createdAt)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              if (isPending) ...[
                OutlinedButton(
                  onPressed: () async {
                    final db = context.read<AppDatabase>();
                    await db.waiveFine(fine.id);
                    _loadData();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.borderLight),
                  ),
                  child: const Text('WAIVE'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () async {
                    final db = context.read<AppDatabase>();
                    await db.payFine(fine.id);
                    _loadData();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('MARK PAID'),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fine.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _loanFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _loanFilter = value),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}
