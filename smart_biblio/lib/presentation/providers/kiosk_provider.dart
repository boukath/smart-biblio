import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/database/app_database.dart';
import '../../data/models/loan.dart';
import '../../data/models/member.dart';
import '../../domain/rfid/rfid_manager.dart';
import '../../domain/rfid/rfid_models.dart';
import '../../domain/rules/library_rules_engine.dart';
import '../../domain/services/circulation_service.dart';

enum KioskStep {
  idle,
  studentHome,
  borrowScanning,
  returnScanning,
  successReceipt,
}

class KioskProvider extends ChangeNotifier {
  final AppDatabase _db;
  final CirculationService _circulation;
  final RfidManager _rfid;

  KioskProvider({
    AppDatabase? db,
    CirculationService? circulation,
    RfidManager? rfid,
  })  : _db = db ?? AppDatabase(),
        _circulation = circulation ?? CirculationService(),
        _rfid = rfid ?? RfidManager() {
    _init();
  }

  KioskStep _step = KioskStep.idle;
  Member? _currentStudent;
  List<Loan> _activeStudentLoans = [];
  List<BorrowValidationItem> _borrowItems = [];
  List<ReturnValidationItem> _returnItems = [];
  List<Loan> _lastProcessedLoans = [];

  bool _isProcessing = false;
  int _timeoutSecondsRemaining = 45;
  Timer? _countdownTimer;

  // Stream Subscriptions
  StreamSubscription<String>? _cardSub;
  StreamSubscription<List<RfidTag>>? _inventorySub;

  // Getters
  KioskStep get step => _step;
  Member? get currentStudent => _currentStudent;
  List<Loan> get activeStudentLoans => _activeStudentLoans;
  List<BorrowValidationItem> get borrowItems => _borrowItems;
  List<ReturnValidationItem> get returnItems => _returnItems;
  List<Loan> get lastProcessedLoans => _lastProcessedLoans;
  bool get isProcessing => _isProcessing;
  int get timeoutSecondsRemaining => _timeoutSecondsRemaining;
  RfidManager get rfid => _rfid;

  int get validBorrowCount => _borrowItems.where((b) => b.isValid).length;
  int get validReturnCount => _returnItems.where((r) => r.isValid).length;
  double get pendingFinesOnReturn => _returnItems
      .where((r) => r.isValid)
      .fold(0.0, (sum, item) => sum + item.fineAmount);

  void _init() {
    // Start in card scan mode
    _rfid.setMode(RfidReaderMode.studentCardScan);

    // Listen for card detections
    _cardSub = _rfid.onCardDetected.listen((epc) {
      if (_step == KioskStep.idle) {
        handleCardTapped(epc);
      }
    });

    // Listen for multi-tag inventory detections
    _inventorySub = _rfid.onTagsInventory.listen((tags) {
      final epcs = tags.map((t) => t.cleanEpc).toList();
      if (_step == KioskStep.borrowScanning && _currentStudent != null) {
        _handleBorrowTagsScanned(epcs);
      } else if (_step == KioskStep.returnScanning && _currentStudent != null) {
        _handleReturnTagsScanned(epcs);
      }
    });
  }

  /// Called when a card is tapped on the reader
  Future<void> handleCardTapped(String cardEpc) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final member = await _db.findMemberByCardEpc(cardEpc);
      if (member != null) {
        _currentStudent = member;
        _activeStudentLoans = await _db.getActiveLoansForMember(member.id);
        _step = KioskStep.studentHome;
        _startTimeoutTimer();
        _rfid.setMode(RfidReaderMode.idle);
      } else {
        await _rfid.beepError();
      }
    } catch (e) {
      await _rfid.beepError();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void startBorrowWorkflow() {
    if (_currentStudent == null) return;
    _borrowItems.clear();
    _step = KioskStep.borrowScanning;
    _rfid.setMode(RfidReaderMode.multiTagInventory);
    resetTimer();
    notifyListeners();
  }

  void startReturnWorkflow() {
    if (_currentStudent == null) return;
    _returnItems.clear();
    _step = KioskStep.returnScanning;
    _rfid.setMode(RfidReaderMode.multiTagInventory);
    resetTimer();
    notifyListeners();
  }

  Future<void> _handleBorrowTagsScanned(List<String> epcs) async {
    if (_currentStudent == null) return;
    resetTimer();

    // Merge existing and new EPCs
    final currentEpcs = _borrowItems.map((b) => b.epc).toList();
    final combined = {...currentEpcs, ...epcs}.toList();

    final validated = await _circulation.validateBorrowTags(
      member: _currentStudent!,
      epcs: combined,
    );

    _borrowItems = validated;
    notifyListeners();
  }

  Future<void> _handleReturnTagsScanned(List<String> epcs) async {
    if (_currentStudent == null) return;
    resetTimer();

    final currentEpcs = _returnItems.map((r) => r.epc).toList();
    final combined = {...currentEpcs, ...epcs}.toList();

    final validated = await _circulation.validateReturnTags(
      member: _currentStudent!,
      epcs: combined,
    );

    _returnItems = validated;
    notifyListeners();
  }

  Future<void> confirmBorrow() async {
    if (_currentStudent == null || validBorrowCount == 0) return;
    _isProcessing = true;
    notifyListeners();

    try {
      final created = await _circulation.commitBorrow(
        member: _currentStudent!,
        items: _borrowItems,
        source: 'self_service',
      );

      _lastProcessedLoans = created;
      _activeStudentLoans = await _db.getActiveLoansForMember(_currentStudent!.id);
      await _rfid.beepSuccess();

      _step = KioskStep.successReceipt;
      resetTimer();
    } catch (e) {
      await _rfid.beepError();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> confirmReturn() async {
    if (_currentStudent == null || validReturnCount == 0) return;
    _isProcessing = true;
    notifyListeners();

    try {
      final returned = await _circulation.commitReturn(
        member: _currentStudent!,
        items: _returnItems,
        actor: 'student',
      );

      _lastProcessedLoans = returned;
      _activeStudentLoans = await _db.getActiveLoansForMember(_currentStudent!.id);
      await _rfid.beepSuccess();

      _step = KioskStep.successReceipt;
      resetTimer();
    } catch (e) {
      await _rfid.beepError();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void backToStudentHome() {
    _rfid.setMode(RfidReaderMode.idle);
    _borrowItems.clear();
    _returnItems.clear();
    _step = KioskStep.studentHome;
    resetTimer();
    notifyListeners();
  }

  void exitSession() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _currentStudent = null;
    _activeStudentLoans.clear();
    _borrowItems.clear();
    _returnItems.clear();
    _lastProcessedLoans.clear();
    _step = KioskStep.idle;
    _rfid.setMode(RfidReaderMode.studentCardScan);
    notifyListeners();
  }

  void resetTimer() {
    _timeoutSecondsRemaining = 45;
  }

  void _startTimeoutTimer() {
    _countdownTimer?.cancel();
    _timeoutSecondsRemaining = 45;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_step == KioskStep.idle) {
        timer.cancel();
        return;
      }
      _timeoutSecondsRemaining--;
      if (_timeoutSecondsRemaining <= 0) {
        exitSession();
      } else {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cardSub?.cancel();
    _inventorySub?.cancel();
    super.dispose();
  }
}
