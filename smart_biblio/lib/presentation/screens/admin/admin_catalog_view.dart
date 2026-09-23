import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_copy.dart';
import '../../../domain/rfid/rfid_manager.dart';
import '../../../domain/rfid/rfid_models.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/rfid_radar_animation.dart';

class AdminCatalogView extends StatefulWidget {
  const AdminCatalogView({super.key});

  @override
  State<AdminCatalogView> createState() => _AdminCatalogViewState();
}

class _AdminCatalogViewState extends State<AdminCatalogView> {
  List<Book> _books = [];
  Map<String, List<BookCopy>> _copiesMap = {};
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    final db = context.read<AppDatabase>();
    final books = await db.getAllBooks();
    final copiesMap = <String, List<BookCopy>>{};

    for (final b in books) {
      copiesMap[b.id] = await db.getCopiesForBook(b.id);
    }

    if (mounted) {
      setState(() {
        _books = books;
        _copiesMap = copiesMap;
        _isLoading = false;
      });
    }
  }

  List<Book> get _filteredBooks {
    if (_searchQuery.isEmpty) return _books;
    final q = _searchQuery.toLowerCase();
    return _books.where((b) {
      return b.title.toLowerCase().contains(q) ||
          b.subtitle.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.isbn.toLowerCase().contains(q) ||
          b.callNumber.toLowerCase().contains(q) ||
          b.category.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmDeleteBook(Book book, LocaleProvider locale) async {
    final db = context.read<AppDatabase>();
    final copies = _copiesMap[book.id] ?? [];

    // Check if any copy is on loan
    bool hasActiveLoan = false;
    for (final c in copies) {
      final loan = await db.getActiveLoanForCopy(c.id);
      if (loan != null) {
        hasActiveLoan = true;
        break;
      }
    }
    if (!mounted) return;

    if (hasActiveLoan) {
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
                  locale.t('book_has_loans_warning'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            locale.isFrench
                ? 'Un ou plusieurs exemplaires de ce livre sont actuellement prêtés. Vous ne pouvez pas supprimer un livre dont les exemplaires sont en circulation.'
                : 'One or more copies of this book are currently checked out. You cannot delete a book with copies in circulation.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
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
            Text(locale.t('delete_book_confirm_title')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locale.t('delete_book_confirm_msg'),
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
                    book.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${book.author} • ISBN: ${book.isbn} • ${copies.length} ${locale.t('copies_count')}',
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
        await db.deleteBook(book.id);
        await _loadCatalog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locale.t('book_deleted_success')),
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

  void _showAddBookWizard() {
    int currentStep = 1; // Step 1: Scan Physical RFID Label, Step 2: Rich Metadata Entry
    final List<String> scannedEpcs = [];

    final titleController = TextEditingController();
    final subtitleController = TextEditingController();
    final authorController = TextEditingController();
    final isbnController = TextEditingController();
    final callNumberController = TextEditingController(text: '005.133 CS');
    final publisherController = TextEditingController();
    final publishYearController = TextEditingController(text: '2024');
    final editionController = TextEditingController(text: '1st Edition');
    final pageCountController = TextEditingController(text: '350');
    final shelfController = TextEditingController(text: 'CS-101-A');
    final descriptionController = TextEditingController();
    final manualEpcController = TextEditingController();

    String selectedCategory = 'Computer Science';
    String selectedLanguage = 'English';
    String selectedFormat = 'Paperback';

    final categories = [
      'Computer Science',
      'Artificial Intelligence',
      'Data Science & AI',
      'Software Engineering',
      'Electrical & Electronics',
      'Mechanical Engineering',
      'Civil Engineering',
      'Mathematics & Statistics',
      'Physics & Chemistry',
      'Medicine & Health Sciences',
      'Law & Political Science',
      'Business & Economics',
      'Literature & Languages',
      'General Reference',
    ];

    final languages = ['English', 'French', 'Arabic', 'Spanish', 'German', 'Other'];
    final formats = [
      'Paperback',
      'Hardcover',
      'Journal / Periodical',
      'Thesis / Dissertation',
      'Reference Book',
      'Multimedia / DVD',
    ];

    StreamSubscription<List<RfidTag>>? inventorySub;
    StreamSubscription<String>? cardSub;
    StreamSubscription<RfidConnectionState>? connSub;
    final wedgeBuffer = StringBuffer();
    DateTime lastKeystrokeTime = DateTime.now();
    final keyboardFocusNode = FocusNode();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final rfidManager = dialogCtx.read<RfidManager>();
        rfidManager.setMode(RfidReaderMode.multiTagInventory);

        // Auto-connect if not connected
        if (!rfidManager.isConnected) {
          rfidManager.connect();
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Attach subscriptions if not attached
            connSub ??= rfidManager.onConnectionStateChanged.listen((_) {
              setDialogState(() {});
            });

            inventorySub ??= rfidManager.onTagsInventory.listen((tags) {
              for (final t in tags) {
                final clean = t.cleanEpc;
                if (clean.isNotEmpty && !scannedEpcs.contains(clean)) {
                  setDialogState(() {
                    scannedEpcs.add(clean);
                  });
                }
              }
            });

            cardSub ??= rfidManager.onCardDetected.listen((epc) {
              final clean = epc.trim().toUpperCase();
              if (clean.isNotEmpty && !scannedEpcs.contains(clean)) {
                setDialogState(() {
                  scannedEpcs.add(clean);
                });
              }
            });

            return KeyboardListener(
              focusNode: keyboardFocusNode,
              autofocus: true,
              onKeyEvent: (event) {
                if (event is KeyDownEvent) {
                  final now = DateTime.now();
                  if (now.difference(lastKeystrokeTime).inMilliseconds > 600) {
                    wedgeBuffer.clear();
                  }
                  lastKeystrokeTime = now;

                  if (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    final raw = wedgeBuffer.toString().trim();
                    wedgeBuffer.clear();
                    if (raw.length >= 4) {
                      final clean = raw.toUpperCase();
                      if (!scannedEpcs.contains(clean)) {
                        setDialogState(() {
                          scannedEpcs.add(clean);
                        });
                        rfidManager.beepScan();
                      }
                    }
                  } else if (event.character != null && event.character!.isNotEmpty) {
                    wedgeBuffer.write(event.character);
                  }
                }
              },
              child: Dialog(
              backgroundColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              child: Container(
                width: 680,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wizard Header & Progress Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            currentStep == 1
                                ? Icons.nfc_rounded
                                : Icons.library_books_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStep == 1
                                  ? 'STEP 1: SCAN PHYSICAL RFID LABEL'
                                  : 'STEP 2: CATALOG BOOK METADATA',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              currentStep == 1
                                  ? 'Scan or encode label on RFID reader first'
                                  : 'Complete rich university/public library fields',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                          onPressed: () {
                            inventorySub?.cancel();
                            cardSub?.cancel();
                            connSub?.cancel();
                            keyboardFocusNode.dispose();
                            rfidManager.setMode(RfidReaderMode.idle);
                            Navigator.of(dialogCtx).pop();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Wizard Progress Indicator
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: currentStep == 2
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Wizard Step 1: RFID Label Scanning
                    if (currentStep == 1) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 12),
                              const RfidRadarAnimation(size: 160),
                              const SizedBox(height: 12),

                              // Hardware Reader Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: rfidManager.isConnected
                                      ? AppColors.success.withValues(alpha: 0.12)
                                      : AppColors.danger.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: rfidManager.isConnected
                                        ? AppColors.success.withValues(alpha: 0.5)
                                        : AppColors.danger.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      rfidManager.isConnected
                                          ? Icons.sensors_rounded
                                          : Icons.sensors_off_rounded,
                                      size: 16,
                                      color: rfidManager.isConnected
                                          ? AppColors.success
                                          : AppColors.danger,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      rfidManager.isConnected
                                          ? 'RFID Reader Online (${rfidManager.isSimulated ? "Simulator" : "Port ${rfidManager.currentPort ?? 'USB'}"})'
                                          : 'RFID Reader Disconnected',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: rfidManager.isConnected
                                            ? AppColors.success
                                            : AppColors.danger,
                                      ),
                                    ),
                                    if (!rfidManager.isConnected) ...[
                                      const SizedBox(width: 10),
                                      InkWell(
                                        onTap: () async {
                                          await rfidManager.connect();
                                          setDialogState(() {});
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
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),
                              const Text(
                                'Place the physical RFID label/sticker on the reader...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Native SDK inventory & USB keyboard wedge auto-capture are active.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Scanned EPCs list card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: scannedEpcs.isNotEmpty
                                        ? AppColors.success
                                        : AppColors.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          scannedEpcs.isNotEmpty
                                              ? Icons.check_circle_rounded
                                              : Icons.sensors_rounded,
                                          size: 18,
                                          color: scannedEpcs.isNotEmpty
                                              ? AppColors.success
                                              : AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Scanned Physical RFID Labels (${scannedEpcs.length})',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: scannedEpcs.isNotEmpty
                                                ? AppColors.success
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (scannedEpcs.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'Waiting for RFID label detection...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      )
                                    else
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: scannedEpcs.map((epc) {
                                          return Chip(
                                            backgroundColor: AppColors.success
                                                .withValues(alpha: 0.15),
                                            side: const BorderSide(
                                                color: AppColors.success),
                                            avatar: const Icon(
                                              Icons.nfc_rounded,
                                              size: 16,
                                              color: AppColors.success,
                                            ),
                                            label: Text(
                                              epc,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            onDeleted: () {
                                              setDialogState(() {
                                                scannedEpcs.remove(epc);
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Manual Input / Simulator Injection Action
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: manualEpcController,
                                      decoration: const InputDecoration(
                                        hintText: 'Manual EPC string or barcode...',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      final input = manualEpcController.text.trim();
                                      final epcToAdd = input.isNotEmpty
                                          ? input.toUpperCase()
                                          : 'E2806894${DateTime.now().millisecondsSinceEpoch.toString().padLeft(16, '0')}';
                                      if (!scannedEpcs.contains(epcToAdd)) {
                                        setDialogState(() {
                                          scannedEpcs.add(epcToAdd);
                                          manualEpcController.clear();
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.add_task_rounded, size: 16),
                                    label: const Text('ADD LABEL'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Wizard Step 2: Rich Library Catalog Metadata Entry
                    if (currentStep == 2) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Scanned RFID Banner
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.success),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppColors.success, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Linked RFID Label(s): ${scannedEpcs.join(', ')}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Section 1: Primary Catalog Metadata
                              const Text(
                                '1. BASIC BIBLIOGRAPHIC INFORMATION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Book Title *',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: subtitleController,
                                decoration: const InputDecoration(
                                  labelText: 'Subtitle / Volume (Optional)',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: authorController,
                                      decoration: const InputDecoration(
                                        labelText: 'Primary Author / Creators *',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: isbnController,
                                      decoration: const InputDecoration(
                                        labelText: 'ISBN-13 / ISSN *',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // Section 2: Library Classification & Shelf Location
                              const Text(
                                '2. LIBRARY CLASSIFICATION & STACKS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: callNumberController,
                                      decoration: const InputDecoration(
                                        labelText: 'Call Number / Dewey Decimal',
                                        hintText: 'e.g. 005.133 S682',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedCategory,
                                      decoration: const InputDecoration(
                                        labelText: 'Category / Subject',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                      items: categories.map((cat) {
                                        return DropdownMenuItem(
                                          value: cat,
                                          child: Text(cat,
                                              style: const TextStyle(fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedCategory = val);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: shelfController,
                                      decoration: const InputDecoration(
                                        labelText: 'Shelf / Stacks',
                                        hintText: 'e.g. CS-101-A',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // Section 3: Publishing Details
                              const Text(
                                '3. PUBLICATION DETAILS & FORMAT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: publisherController,
                                      decoration: const InputDecoration(
                                        labelText: 'Publisher',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: publishYearController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Year',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: editionController,
                                      decoration: const InputDecoration(
                                        labelText: 'Edition',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedLanguage,
                                      decoration: const InputDecoration(
                                        labelText: 'Language',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                      items: languages.map((lang) {
                                        return DropdownMenuItem(
                                          value: lang,
                                          child: Text(lang,
                                              style: const TextStyle(fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedLanguage = val);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedFormat,
                                      decoration: const InputDecoration(
                                        labelText: 'Binding / Format',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                      items: formats.map((fmt) {
                                        return DropdownMenuItem(
                                          value: fmt,
                                          child: Text(fmt,
                                              style: const TextStyle(fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedFormat = val);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: pageCountController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Pages',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Description & Summary
                              TextField(
                                controller: descriptionController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Summary / Abstract / Description',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Wizard Footer Actions
                    Row(
                      children: [
                        if (currentStep == 2)
                          OutlinedButton.icon(
                            onPressed: () => setDialogState(() => currentStep = 1),
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text('BACK TO RFID SCAN'),
                          )
                        else
                          TextButton(
                            onPressed: () {
                              inventorySub?.cancel();
                              cardSub?.cancel();
                              rfidManager.setMode(RfidReaderMode.idle);
                              Navigator.of(dialogCtx).pop();
                            },
                            child: const Text('CANCEL'),
                          ),
                        const Spacer(),
                        if (currentStep == 1)
                          FilledButton.icon(
                            onPressed: scannedEpcs.isNotEmpty
                                ? () => setDialogState(() => currentStep = 2)
                                : null,
                            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                            label: Text('NEXT: ENTER METADATA (${scannedEpcs.length} TAGS)'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () async {
                              if (titleController.text.trim().isEmpty ||
                                  authorController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Please enter Title and Author.')),
                                );
                                return;
                              }

                              const uuid = Uuid();
                              final db = context.read<AppDatabase>();
                              final bookId =
                                  'book-${DateTime.now().millisecondsSinceEpoch}';

                              final newBook = Book(
                                id: bookId,
                                title: titleController.text.trim(),
                                subtitle: subtitleController.text.trim(),
                                author: authorController.text.trim(),
                                isbn: isbnController.text.trim().isNotEmpty
                                    ? isbnController.text.trim()
                                    : '978-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
                                publisher: publisherController.text.trim(),
                                publishYear: int.tryParse(
                                        publishYearController.text.trim()) ??
                                    2024,
                                category: selectedCategory,
                                shelfLocation: shelfController.text.trim(),
                                callNumber: callNumberController.text.trim(),
                                edition: editionController.text.trim(),
                                language: selectedLanguage,
                                pageCount: int.tryParse(
                                        pageCountController.text.trim()) ??
                                    0,
                                format: selectedFormat,
                                description: descriptionController.text.trim(),
                              );

                              await db.insertBook(newBook);

                              // Save scanned RFID physical copies
                              for (int i = 0; i < scannedEpcs.length; i++) {
                                final epc = scannedEpcs[i];
                                final titlePrefix = newBook.title
                                    .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
                                    .toUpperCase();
                                final prefix = titlePrefix.length >= 2
                                    ? titlePrefix.substring(0, 2)
                                    : 'BK';
                                final copyBarcode =
                                    'BC-$prefix-${i + 1}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

                                final copy = BookCopy(
                                  id: uuid.v4(),
                                  bookId: bookId,
                                  copyBarcode: copyBarcode,
                                  rfidEpc: epc,
                                  status: 'available',
                                );
                                await db.insertBookCopy(copy);
                              }

                              inventorySub?.cancel();
                              cardSub?.cancel();
                              connSub?.cancel();
                              keyboardFocusNode.dispose();
                              rfidManager.setMode(RfidReaderMode.idle);

                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                                _loadCatalog();
                              }
                            },
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('SAVE & LINK RFID COPIES'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredBooks;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Action Bar
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.t('catalog_badge'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.t('catalog_title'),
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
                onPressed: _showAddBookWizard,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(locale.t('new_book')),
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
              hintText: locale.t('search_book_placeholder'),
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

          // Books List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No matching books found.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final book = filtered[index];
                      final copies = _copiesMap[book.id] ?? [];

                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.menu_book_rounded,
                                  color: AppColors.primary, size: 22),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  book.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (book.subtitle.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    ': ${book.subtitle}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Author: ${book.author}  •  ISBN: ${book.isbn}  •  Shelf: ${book.shelfLocation}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (book.callNumber.isNotEmpty)
                                      _buildBadge('Call No: ${book.callNumber}', AppColors.primary),
                                    _buildBadge(book.category, AppColors.secondary),
                                    _buildBadge('${book.format} • ${book.language}', AppColors.textMuted),
                                    if (book.edition.isNotEmpty)
                                      _buildBadge(book.edition, AppColors.warning),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${copies.length} ${locale.t('copies_count')}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: locale.t('delete_book'),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.danger,
                                    size: 20,
                                  ),
                                  onPressed: () => _confirmDeleteBook(book, locale),
                                ),
                              ],
                            ),
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                color: AppColors.surface.withValues(alpha: 0.5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (book.description.isNotEmpty) ...[
                                      Text(
                                        'SUMMARY: ${book.description}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    const Text(
                                      'PHYSICAL COPIES & LINKED RFID LABELS:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...copies.map((copy) {
                                      final isAvail = copy.isAvailable;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isAvail ? Icons.check_circle_outline_rounded : Icons.lock_outline_rounded,
                                              size: 16,
                                              color: isAvail ? AppColors.success : AppColors.danger,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Barcode: ${copy.copyBarcode}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              'EPC: ${copy.rfidEpc}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isAvail
                                                    ? AppColors.success.withValues(alpha: 0.12)
                                                    : AppColors.danger.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isAvail ? AppColors.success : AppColors.danger,
                                                ),
                                              ),
                                              child: Text(
                                                copy.status.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isAvail ? AppColors.success : AppColors.danger,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
