import '../models/book.dart';
import '../models/book_copy.dart';
import '../models/member.dart';
import 'app_database.dart';

class SeedData {
  static Future<void> populateIfEmpty(AppDatabase db) async {
    final existingBooks = await db.getAllBooks();
    if (existingBooks.isNotEmpty) return; // Already seeded

    // 1. Seed Members
    final members = [
      Member(
        id: 'member-01',
        studentNumber: 'STU-2026-001',
        fullName: 'Ahmed Ben Ali',
        email: 'ahmed.benali@univ.edu',
        phone: '+213 555 123 456',
        gradeDepartment: 'Computer Science (Master 2)',
        maxLoans: 5,
        status: 'active',
      ),
      Member(
        id: 'member-02',
        studentNumber: 'STU-2026-002',
        fullName: 'Sarah Chen',
        email: 'sarah.chen@univ.edu',
        phone: '+213 555 987 654',
        gradeDepartment: 'Data Science & AI',
        maxLoans: 5,
        status: 'active',
      ),
      Member(
        id: 'member-03',
        studentNumber: 'STU-2026-003',
        fullName: 'Marcus Vance',
        email: 'marcus.vance@univ.edu',
        phone: '+213 555 333 222',
        gradeDepartment: 'Mechanical Engineering',
        maxLoans: 4,
        status: 'active',
      ),
      Member(
        id: 'member-04',
        studentNumber: 'STU-2026-004',
        fullName: 'Yasmine Kaci',
        email: 'yasmine.kaci@univ.edu',
        phone: '+213 555 444 888',
        gradeDepartment: 'Civil Engineering',
        maxLoans: 5,
        status: 'suspended', // Suspended student for testing validation!
      ),
    ];

    for (final m in members) {
      await db.insertMember(m);
    }

    // 2. Assign RFID Cards
    await db.assignCardToMember(
      memberId: 'member-01',
      epc: 'E28068940000501234567890', // Ahmed's primary test card
    );
    await db.assignCardToMember(
      memberId: 'member-02',
      epc: 'CARD00000000000000000002', // Sarah's card
    );
    await db.assignCardToMember(
      memberId: 'member-03',
      epc: 'CARD00000000000000000003', // Marcus's card
    );
    await db.assignCardToMember(
      memberId: 'member-04',
      epc: 'CARD00000000000000000004', // Yasmine's card
    );

    // 3. Seed Books
    final books = [
      Book(
        id: 'book-01',
        title: 'Clean Code: A Handbook of Agile Software Craftsmanship',
        author: 'Robert C. Martin',
        isbn: '978-0132350884',
        publisher: 'Prentice Hall',
        publishYear: 2008,
        category: 'Computer Science',
        shelfLocation: 'CS-101',
        description: 'Even bad code can function. But if code isn\'t clean, it can bring a development organization to its knees.',
      ),
      Book(
        id: 'book-02',
        title: 'Database System Concepts (7th Edition)',
        author: 'Abraham Silberschatz, Henry Korth',
        isbn: '978-0078022159',
        publisher: 'McGraw-Hill',
        publishYear: 2019,
        category: 'Computer Science',
        shelfLocation: 'CS-102',
        description: 'Comprehensive presentation of database management system concepts.',
      ),
      Book(
        id: 'book-03',
        title: 'Operating System Concepts (10th Edition)',
        author: 'Abraham Silberschatz, Peter B. Galvin',
        isbn: '978-1119800361',
        publisher: 'Wiley',
        publishYear: 2021,
        category: 'Computer Science',
        shelfLocation: 'CS-103',
        description: 'Fundamental concepts of modern operating systems, virtualization, and security.',
      ),
      Book(
        id: 'book-04',
        title: 'Designing Data-Intensive Applications',
        author: 'Martin Kleppmann',
        isbn: '978-1449373320',
        publisher: 'O\'Reilly Media',
        publishYear: 2017,
        category: 'Computer Science',
        shelfLocation: 'CS-104',
        description: 'The big ideas behind reliable, scalable, and maintainable systems.',
      ),
      Book(
        id: 'book-05',
        title: 'Introduction to Algorithms (4th Edition)',
        author: 'Thomas H. Cormen, Charles E. Leiserson',
        isbn: '978-0262046305',
        publisher: 'MIT Press',
        publishYear: 2022,
        category: 'Computer Science',
        shelfLocation: 'CS-105',
        description: 'The leading algorithms text worldwide, an essential reference for universities.',
      ),
      Book(
        id: 'book-06',
        title: 'Artificial Intelligence: A Modern Approach (4th Edition)',
        author: 'Stuart Russell, Peter Norvig',
        isbn: '978-0134610993',
        publisher: 'Pearson',
        publishYear: 2020,
        category: 'Artificial Intelligence',
        shelfLocation: 'AI-201',
        description: 'The definitive introduction to the theory and practice of artificial intelligence.',
      ),
    ];

    for (final b in books) {
      await db.insertBook(b);
    }

    // 4. Seed Physical Copies with RFID EPC tags
    final copies = [
      // Clean Code - Copy 1
      BookCopy(
        id: 'copy-01-a',
        bookId: 'book-01',
        copyBarcode: 'BC-CC-001',
        rfidEpc: 'E28068940000000000000001',
        status: 'available',
      ),
      // Clean Code - Copy 2
      BookCopy(
        id: 'copy-01-b',
        bookId: 'book-01',
        copyBarcode: 'BC-CC-002',
        rfidEpc: 'E28068940000000000000002',
        status: 'available',
      ),
      // Database Systems - Copy 1
      BookCopy(
        id: 'copy-02-a',
        bookId: 'book-02',
        copyBarcode: 'BC-DB-001',
        rfidEpc: 'E28068940000000000000003',
        status: 'available',
      ),
      // Operating System Concepts - Copy 1
      BookCopy(
        id: 'copy-03-a',
        bookId: 'book-03',
        copyBarcode: 'BC-OS-001',
        rfidEpc: 'E28068940000000000000004',
        status: 'available',
      ),
      // Designing Data-Intensive Applications - Copy 1
      BookCopy(
        id: 'copy-04-a',
        bookId: 'book-04',
        copyBarcode: 'BC-DDIA-001',
        rfidEpc: 'E28068940000000000000005',
        status: 'available',
      ),
      // Introduction to Algorithms - Copy 1
      BookCopy(
        id: 'copy-05-a',
        bookId: 'book-05',
        copyBarcode: 'BC-ALGO-001',
        rfidEpc: 'E28068940000000000000006',
        status: 'available',
      ),
    ];

    for (final c in copies) {
      await db.insertBookCopy(c);
    }

    // 5. Seed an active loan for Ahmed to test return & overdue workflows
    // Ahmed already has Copy 1 of Clean Code borrowed
    await db.borrowBookCopy(
      member: members[0], // Ahmed
      copy: copies[0],
      durationDays: 14,
    );
  }
}
