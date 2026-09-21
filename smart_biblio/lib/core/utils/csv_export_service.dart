import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/audit_log.dart';

class CsvExportService {
  static String _escapeCsvValue(dynamic value) {
    if (value == null) return '""';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return '"$str"';
  }

  /// Converts Audit Logs into standard CSV string
  static String generateAuditLogCsv(List<AuditLog> logs) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln('ID,Timestamp,Actor Type,Actor ID,Action,Entity Type,Entity ID,Details');

    for (final log in logs) {
      final line = [
        _escapeCsvValue(log.id),
        _escapeCsvValue(log.timestamp.toIso8601String()),
        _escapeCsvValue(log.actorType),
        _escapeCsvValue(log.actorId),
        _escapeCsvValue(log.action),
        _escapeCsvValue(log.entityType),
        _escapeCsvValue(log.entityId),
        _escapeCsvValue(log.details),
      ].join(',');
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  /// Converts Detailed Loans into standard CSV string
  static String generateLoansReportCsv(List<Map<String, dynamic>> loans) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln(
      'Transaction No,Status,Borrowed At,Due Date,Returned At,Renewals,Fine Amount,Fine Status,Student ID,Student Name,Department,Book Title,Author,ISBN,Shelf,Barcode,RFID EPC',
    );

    for (final row in loans) {
      final line = [
        _escapeCsvValue(row['transaction_no']),
        _escapeCsvValue(row['loan_status']),
        _escapeCsvValue(row['borrowed_at']),
        _escapeCsvValue(row['due_at']),
        _escapeCsvValue(row['returned_at'] ?? 'N/A'),
        _escapeCsvValue(row['renewal_count']),
        _escapeCsvValue(row['fine_amount']),
        _escapeCsvValue(row['fine_status']),
        _escapeCsvValue(row['student_number']),
        _escapeCsvValue(row['student_name']),
        _escapeCsvValue(row['grade_department']),
        _escapeCsvValue(row['book_title']),
        _escapeCsvValue(row['book_author']),
        _escapeCsvValue(row['isbn']),
        _escapeCsvValue(row['shelf_location']),
        _escapeCsvValue(row['copy_barcode']),
        _escapeCsvValue(row['rfid_epc']),
      ].join(',');
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  /// Converts Catalog & Physical Copies into standard CSV string
  static String generateCatalogInventoryCsv(List<Map<String, dynamic>> items) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln(
      'Book Title,Author,ISBN,Publisher,Year,Category,Shelf Location,Copy Barcode,RFID EPC,Status,Condition',
    );

    for (final row in items) {
      final line = [
        _escapeCsvValue(row['title']),
        _escapeCsvValue(row['author']),
        _escapeCsvValue(row['isbn']),
        _escapeCsvValue(row['publisher']),
        _escapeCsvValue(row['publish_year']),
        _escapeCsvValue(row['category']),
        _escapeCsvValue(row['shelf_location']),
        _escapeCsvValue(row['copy_barcode']),
        _escapeCsvValue(row['rfid_epc']),
        _escapeCsvValue(row['copy_status']),
        _escapeCsvValue(row['copy_condition']),
      ].join(',');
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  /// Saves CSV string to disk in application documents or temp directory
  static Future<File> saveCsvToFile({
    required String filenamePrefix,
    required String csvContent,
  }) async {
    Directory targetDir;
    try {
      targetDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      targetDir = Directory.current;
    }

    final dateStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = '${filenamePrefix}_$dateStamp.csv';
    final filePath = p.join(targetDir.path, filename);

    final file = File(filePath);
    await file.writeAsString(csvContent, flush: true);
    return file;
  }
}
