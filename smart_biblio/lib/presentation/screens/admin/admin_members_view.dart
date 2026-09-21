import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/member.dart';
import '../../../domain/rfid/rfid_manager.dart';

class AdminMembersView extends StatefulWidget {
  const AdminMembersView({super.key});

  @override
  State<AdminMembersView> createState() => _AdminMembersViewState();
}

class _AdminMembersViewState extends State<AdminMembersView> {
  List<Member> _members = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final db = context.read<AppDatabase>();
    final members = await db.getAllMembers();
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  List<Member> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    final q = _searchQuery.toLowerCase();
    return _members.where((m) {
      return m.fullName.toLowerCase().contains(q) ||
          m.studentNumber.toLowerCase().contains(q) ||
          m.gradeDepartment.toLowerCase().contains(q);
    }).toList();
  }

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    final studentNumController = TextEditingController(
        text: 'STU-2026-00${_members.length + 1}');
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final deptController = TextEditingController(text: 'Computer Science');
    int maxLoans = 5;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_add_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Register New Member / Student'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: studentNumController,
                        decoration: const InputDecoration(
                          labelText: 'Student Number / ID *',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: deptController,
                        decoration: const InputDecoration(
                          labelText: 'Department / Grade *',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Borrowing Limit (Max Books):',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          const Spacer(),
                          IconButton(
                            onPressed: maxLoans > 1
                                ? () => setDialogState(() => maxLoans--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                          ),
                          Text(maxLoans.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            onPressed: maxLoans < 10
                                ? () => setDialogState(() => maxLoans++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty ||
                        studentNumController.text.trim().isEmpty) {
                      return;
                    }

                    const uuid = Uuid();
                    final db = context.read<AppDatabase>();
                    final member = Member(
                      id: uuid.v4(),
                      studentNumber: studentNumController.text.trim(),
                      fullName: nameController.text.trim(),
                      email: emailController.text.trim(),
                      phone: phoneController.text.trim(),
                      gradeDepartment: deptController.text.trim(),
                      maxLoans: maxLoans,
                      status: 'active',
                    );

                    await db.insertMember(member);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      _loadMembers();
                    }
                  },
                  child: const Text('REGISTER'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAssignCardDialog(Member member) {
    final epcController = TextEditingController(
      text: 'CARD${DateTime.now().millisecondsSinceEpoch.toString().padLeft(20, '0')}',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderLight),
          ),
          title: Row(
            children: [
              const Icon(Icons.credit_card_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Assign RFID Card: ${member.fullName}'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Place an RFID card on the reader antenna pad or enter the EPC directly. Assigning a new card automatically deactivates any previously lost card.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: epcController,
                  decoration: const InputDecoration(
                    labelText: 'RFID Card EPC / UID *',
                    filled: true,
                    fillColor: AppColors.surface,
                    suffixIcon: Icon(Icons.contactless_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final rfid = context.read<RfidManager>();
                    final tags = await rfid.device.inventory();
                    if (tags.isNotEmpty) {
                      epcController.text = tags.first.cleanEpc;
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No RFID card detected in reader field.'),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.sensors_rounded, size: 16),
                  label: const Text('Read Tag from Antenna'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () async {
                final epc = epcController.text.trim();
                if (epc.isEmpty) return;

                final db = context.read<AppDatabase>();
                await db.assignCardToMember(
                  memberId: member.id,
                  epc: epc,
                  cardType: 'student',
                );

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('RFID card $epc assigned to ${member.fullName}!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('ASSIGN & ACTIVATE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredMembers;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Add Button
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STUDENTS & RFID ACCESS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Member Management',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showAddMemberDialog,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('REGISTER STUDENT'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by student name, ID number, or department...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Members List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No matching students found.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final member = filtered[index];
                      final isActive = member.isActive;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : AppColors.danger.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  member.fullName.isNotEmpty
                                      ? member.fullName[0].toUpperCase()
                                      : 'M',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: isActive ? AppColors.primary : AppColors.danger,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        member.fullName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? AppColors.success.withValues(alpha: 0.12)
                                              : AppColors.danger.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isActive ? AppColors.success : AppColors.danger,
                                          ),
                                        ),
                                        child: Text(
                                          member.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isActive ? AppColors.success : AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${member.studentNumber}  •  ${member.gradeDepartment}  •  Max: ${member.maxLoans} books',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),

                            // Assign RFID Card Button
                            OutlinedButton.icon(
                              onPressed: () => _showAssignCardDialog(member),
                              icon: const Icon(Icons.credit_card_rounded, size: 16),
                              label: const Text('ASSIGN RFID CARD'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
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
}
