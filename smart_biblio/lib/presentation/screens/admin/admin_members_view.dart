import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/member.dart';
import '../../../domain/rfid/rfid_manager.dart';
import '../../../domain/rfid/rfid_models.dart';
import '../../providers/locale_provider.dart';

class AdminMembersView extends StatefulWidget {
  const AdminMembersView({super.key});

  @override
  State<AdminMembersView> createState() => _AdminMembersViewState();
}

class _AdminMembersViewState extends State<AdminMembersView> {
  List<Member> _members = [];
  Map<String, String> _memberCards = {};
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
    final cards = await db.getAllActiveMemberCards();
    if (mounted) {
      setState(() {
        _members = members;
        _memberCards = cards;
        _isLoading = false;
      });
    }
  }

  List<Member> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    final q = _searchQuery.toLowerCase();
    return _members.where((m) {
      final card = _memberCards[m.id]?.toLowerCase() ?? '';
      return m.fullName.toLowerCase().contains(q) ||
          m.studentNumber.toLowerCase().contains(q) ||
          m.gradeDepartment.toLowerCase().contains(q) ||
          card.contains(q);
    }).toList();
  }

  Future<void> _confirmDeleteMember(Member member, LocaleProvider locale) async {
    final db = context.read<AppDatabase>();
    final activeLoans = await db.getActiveLoansForMember(member.id);
    if (!mounted) return;

    if (activeLoans.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locale.t('student_has_loans_warning'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            locale.isFrench
                ? 'Cet étudiant possède encore ${activeLoans.length} livre(s) non retourné(s). Veuillez d\'abord effectuer le retour des livres avant de le supprimer.'
                : 'This student still has ${activeLoans.length} unreturned book(s). Please return the borrowed books first before deleting.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
              child: Text(locale.t('close')),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Text(locale.t('delete_student_confirm_title')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locale.t('delete_student_confirm_msg'),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${member.studentNumber} • ${member.gradeDepartment}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(locale.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(locale.t('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await db.deleteMember(member.id);
        await _loadMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locale.t('student_deleted_success')),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddStudentDialog(
        nextStudentIndex: _members.length + 1,
        onRegistered: _loadMembers,
      ),
    );
  }

  void _showAssignCardDialog(Member member) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AssignCardDialog(
        member: member,
        currentCardEpc: _memberCards[member.id],
        onAssigned: _loadMembers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.t('students_badge'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.t('students_title'),
                    style: const TextStyle(
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
                label: Text(locale.t('register_student')),
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
              hintText: locale.t('search_student_placeholder'),
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
                      final cardEpc = _memberCards[member.id];

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
                                      const SizedBox(width: 8),

                                      // RFID Card Badge
                                      if (cardEpc != null && cardEpc.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: AppColors.primary.withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.nfc_rounded, size: 12, color: AppColors.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                'RFID: $cardEpc',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'monospace',
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.credit_card_off_rounded, size: 12, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(
                                                locale.t('no_card_assigned'),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${member.studentNumber}  •  ${member.gradeDepartment}  •  Max: ${member.maxLoans} books${member.email.isNotEmpty ? "  •  ${member.email}" : ""}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),

                            // Assign/Change RFID Card Button
                            OutlinedButton.icon(
                              onPressed: () => _showAssignCardDialog(member),
                              icon: const Icon(Icons.credit_card_rounded, size: 16),
                              label: Text(cardEpc != null && cardEpc.isNotEmpty ? locale.t('reassign_card') : locale.t('assign_card')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Delete Member Button
                            IconButton(
                              tooltip: locale.t('delete_student'),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.danger,
                                size: 20,
                              ),
                              onPressed: () => _confirmDeleteMember(member, locale),
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

/// Rich dialog to Register a Student and scan their physical RFID card simultaneously
class _AddStudentDialog extends StatefulWidget {
  final int nextStudentIndex;
  final VoidCallback onRegistered;

  const _AddStudentDialog({
    required this.nextStudentIndex,
    required this.onRegistered,
  });

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _keyboardFocusNode = FocusNode();
  final _wedgeBuffer = StringBuffer();
  Timer? _wedgeTimer;

  late TextEditingController _nameController;
  late TextEditingController _studentNumController;
  late TextEditingController _deptController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _epcController;

  int _maxLoans = 5;
  bool _isScanning = false;
  bool _isWriting = false;
  bool _isSubmitting = false;
  bool _cardWasActivated = false;
  bool _codeGeneratedOnly = false;
  bool _autoActivateOnSwipe = true;
  String? _duplicateWarning;

  StreamSubscription? _tagSub;
  StreamSubscription? _cardSub;
  StreamSubscription? _connSub;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _studentNumController = TextEditingController(
      text: 'STU-2026-00${widget.nextStudentIndex}',
    );
    _deptController = TextEditingController(text: 'Computer Science');
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _epcController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRfidScanning();
      _keyboardFocusNode.requestFocus();
    });
  }

  void _initRfidScanning() {
    final rfid = context.read<RfidManager>();
    rfid.setMode(RfidReaderMode.studentCardScan);

    _tagSub = rfid.onTagsInventory.listen((tags) {
      if (tags.isNotEmpty) {
        _onCardDetected(tags.first.cleanEpc);
      }
    });

    _cardSub = rfid.onCardDetected.listen((epc) {
      _onCardDetected(epc);
    });

    _connSub = rfid.onConnectionStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _onCardDetected(String rawEpc) async {
    final clean = rawEpc.trim().toUpperCase();
    if (clean.isEmpty) return;
    if (_epcController.text == clean) return; // already set

    final isEmptyCard = RfidManager.isBlankOrEmptyEpc(clean);

    // If an empty/blank card is swiped and auto-activate is enabled, write student ID immediately
    if (isEmptyCard && _autoActivateOnSwipe && _studentNumController.text.trim().isNotEmpty) {
      await _writeStudentIdToCard();
      return;
    }

    setState(() {
      _epcController.text = clean;
      _cardWasActivated = !isEmptyCard;
    });

    if (!mounted) return;
    final rfid = context.read<RfidManager>();
    final db = context.read<AppDatabase>();

    await rfid.beepSuccess();

    if (!isEmptyCard) {
      // Check if card is currently assigned to another member
      final existingMember = await db.findMemberByCardEpc(clean);
      if (mounted) {
        setState(() {
          if (existingMember != null) {
            _duplicateWarning =
                '⚠️ Card currently assigned to ${existingMember.fullName} (${existingMember.studentNumber}). Registering will reassign it.';
          } else {
            _duplicateWarning = null;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _duplicateWarning = null;
        });
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        final captured = _wedgeBuffer.toString().trim().toUpperCase();
        _wedgeBuffer.clear();
        if (captured.length >= 4) {
          _onCardDetected(captured);
        }
      } else {
        final char = event.character;
        if (char != null && char.isNotEmpty && RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
          _wedgeBuffer.write(char);
          _wedgeTimer?.cancel();
          _wedgeTimer = Timer(const Duration(milliseconds: 300), () {
            final captured = _wedgeBuffer.toString().trim().toUpperCase();
            _wedgeBuffer.clear();
            if (captured.length >= 8) {
              _onCardDetected(captured);
            }
          });
        }
      }
    }
  }

  Future<void> _scanFromAntenna() async {
    setState(() => _isScanning = true);
    try {
      final rfid = context.read<RfidManager>();
      if (!rfid.isConnected) {
        await rfid.connect();
      }
      final tags = await rfid.device.inventory();
      if (tags.isNotEmpty) {
        await _onCardDetected(tags.first.cleanEpc);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No RFID card detected on antenna. Place a card closer to reader.'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _writeStudentIdToCard() async {
    final studentNum = _studentNumController.text.trim();
    if (studentNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Student Number / ID first before activating card.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final hexEpc = RfidManager.formatStudentIdToHexEpc(studentNum);
    setState(() => _isWriting = true);

    try {
      final rfid = context.read<RfidManager>();
      if (!rfid.isConnected) {
        await rfid.connect();
      }
      final success = await rfid.writeEpc(hexEpc);
      if (success) {
        if (mounted) {
          setState(() {
            _epcController.text = hexEpc;
            _cardWasActivated = true;
            _codeGeneratedOnly = false;
            _duplicateWarning = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Card activated! Student ID encoded into RFID Card EPC: $hexEpc'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not write to physical tag. Ensure a writable UHF RFID card is on the reader, or click "Generate Code" to assign logically.',
              ),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Use Code',
                textColor: Colors.white,
                onPressed: () {
                  if (!mounted) return;
                  setState(() {
                    _epcController.text = hexEpc;
                    _cardWasActivated = false;
                    _codeGeneratedOnly = true;
                  });
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Encoding error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWriting = false);
    }
  }

  void _generateStudentEpcCode() {
    final studentNum = _studentNumController.text.trim();
    if (studentNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Student Number / ID first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final hexEpc = RfidManager.formatStudentIdToHexEpc(studentNum);
    setState(() {
      _epcController.text = hexEpc;
      _cardWasActivated = false;
      _codeGeneratedOnly = true;
      _duplicateWarning = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final studentNum = _studentNumController.text.trim();
    final cardEpc = _epcController.text.trim().toUpperCase();

    setState(() => _isSubmitting = true);
    try {
      const uuid = Uuid();
      final db = context.read<AppDatabase>();
      final rfid = context.read<RfidManager>();

      final member = Member(
        id: uuid.v4(),
        studentNumber: studentNum,
        fullName: name,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        gradeDepartment: _deptController.text.trim(),
        maxLoans: _maxLoans,
        status: 'active',
      );

      await db.insertMember(member);

      if (cardEpc.isNotEmpty) {
        await db.assignCardToMember(
          memberId: member.id,
          epc: cardEpc,
          cardType: 'student',
        );
      }

      await rfid.beepSuccess();

      if (mounted) {
        Navigator.of(context).pop();
        widget.onRegistered();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cardEpc.isNotEmpty
                  ? 'Student $name registered with RFID Card $cardEpc!'
                  : 'Student $name registered successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _tagSub?.cancel();
    _cardSub?.cancel();
    _connSub?.cancel();
    _wedgeTimer?.cancel();
    _keyboardFocusNode.dispose();
    _nameController.dispose();
    _studentNumController.dispose();
    _deptController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _epcController.dispose();

    // Restore idle mode
    try {
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      context.read<RfidManager>().setMode(RfidReaderMode.idle);
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rfid = context.watch<RfidManager>();
    final locale = context.watch<LocaleProvider>();
    final hasCardScanned = _epcController.text.trim().isNotEmpty;
    final isEmptyCard = hasCardScanned && RfidManager.isBlankOrEmptyEpc(_epcController.text);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register Student & Scan RFID Card',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Scan or tap student card, then enter personal & academic details',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // RFID Reader Connection Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: rfid.isConnected
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: rfid.isConnected
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.danger.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          rfid.isConnected ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                          size: 16,
                          color: rfid.isConnected ? AppColors.success : AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rfid.isConnected
                              ? 'RFID Reader Online (${rfid.isSimulated ? "Simulator" : "Port ${rfid.currentPort ?? 'USB'}"})'
                              : 'RFID Reader Disconnected',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: rfid.isConnected ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        const Spacer(),
                        if (!rfid.isConnected)
                          InkWell(
                            onTap: () async {
                              await rfid.connect();
                              if (mounted) setState(() {});
                            },
                            child: const Text(
                              'CONNECT READER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // RFID Card Scanning Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasCardScanned ? AppColors.success : AppColors.border,
                        width: hasCardScanned ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hasCardScanned ? Icons.check_circle_rounded : Icons.contactless_rounded,
                              color: hasCardScanned ? AppColors.success : AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              hasCardScanned ? 'STUDENT CARD DETECTED' : 'SCAN STUDENT RFID CARD',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: hasCardScanned ? AppColors.success : AppColors.primary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            if (hasCardScanned)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _epcController.clear();
                                    _duplicateWarning = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 14),
                                label: const Text('Re-scan', style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Place the student card or tag on the RFID antenna pad. Keystroke wedge & antenna auto-polling are active.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),

                        // EPC Field & Manual Scan Button
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _epcController,
                                onChanged: (val) {
                                  _onCardDetected(val);
                                },
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'RFID Card (EPC / UID)',
                                  hintText: 'Waiting for card scan on antenna...',
                                  filled: true,
                                  fillColor: AppColors.surfaceCard,
                                  prefixIcon: const Icon(Icons.credit_card_rounded, size: 18),
                                  suffixIcon: hasCardScanned
                                      ? const Icon(Icons.check_rounded, color: AppColors.success, size: 18)
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _isScanning ? null : _scanFromAntenna,
                              icon: _isScanning
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sensors_rounded, size: 16),
                              label: const Text('Scan Now'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                              ),
                            ),
                          ],
                        ),

                        // Status Banners
                        if (isEmptyCard) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.credit_card_off_rounded, size: 20, color: AppColors.warning),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        locale.t('empty_card_detected'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        locale.t('empty_card_hint'),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_cardWasActivated) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.success),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        locale.t('card_activated_success'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.success,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'EPC: ${_epcController.text} (${RfidManager.decodeHexEpcToText(_epcController.text)})',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_codeGeneratedOnly) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Code EPC assigné logiquement',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'EPC: ${_epcController.text}. Posez une carte RFID sur le lecteur et cliquez sur "⚡ ENCODER & ACTIVER LA CARTE" pour la programmer physiquement.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_duplicateWarning != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _duplicateWarning!,
                                    style: const TextStyle(fontSize: 11, color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Card Activation & Encoding Action Bar
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  FilledButton.icon(
                                    onPressed: _isWriting ? null : _writeStudentIdToCard,
                                    icon: _isWriting
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.black,
                                            ),
                                          )
                                        : const Icon(Icons.bolt_rounded, size: 16),
                                    label: Text(
                                      locale.t('write_and_activate_card'),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _generateStudentEpcCode,
                                    icon: const Icon(Icons.qr_code_rounded, size: 16),
                                    label: Text(
                                      locale.t('generate_card_code'),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  setState(() => _autoActivateOnSwipe = !_autoActivateOnSwipe);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: Checkbox(
                                          value: _autoActivateOnSwipe,
                                          activeColor: AppColors.primary,
                                          checkColor: Colors.black,
                                          onChanged: (val) {
                                            setState(() => _autoActivateOnSwipe = val ?? true);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          locale.t('auto_activate_label'),
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Student Information Form
                  const Text(
                    'STUDENT DETAILS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _nameController,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Full Name is required' : null,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'e.g. Ahmed Benali',
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _studentNumController,
                          onChanged: (_) => setState(() {}),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Student ID is required' : null,
                          decoration: const InputDecoration(
                            labelText: 'Student Number / ID *',
                            hintText: 'e.g. STU-2026-0042',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _deptController,
                          decoration: const InputDecoration(
                            labelText: 'Department / Grade *',
                            hintText: 'e.g. Computer Science',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'e.g. student@univ.edu',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'e.g. +213 555 123 456',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Borrowing Limit
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        const Text(
                          'Borrowing Limit (Max Books):',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _maxLoans > 1 ? () => setState(() => _maxLoans--) : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                        ),
                        Text(
                          _maxLoans.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          onPressed: _maxLoans < 10 ? () => setState(() => _maxLoans++) : null,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.how_to_reg_rounded, size: 18),
            label: Text(_isSubmitting ? 'REGISTERING...' : 'REGISTER STUDENT'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rich dialog to Reassign/Assign RFID card to an existing member with live scanning
class _AssignCardDialog extends StatefulWidget {
  final Member member;
  final String? currentCardEpc;
  final VoidCallback onAssigned;

  const _AssignCardDialog({
    required this.member,
    this.currentCardEpc,
    required this.onAssigned,
  });

  @override
  State<_AssignCardDialog> createState() => _AssignCardDialogState();
}

class _AssignCardDialogState extends State<_AssignCardDialog> {
  final _keyboardFocusNode = FocusNode();
  final _wedgeBuffer = StringBuffer();
  Timer? _wedgeTimer;

  late TextEditingController _epcController;
  bool _isScanning = false;
  bool _isWriting = false;
  bool _isSubmitting = false;
  bool _cardWasActivated = false;
  bool _codeGeneratedOnly = false;
  bool _autoActivateOnSwipe = true;
  String? _duplicateWarning;

  StreamSubscription? _tagSub;
  StreamSubscription? _cardSub;
  StreamSubscription? _connSub;

  @override
  void initState() {
    super.initState();
    _epcController = TextEditingController(text: widget.currentCardEpc ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRfidScanning();
      _keyboardFocusNode.requestFocus();
    });
  }

  void _initRfidScanning() {
    final rfid = context.read<RfidManager>();
    rfid.setMode(RfidReaderMode.studentCardScan);

    _tagSub = rfid.onTagsInventory.listen((tags) {
      if (tags.isNotEmpty) {
        _onCardDetected(tags.first.cleanEpc);
      }
    });

    _cardSub = rfid.onCardDetected.listen((epc) {
      _onCardDetected(epc);
    });

    _connSub = rfid.onConnectionStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _onCardDetected(String rawEpc) async {
    final clean = rawEpc.trim().toUpperCase();
    if (clean.isEmpty) return;
    if (_epcController.text == clean) return;

    final isEmptyCard = RfidManager.isBlankOrEmptyEpc(clean);

    // If card is empty and auto-activate is turned on, write student ID immediately
    if (isEmptyCard && _autoActivateOnSwipe) {
      await _writeStudentIdToCard();
      return;
    }

    setState(() {
      _epcController.text = clean;
      _cardWasActivated = !isEmptyCard;
    });

    if (!mounted) return;
    final rfid = context.read<RfidManager>();
    final db = context.read<AppDatabase>();

    await rfid.beepSuccess();

    if (!isEmptyCard) {
      final existingMember = await db.findMemberByCardEpc(clean);
      if (mounted) {
        setState(() {
          if (existingMember != null && existingMember.id != widget.member.id) {
            _duplicateWarning =
                '⚠️ Card currently assigned to ${existingMember.fullName} (${existingMember.studentNumber}). Assigning will transfer it.';
          } else {
            _duplicateWarning = null;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _duplicateWarning = null;
        });
      }
    }
  }

  Future<void> _writeStudentIdToCard() async {
    final studentNum = widget.member.studentNumber.trim();
    final hexEpc = RfidManager.formatStudentIdToHexEpc(studentNum);
    setState(() => _isWriting = true);

    try {
      final rfid = context.read<RfidManager>();
      if (!rfid.isConnected) {
        await rfid.connect();
      }
      final success = await rfid.writeEpc(hexEpc);
      if (success) {
        if (mounted) {
          setState(() {
            _epcController.text = hexEpc;
            _cardWasActivated = true;
            _codeGeneratedOnly = false;
            _duplicateWarning = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Card activated! Student ID encoded into RFID Card EPC: $hexEpc'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not write to physical tag. Ensure a writable UHF RFID card is on the reader, or click "Generate Code" to assign logically.',
              ),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Use Code',
                textColor: Colors.white,
                onPressed: () {
                  if (!mounted) return;
                  setState(() {
                    _epcController.text = hexEpc;
                    _cardWasActivated = false;
                    _codeGeneratedOnly = true;
                  });
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Encoding error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWriting = false);
    }
  }

  void _generateStudentEpcCode() {
    final hexEpc = RfidManager.formatStudentIdToHexEpc(widget.member.studentNumber);
    setState(() {
      _epcController.text = hexEpc;
      _cardWasActivated = false;
      _codeGeneratedOnly = true;
      _duplicateWarning = null;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        final captured = _wedgeBuffer.toString().trim().toUpperCase();
        _wedgeBuffer.clear();
        if (captured.length >= 4) {
          _onCardDetected(captured);
        }
      } else {
        final char = event.character;
        if (char != null && char.isNotEmpty && RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
          _wedgeBuffer.write(char);
          _wedgeTimer?.cancel();
          _wedgeTimer = Timer(const Duration(milliseconds: 300), () {
            final captured = _wedgeBuffer.toString().trim().toUpperCase();
            _wedgeBuffer.clear();
            if (captured.length >= 8) {
              _onCardDetected(captured);
            }
          });
        }
      }
    }
  }

  Future<void> _scanFromAntenna() async {
    setState(() => _isScanning = true);
    try {
      final rfid = context.read<RfidManager>();
      if (!rfid.isConnected) {
        await rfid.connect();
      }
      final tags = await rfid.device.inventory();
      if (tags.isNotEmpty) {
        await _onCardDetected(tags.first.cleanEpc);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No RFID card detected on antenna. Place a card closer.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _submit() async {
    final epc = _epcController.text.trim().toUpperCase();
    if (epc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan or enter an RFID card EPC.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final db = context.read<AppDatabase>();
      final rfid = context.read<RfidManager>();

      await db.assignCardToMember(
        memberId: widget.member.id,
        epc: epc,
        cardType: 'student',
      );

      await rfid.beepSuccess();

      if (mounted) {
        Navigator.of(context).pop();
        widget.onAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('RFID card $epc activated for ${widget.member.fullName}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _tagSub?.cancel();
    _cardSub?.cancel();
    _connSub?.cancel();
    _wedgeTimer?.cancel();
    _keyboardFocusNode.dispose();
    _epcController.dispose();

    try {
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      context.read<RfidManager>().setMode(RfidReaderMode.idle);
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rfid = context.watch<RfidManager>();
    final locale = context.watch<LocaleProvider>();
    final hasCardScanned = _epcController.text.trim().isNotEmpty;
    final isEmptyCard = hasCardScanned && RfidManager.isBlankOrEmptyEpc(_epcController.text);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        title: Row(
          children: [
            const Icon(Icons.credit_card_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Assign Card: ${widget.member.fullName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reader status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: rfid.isConnected
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: rfid.isConnected
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.danger.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        rfid.isConnected ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                        size: 16,
                        color: rfid.isConnected ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rfid.isConnected
                            ? 'RFID Reader Online (${rfid.isSimulated ? "Simulator" : "Port ${rfid.currentPort ?? 'USB'}"})'
                            : 'RFID Reader Disconnected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rfid.isConnected ? AppColors.success : AppColors.danger,
                        ),
                      ),
                      const Spacer(),
                      if (!rfid.isConnected)
                        InkWell(
                          onTap: () async {
                            await rfid.connect();
                            if (mounted) setState(() {});
                          },
                          child: const Text(
                            'CONNECT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Place the RFID student card on the antenna pad or enter the EPC directly. Blank cards can be encoded directly with the student ID.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _epcController,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'RFID Card EPC / UID *',
                          hintText: 'Waiting for card scan...',
                          filled: true,
                          fillColor: AppColors.surface,
                          suffixIcon: hasCardScanned
                              ? const Icon(Icons.check_rounded, color: AppColors.success)
                              : const Icon(Icons.contactless_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _isScanning ? null : _scanFromAntenna,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sensors_rounded, size: 16),
                      label: const Text('Scan Tag'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      ),
                    ),
                  ],
                ),

                // Status Banners
                if (isEmptyCard) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card_off_rounded, size: 20, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locale.t('empty_card_detected'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                locale.t('empty_card_hint'),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_cardWasActivated) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locale.t('card_activated_success'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'EPC: ${_epcController.text} (${RfidManager.decodeHexEpcToText(_epcController.text)})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_codeGeneratedOnly) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Code EPC assigné logiquement',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'EPC: ${_epcController.text}. Posez une carte RFID sur le lecteur et cliquez sur "⚡ ENCODER & ACTIVER LA CARTE" pour la programmer physiquement.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_duplicateWarning != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _duplicateWarning!,
                            style: const TextStyle(fontSize: 11, color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Card Activation Action Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: _isWriting ? null : _writeStudentIdToCard,
                            icon: _isWriting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.bolt_rounded, size: 16),
                            label: Text(
                              locale.t('write_and_activate_card'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _generateStudentEpcCode,
                            icon: const Icon(Icons.qr_code_rounded, size: 16),
                            label: Text(
                              locale.t('generate_card_code'),
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          setState(() => _autoActivateOnSwipe = !_autoActivateOnSwipe);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: Checkbox(
                                  value: _autoActivateOnSwipe,
                                  activeColor: AppColors.primary,
                                  checkColor: Colors.black,
                                  onChanged: (val) {
                                    setState(() => _autoActivateOnSwipe = val ?? true);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  locale.t('auto_activate_label'),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_isSubmitting ? 'ACTIVATING...' : 'ASSIGN & ACTIVATE'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
