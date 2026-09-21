class SystemSettings {
  final int loanDurationDays;
  final int maxLoansPerStudent;
  final double finePerDay;
  final int gracePeriodDays;
  final int debounceMs;
  final int autoTimeoutSeconds;
  final String libraryName;
  final String currency;
  final bool allowReturnOtherMemberBooks;
  final int readerPort;
  final int readerBaud;

  SystemSettings({
    this.loanDurationDays = 14,
    this.maxLoansPerStudent = 5,
    this.finePerDay = 50.0,
    this.gracePeriodDays = 2,
    this.debounceMs = 1200,
    this.autoTimeoutSeconds = 45,
    this.libraryName = 'Smart Biblio University Library',
    this.currency = 'DZD',
    this.allowReturnOtherMemberBooks = false,
    this.readerPort = 100, // USB default
    this.readerBaud = 115200,
  });

  Map<String, String> toSettingsMap() {
    return {
      'loan_duration_days': loanDurationDays.toString(),
      'max_loans_per_student': maxLoansPerStudent.toString(),
      'fine_per_day': finePerDay.toString(),
      'grace_period_days': gracePeriodDays.toString(),
      'debounce_ms': debounceMs.toString(),
      'auto_timeout_seconds': autoTimeoutSeconds.toString(),
      'library_name': libraryName,
      'currency': currency,
      'allow_return_other_member_books': allowReturnOtherMemberBooks ? '1' : '0',
      'reader_port': readerPort.toString(),
      'reader_baud': readerBaud.toString(),
    };
  }

  factory SystemSettings.fromMap(Map<String, String> map) {
    return SystemSettings(
      loanDurationDays: int.tryParse(map['loan_duration_days'] ?? '') ?? 14,
      maxLoansPerStudent: int.tryParse(map['max_loans_per_student'] ?? '') ?? 5,
      finePerDay: double.tryParse(map['fine_per_day'] ?? '') ?? 50.0,
      gracePeriodDays: int.tryParse(map['grace_period_days'] ?? '') ?? 2,
      debounceMs: int.tryParse(map['debounce_ms'] ?? '') ?? 1200,
      autoTimeoutSeconds: int.tryParse(map['auto_timeout_seconds'] ?? '') ?? 45,
      libraryName: map['library_name'] ?? 'Smart Biblio University Library',
      currency: map['currency'] ?? 'DZD',
      allowReturnOtherMemberBooks: map['allow_return_other_member_books'] == '1',
      readerPort: int.tryParse(map['reader_port'] ?? '') ?? 100,
      readerBaud: int.tryParse(map['reader_baud'] ?? '') ?? 115200,
    );
  }
}
