import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_copy.dart';

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
          b.author.toLowerCase().contains(q) ||
          b.isbn.toLowerCase().contains(q) ||
          b.category.toLowerCase().contains(q);
    }).toList();
  }

  void _showAddBookDialog() {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final isbnController = TextEditingController();
    final categoryController = TextEditingController(text: 'Computer Science');
    final shelfController = TextEditingController(text: 'CS-101');
    int initialCopies = 1;

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
                  Icon(Icons.add_box_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Catalog New Book & Create Copies'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Book Title *',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: authorController,
                        decoration: const InputDecoration(
                          labelText: 'Author *',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: isbnController,
                        decoration: const InputDecoration(
                          labelText: 'ISBN *',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: categoryController,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: shelfController,
                              decoration: const InputDecoration(
                                labelText: 'Shelf Location',
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
                          const Text(
                            'Initial Physical Copies to Create:',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: initialCopies > 1
                                ? () => setDialogState(() => initialCopies--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                          ),
                          Text(
                            initialCopies.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          IconButton(
                            onPressed: initialCopies < 10
                                ? () => setDialogState(() => initialCopies++)
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
                    if (titleController.text.trim().isEmpty ||
                        authorController.text.trim().isEmpty) {
                      return;
                    }

                    const uuid = Uuid();
                    final db = context.read<AppDatabase>();
                    final bookId = 'book-${DateTime.now().millisecondsSinceEpoch}';

                    final newBook = Book(
                      id: bookId,
                      title: titleController.text.trim(),
                      author: authorController.text.trim(),
                      isbn: isbnController.text.trim().isNotEmpty
                          ? isbnController.text.trim()
                          : '978-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
                      category: categoryController.text.trim(),
                      shelfLocation: shelfController.text.trim(),
                    );

                    await db.insertBook(newBook);

                    // Generate physical copies with barcodes and EPCs
                    for (int i = 1; i <= initialCopies; i++) {
                      final copyBarcode = 'BC-${newBook.title.substring(0, 2).toUpperCase()}-$i-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                      final epc =
                          'E2806894000000000000${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}$i';

                      final copy = BookCopy(
                        id: uuid.v4(),
                        bookId: bookId,
                        copyBarcode: copyBarcode,
                        rfidEpc: epc,
                        status: 'available',
                      );
                      await db.insertBookCopy(copy);
                    }

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      _loadCatalog();
                    }
                  },
                  child: const Text('CREATE & TAG'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CATALOG & RFID INVENTORY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Books & Physical Copies',
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
                onPressed: _showAddBookDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('NEW BOOK'),
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
              hintText: 'Search by title, author, ISBN, or category...',
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
                            title: Text(
                              book.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${book.author}  •  ISBN: ${book.isbn}  •  Shelf: ${book.shelfLocation}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${copies.length} Copies',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                color: AppColors.surface.withValues(alpha: 0.5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'PHYSICAL COPIES & RFID TAGS:',
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
}
