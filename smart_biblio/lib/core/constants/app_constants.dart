class AppConstants {
  static const String appName = 'Smart Biblio';
  static const String appVersion = '1.0.0';

  // RFID Memory Banks
  static const int rfidBankReserved = 0;
  static const int rfidBankEpc = 1;
  static const int rfidBankTid = 2;
  static const int rfidBankUser = 3;

  // Default Policy Settings
  static const int defaultLoanDurationDays = 14;
  static const int defaultMaxLoansPerMember = 5;
  static const double defaultFinePerDay = 50.0; // In DZD or local currency
  static const int defaultGracePeriodDays = 2;
  static const int defaultDebounceMs = 1200;
  static const int defaultSessionTimeoutSeconds = 45;

  // EPC Prefixes for partitioning cards vs book tags if configured
  static const String studentCardEpcPrefix = 'CARD';
  static const String bookCopyEpcPrefix = 'BOOK';

  // Database Filename
  static const String databaseFileName = 'smart_biblio_v1.db';
}
