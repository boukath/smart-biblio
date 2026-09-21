import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_copy.dart';
import '../../../domain/rfid/rfid_manager.dart';
import '../../../domain/rfid/rfid_models.dart';

class AdminRfidCenterView extends StatefulWidget {
  const AdminRfidCenterView({super.key});

  @override
  State<AdminRfidCenterView> createState() => _AdminRfidCenterViewState();
}

class _AdminRfidCenterViewState extends State<AdminRfidCenterView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Diagnostics state
  int _selectedPort = 100;
  int _selectedBaud = 115200;
  int _selectedMemoryBank = 1; // EPC
  int _readMemoryAddress = 0;
  int _readMemoryLength = 8;
  String? _readMemoryResult;
  bool _isReadingMemory = false;

  // Tag Writer state
  List<Book> _catalogBooks = [];
  List<BookCopy> _availableCopies = [];
  BookCopy? _selectedCopy;
  final _epcWriterController = TextEditingController();
  bool _isWritingTag = false;
  String? _writeStatusMessage;
  bool _writeSuccess = false;
  bool _batchMode = false;

  // Shelf Audit state
  List<String> _shelves = [];
  String? _selectedShelf;
  List<Map<String, dynamic>> _expectedShelfCopies = [];
  final Set<String> _scannedAuditEpcs = {};
  bool _isAuditing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final db = context.read<AppDatabase>();
    final books = await db.getAllBooks();
    final shelves = await db.getAllShelfLocations();

    final allCopies = <BookCopy>[];
    for (final b in books) {
      allCopies.addAll(await db.getCopiesForBook(b.id));
    }

    if (mounted) {
      setState(() {
        _catalogBooks = books;
        _availableCopies = allCopies;
        _shelves = shelves;
        if (shelves.isNotEmpty) {
          _selectedShelf = shelves.first;
          _loadShelfCopies(_selectedShelf!);
        }
        if (allCopies.isNotEmpty) {
          _selectedCopy = allCopies.first;
          _epcWriterController.text = _selectedCopy!.rfidEpc;
        }
      });
    }
  }

  Future<void> _loadShelfCopies(String shelf) async {
    final db = context.read<AppDatabase>();
    final copies = await db.getCopiesByShelf(shelf);
    setState(() {
      _expectedShelfCopies = copies;
      _scannedAuditEpcs.clear();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _epcWriterController.dispose();
    super.dispose();
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
                'FONGWAH U1-CU-71 HARDWARE CENTER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'RFID Diagnostics, Tag Encoder & Shelf Audit',
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
                    Text('Diagnostics & Port Settings'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Tag Writer & Encoder'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    Icon(Icons.shelves, size: 18),
                    SizedBox(width: 8),
                    Text('Shelf Inventory Audit'),
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
                _buildDiagnosticsTab(),
                _buildTagWriterTab(),
                _buildShelfAuditTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: DIAGNOSTICS & HARDWARE TEST
  // ==========================================
  Widget _buildDiagnosticsTab() {
    final rfid = context.watch<RfidManager>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Config Card
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
                  'Hardware Connection & Port Configuration',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Port Selector
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _selectedPort,
                        decoration: const InputDecoration(
                          labelText: 'Reader Port',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        items: const [
                          DropdownMenuItem(value: 100, child: Text('USB Port (100 - Default)')),
                          DropdownMenuItem(value: 0, child: Text('Serial COM1 (Port 0)')),
                          DropdownMenuItem(value: 1, child: Text('Serial COM2 (Port 1)')),
                          DropdownMenuItem(value: 2, child: Text('Serial COM3 (Port 2)')),
                          DropdownMenuItem(value: 3, child: Text('Serial COM4 (Port 3)')),
                        ],
                        onChanged: (val) => setState(() => _selectedPort = val ?? 100),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Baud Rate Selector
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _selectedBaud,
                        decoration: const InputDecoration(
                          labelText: 'Baud Rate',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        items: const [
                          DropdownMenuItem(value: 115200, child: Text('115200 bps (Recommended)')),
                          DropdownMenuItem(value: 57600, child: Text('57600 bps')),
                          DropdownMenuItem(value: 38400, child: Text('38400 bps')),
                          DropdownMenuItem(value: 9600, child: Text('9600 bps')),
                        ],
                        onChanged: (val) => setState(() => _selectedBaud = val ?? 115200),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Connect/Disconnect Button
                    FilledButton.icon(
                      onPressed: () async {
                        if (rfid.isConnected) {
                          await rfid.disconnect();
                        } else {
                          await rfid.connect(port: _selectedPort, baud: _selectedBaud);
                        }
                      },
                      icon: Icon(rfid.isConnected ? Icons.link_off_rounded : Icons.link_rounded),
                      label: Text(rfid.isConnected ? 'DISCONNECT' : 'CONNECT READER'),
                      style: FilledButton.styleFrom(
                        backgroundColor: rfid.isConnected ? AppColors.danger : AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Hardware Feedback Actions (Buzzer & LEDs)
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
                  'Hardware Action Tests (Buzzer & LEDs)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Directly trigger Fongwah U1-CU-71 audio and visual signals (uhf_action API)',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => rfid.beepSuccess(),
                      icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
                      label: const Text('BEEP BUZZER (0x01)'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => rfid.device.triggerAction(beep: false, greenLed: true, durationMs: 500),
                      icon: const Icon(Icons.lightbulb_rounded, color: AppColors.success),
                      label: const Text('GREEN LED (0x04)'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => rfid.device.triggerAction(beep: false, redLed: true, durationMs: 500),
                      icon: const Icon(Icons.lightbulb_rounded, color: AppColors.danger),
                      label: const Text('RED LED (0x02)'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => rfid.device.triggerAction(beep: false, yellowLed: true, durationMs: 500),
                      icon: const Icon(Icons.lightbulb_rounded, color: AppColors.warning),
                      label: const Text('YELLOW LED (0x08)'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Memory Bank Inspector
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
                  'Raw Memory Bank Inspector',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _selectedMemoryBank,
                        decoration: const InputDecoration(
                          labelText: 'Memory Bank',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Bank 1: EPC Memory')),
                          DropdownMenuItem(value: 2, child: Text('Bank 2: TID Memory')),
                          DropdownMenuItem(value: 3, child: Text('Bank 3: USER Memory')),
                          DropdownMenuItem(value: 0, child: Text('Bank 0: Reserved (Access/Kill)')),
                        ],
                        onChanged: (val) => setState(() => _selectedMemoryBank = val ?? 1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _readMemoryAddress.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Start Word Address',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _readMemoryAddress = int.tryParse(val) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _readMemoryLength.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Word Length',
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _readMemoryLength = int.tryParse(val) ?? 8,
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: _isReadingMemory
                          ? null
                          : () async {
                              setState(() => _isReadingMemory = true);
                              final res = await rfid.device.readMemory(
                                bank: _selectedMemoryBank,
                                address: _readMemoryAddress,
                                length: _readMemoryLength,
                              );
                              setState(() {
                                _readMemoryResult = res ?? 'Read failed or no tag in field';
                                _isReadingMemory = false;
                              });
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      ),
                      child: _isReadingMemory
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('READ MEMORY'),
                    ),
                  ],
                ),
                if (_readMemoryResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Result: $_readMemoryResult',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: TAG WRITER & ENCODER
  // ==========================================
  Widget _buildTagWriterTab() {
    final rfid = context.watch<RfidManager>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Encode & Write Physical RFID Tags',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Place UHF RFID label sticker near reader to burn EPC and link to library copy',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Batch Mode Toggle
                    Row(
                      children: [
                        const Text('Batch Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Switch(
                          value: _batchMode,
                          onChanged: (val) => setState(() => _batchMode = val),
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Select Target Copy
                DropdownButtonFormField<BookCopy>(
                  isExpanded: true,
                  key: ValueKey(_selectedCopy?.id),
                  initialValue: _selectedCopy,
                  decoration: const InputDecoration(
                    labelText: 'Target Book Copy to Tag *',
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  items: _availableCopies.map((c) {
                    final book = _catalogBooks.firstWhere(
                      (b) => b.id == c.bookId,
                      orElse: () => Book(id: '', title: 'Unknown', author: '', isbn: ''),
                    );
                    return DropdownMenuItem(
                      value: c,
                      child: Text(
                        '${book.title} (Barcode: ${c.copyBarcode} • Current EPC: ${c.rfidEpc})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCopy = val;
                      if (val != null) {
                        _epcWriterController.text = val.rfidEpc;
                      }
                    });
                  },
                ),

                const SizedBox(height: 16),

                // New EPC field
                TextField(
                  controller: _epcWriterController,
                  decoration: InputDecoration(
                    labelText: 'New EPC to Encode (24 Hex Characters) *',
                    filled: true,
                    fillColor: AppColors.surface,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.auto_fix_high_rounded, color: AppColors.primary),
                      tooltip: 'Generate Standard 24-Hex EPC',
                      onPressed: () {
                        final hexStamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0').toUpperCase();
                        _epcWriterController.text = 'E28068940000$hexStamp';
                      },
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 24),

                // Write & Verify Button
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isWritingTag || _selectedCopy == null
                          ? null
                          : () async {
                              final newEpc = _epcWriterController.text.trim();
                              if (newEpc.isEmpty) return;

                              final db = context.read<AppDatabase>();
                              final targetCopyId = _selectedCopy!.id;

                              setState(() {
                                _isWritingTag = true;
                                _writeStatusMessage = 'Writing EPC to tag...';
                              });

                              // 1. Write EPC via RfidManager
                              final writeOk = await rfid.writeEpc(newEpc);
                              if (!mounted) return;

                              if (writeOk) {
                                // 2. Update Database assignment
                                await db.updateCopyEpc(targetCopyId, newEpc);

                                setState(() {
                                  _writeSuccess = true;
                                  _writeStatusMessage =
                                      'SUCCESS: Tag encoded & verified with EPC $newEpc!';
                                  _isWritingTag = false;
                                });

                                // Batch mode: advance to next copy
                                if (_batchMode) {
                                  final currentIndex = _availableCopies.indexOf(_selectedCopy!);
                                  if (currentIndex >= 0 &&
                                      currentIndex + 1 < _availableCopies.length) {
                                    final next = _availableCopies[currentIndex + 1];
                                    setState(() {
                                      _selectedCopy = next;
                                      _epcWriterController.text = next.rfidEpc;
                                    });
                                  }
                                }
                              } else {
                                setState(() {
                                  _writeSuccess = false;
                                  _writeStatusMessage =
                                      'ERROR: Tag write failed. Ensure tag is in reader field.';
                                  _isWritingTag = false;
                                });
                              }
                            },
                      icon: _isWritingTag
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.qr_code_2_rounded, size: 20),
                      label: const Text('WRITE & VERIFY TAG', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (_writeStatusMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _writeSuccess
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _writeSuccess ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        child: Text(
                          _writeStatusMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _writeSuccess ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: SHELF INVENTORY AUDIT
  // ==========================================
  Widget _buildShelfAuditTab() {
    final rfid = context.watch<RfidManager>();

    // Calculate audit metrics
    final totalExpected = _expectedShelfCopies.length;
    int presentCount = 0;
    int missingCount = 0;
    int misplacedCount = 0;

    for (final expected in _expectedShelfCopies) {
      final epc = (expected['rfid_epc'] as String).toUpperCase();
      if (_scannedAuditEpcs.contains(epc)) {
        presentCount++;
      } else {
        missingCount++;
      }
    }

    // Check misplaced: scanned tags that do NOT belong to this shelf
    final expectedEpcs = _expectedShelfCopies
        .map((e) => (e['rfid_epc'] as String).toUpperCase())
        .toSet();
    for (final scanned in _scannedAuditEpcs) {
      if (!expectedEpcs.contains(scanned)) {
        misplacedCount++;
      }
    }

    final percent = totalExpected > 0 ? (presentCount / totalExpected * 100).toInt() : 100;

    return Column(
      children: [
        // Controls Header
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
              Row(
                children: [
                  // Shelf Location Dropdown
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedShelf,
                      decoration: const InputDecoration(
                        labelText: 'Target Shelf',
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                      items: _shelves.map((s) {
                        return DropdownMenuItem(value: s, child: Text('Shelf $s'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedShelf = val);
                          _loadShelfCopies(val);
                        }
                      },
                    ),
                  ),
                  const Spacer(),

                  // Start / Stop Audit Button
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _isAuditing = !_isAuditing);
                      if (_isAuditing) {
                        rfid.setMode(RfidReaderMode.multiTagInventory);
                        // Listen for incoming tags
                        rfid.onTagsInventory.listen((tags) {
                          if (_isAuditing && mounted) {
                            setState(() {
                              for (final t in tags) {
                                _scannedAuditEpcs.add(t.cleanEpc);
                              }
                            });
                          }
                        });
                      } else {
                        rfid.setMode(RfidReaderMode.idle);
                      }
                    },
                    icon: Icon(_isAuditing ? Icons.stop_rounded : Icons.radar_rounded),
                    label: Text(_isAuditing ? 'STOP AUDIT' : 'START SHELF SCAN'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isAuditing ? AppColors.danger : AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _scannedAuditEpcs.clear()),
                    child: const Text('CLEAR AUDIT'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metric badges
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildAuditBadge('Expected', totalExpected.toString(), AppColors.textPrimary),
                  _buildAuditBadge('Present', '$presentCount ($percent%)', AppColors.success),
                  _buildAuditBadge('Missing', missingCount.toString(), AppColors.danger),
                  _buildAuditBadge('Misplaced', misplacedCount.toString(), AppColors.warning),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Shelf Copies Comparison List
        Expanded(
          child: _expectedShelfCopies.isEmpty
              ? const Center(
                  child: Text('No books assigned to this shelf location.',
                      style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.separated(
                  itemCount: _expectedShelfCopies.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _expectedShelfCopies[index];
                    final epc = (item['rfid_epc'] as String).toUpperCase();
                    final isPresent = _scannedAuditEpcs.contains(epc);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPresent
                              ? AppColors.success.withValues(alpha: 0.5)
                              : AppColors.danger.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: isPresent ? AppColors.success : AppColors.danger,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Author: ${item['author']}  •  Barcode: ${item['copy_barcode']}  •  EPC: $epc',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPresent
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPresent ? 'ON SHELF' : 'NOT DETECTED (MISSING)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPresent ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAuditBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
