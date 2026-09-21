import '../../data/models/book.dart';
import '../../data/models/book_copy.dart';
import '../../data/models/loan.dart';
import '../../data/models/member.dart';
import '../../data/models/system_settings.dart';

class BorrowValidationItem {
  final String epc;
  final bool isValid;
  final String reason;
  final Book? book;
  final BookCopy? copy;

  const BorrowValidationItem({
    required this.epc,
    required this.isValid,
    required this.reason,
    this.book,
    this.copy,
  });
}

class ReturnValidationItem {
  final String epc;
  final bool isValid;
  final String reason;
  final Book? book;
  final BookCopy? copy;
  final Loan? activeLoan;
  final bool isOverdue;
  final int overdueDays;
  final double fineAmount;
  final bool belongsToCurrentStudent;
  final String? actualBorrowerName;

  const ReturnValidationItem({
    required this.epc,
    required this.isValid,
    required this.reason,
    this.book,
    this.copy,
    this.activeLoan,
    this.isOverdue = false,
    this.overdueDays = 0,
    this.fineAmount = 0.0,
    this.belongsToCurrentStudent = true,
    this.actualBorrowerName,
  });
}

class LibraryRulesEngine {
  /// Validates a single scanned RFID tag for borrowing by [member].
  static BorrowValidationItem evaluateBorrowTag({
    required String epc,
    required Member member,
    required BookCopy? copy,
    required Book? book,
    required int currentActiveLoanCount,
    required int pendingBorrowCountInCurrentSession,
    required bool hasOverdueLoans,
    required SystemSettings settings,
  }) {
    final cleanEpc = epc.trim().toUpperCase();

    // 1. Check student account status
    if (!member.isActive) {
      return BorrowValidationItem(
        epc: cleanEpc,
        isValid: false,
        reason: 'Student account is ${member.status.toUpperCase()} (Cannot borrow)',
        book: book,
        copy: copy,
      );
    }

    // 2. Check blocking overdue conditions
    if (hasOverdueLoans) {
      return BorrowValidationItem(
        epc: cleanEpc,
        isValid: false,
        reason: 'Student has overdue books. Return them before borrowing new ones.',
        book: book,
        copy: copy,
      );
    }

    // 3. Check student loan limit
    final totalProjectedLoans = currentActiveLoanCount + pendingBorrowCountInCurrentSession;
    if (totalProjectedLoans >= member.maxLoans) {
      return BorrowValidationItem(
        epc: cleanEpc,
        isValid: false,
        reason: 'Borrowing limit reached (Max: ${member.maxLoans} books)',
        book: book,
        copy: copy,
      );
    }

    // 4. Check if tag is known in database
    if (copy == null || book == null) {
      return BorrowValidationItem(
        epc: cleanEpc,
        isValid: false,
        reason: 'Unknown RFID tag (Not registered in library catalog)',
      );
    }

    // 5. Check physical copy status
    if (!copy.isAvailable) {
      if (copy.isBorrowed) {
        return BorrowValidationItem(
          epc: cleanEpc,
          isValid: false,
          reason: 'Copy already marked as BORROWED',
          book: book,
          copy: copy,
        );
      } else {
        return BorrowValidationItem(
          epc: cleanEpc,
          isValid: false,
          reason: 'Copy is currently ${copy.status.toUpperCase()}',
          book: book,
          copy: copy,
        );
      }
    }

    // 6. Check physical condition
    if (copy.condition.toLowerCase() == 'damaged') {
      return BorrowValidationItem(
        epc: cleanEpc,
        isValid: false,
        reason: 'Copy is flagged as DAMAGED (Needs maintenance)',
        book: book,
        copy: copy,
      );
    }

    // All validation checks passed!
    return BorrowValidationItem(
      epc: cleanEpc,
      isValid: true,
      reason: 'Ready to borrow',
      book: book,
      copy: copy,
    );
  }

  /// Validates a single scanned RFID tag for return by [member].
  static ReturnValidationItem evaluateReturnTag({
    required String epc,
    required Member member,
    required BookCopy? copy,
    required Book? book,
    required Loan? activeLoan,
    required String? actualBorrowerName,
    required SystemSettings settings,
    DateTime? checkTime,
  }) {
    final cleanEpc = epc.trim().toUpperCase();
    final now = checkTime ?? DateTime.now();

    // 1. Check if tag is known in library catalog
    if (copy == null || book == null) {
      return ReturnValidationItem(
        epc: cleanEpc,
        isValid: false,
        reason: 'Unknown RFID tag (Not in library catalog)',
      );
    }

    // 2. Check if this copy has an active loan
    if (activeLoan == null) {
      return ReturnValidationItem(
        epc: cleanEpc,
        isValid: false,
        reason: 'This book is not currently marked as loaned (Already in library)',
        book: book,
        copy: copy,
      );
    }

    // 3. Verify borrower matches
    final isSameStudent = activeLoan.memberId == member.id;
    if (!isSameStudent && !settings.allowReturnOtherMemberBooks) {
      return ReturnValidationItem(
        epc: cleanEpc,
        isValid: false,
        reason: 'Loaned to another student (${actualBorrowerName ?? 'Other Member'})',
        book: book,
        copy: copy,
        activeLoan: activeLoan,
        belongsToCurrentStudent: false,
        actualBorrowerName: actualBorrowerName,
      );
    }

    // 4. Overdue and fine calculation
    bool isOverdue = false;
    int overdueDays = 0;
    double fineAmount = 0.0;

    if (now.isAfter(activeLoan.dueAt)) {
      final diff = now.difference(activeLoan.dueAt);
      final rawDays = diff.inDays + (diff.inHours % 24 > 0 ? 1 : 0);
      if (rawDays > settings.gracePeriodDays) {
        isOverdue = true;
        overdueDays = rawDays;
        fineAmount = overdueDays * settings.finePerDay;
      }
    }

    return ReturnValidationItem(
      epc: cleanEpc,
      isValid: true,
      reason: isOverdue ? 'Overdue by $overdueDays days' : 'Ready to return',
      book: book,
      copy: copy,
      activeLoan: activeLoan,
      isOverdue: isOverdue,
      overdueDays: overdueDays,
      fineAmount: fineAmount,
      belongsToCurrentStudent: isSameStudent,
      actualBorrowerName: actualBorrowerName,
    );
  }

  /// Calculates expected due date according to library settings
  static DateTime calculateDueDate({
    DateTime? fromDate,
    required SystemSettings settings,
  }) {
    final start = fromDate ?? DateTime.now();
    return start.add(Duration(days: settings.loanDurationDays));
  }
}
