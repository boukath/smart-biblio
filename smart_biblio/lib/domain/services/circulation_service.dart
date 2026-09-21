import '../../data/database/app_database.dart';
import '../../data/models/book.dart';
import '../../data/models/loan.dart';
import '../../data/models/member.dart';
import '../rules/library_rules_engine.dart';

class CirculationService {
  final AppDatabase _db;

  CirculationService({AppDatabase? db}) : _db = db ?? AppDatabase();

  /// Validates a list of scanned tag EPCs against the library catalog for [member].
  Future<List<BorrowValidationItem>> validateBorrowTags({
    required Member member,
    required List<String> epcs,
  }) async {
    final settings = await _db.getSettings();
    final activeLoans = await _db.getActiveLoansForMember(member.id);
    final hasOverdue = activeLoans.any((l) => l.isOverdue);

    final results = <BorrowValidationItem>[];
    int validCount = 0;

    // Remove duplicates from the input list of EPCs
    final uniqueEpcs = epcs.map((e) => e.trim().toUpperCase()).toSet().toList();

    for (final epc in uniqueEpcs) {
      final copy = await _db.findCopyByEpc(epc);
      Book? book;
      if (copy != null) {
        book = await _db.getBookById(copy.bookId);
      }

      final item = LibraryRulesEngine.evaluateBorrowTag(
        epc: epc,
        member: member,
        copy: copy,
        book: book,
        currentActiveLoanCount: activeLoans.length,
        pendingBorrowCountInCurrentSession: validCount,
        hasOverdueLoans: hasOverdue,
        settings: settings,
      );

      if (item.isValid) {
        validCount++;
      }
      results.add(item);
    }

    return results;
  }

  /// Validates a list of scanned tag EPCs for return by [member].
  Future<List<ReturnValidationItem>> validateReturnTags({
    required Member member,
    required List<String> epcs,
    DateTime? checkTime,
  }) async {
    final settings = await _db.getSettings();
    final results = <ReturnValidationItem>[];

    final uniqueEpcs = epcs.map((e) => e.trim().toUpperCase()).toSet().toList();

    for (final epc in uniqueEpcs) {
      final copy = await _db.findCopyByEpc(epc);
      Book? book;
      Loan? activeLoan;
      String? actualBorrowerName;

      if (copy != null) {
        book = await _db.getBookById(copy.bookId);
        activeLoan = await _db.getActiveLoanForCopy(copy.id);
        if (activeLoan != null && activeLoan.memberId != member.id) {
          final borrower = await _db.getMemberById(activeLoan.memberId);
          actualBorrowerName = borrower?.fullName;
        }
      }

      final item = LibraryRulesEngine.evaluateReturnTag(
        epc: epc,
        member: member,
        copy: copy,
        book: book,
        activeLoan: activeLoan,
        actualBorrowerName: actualBorrowerName,
        settings: settings,
        checkTime: checkTime,
      );

      results.add(item);
    }

    return results;
  }

  /// Executes borrow transaction for all valid items in [items].
  Future<List<Loan>> commitBorrow({
    required Member member,
    required List<BorrowValidationItem> items,
    String source = 'self_service',
  }) async {
    final settings = await _db.getSettings();
    final validItems = items.where((i) => i.isValid && i.copy != null).toList();
    final createdLoans = <Loan>[];

    for (final item in validItems) {
      final loan = await _db.borrowBookCopy(
        member: member,
        copy: item.copy!,
        durationDays: settings.loanDurationDays,
        source: source,
      );
      createdLoans.add(loan);
    }

    return createdLoans;
  }

  /// Executes return transaction for all valid return items in [items].
  Future<List<Loan>> commitReturn({
    required Member member,
    required List<ReturnValidationItem> items,
    String actor = 'student',
  }) async {
    final settings = await _db.getSettings();
    final validItems = items.where((i) => i.isValid && i.activeLoan != null).toList();
    final completedLoans = <Loan>[];

    for (final item in validItems) {
      final loan = await _db.returnBookCopy(
        activeLoan: item.activeLoan!,
        copyId: item.copy!.id,
        finePerDay: settings.finePerDay,
        returnActor: actor,
      );
      completedLoans.add(loan);
    }

    return completedLoans;
  }
}
