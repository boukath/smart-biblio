class Book {
  final String id;
  final String title;
  final String author;
  final String isbn;
  final String publisher;
  final int publishYear;
  final String category;
  final String shelfLocation;
  final String description;
  final String? coverUrl;
  final DateTime createdAt;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    this.publisher = '',
    this.publishYear = 2024,
    this.category = 'General',
    this.shelfLocation = 'A-01',
    this.description = '',
    this.coverUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'publisher': publisher,
      'publish_year': publishYear,
      'category': category,
      'shelf_location': shelfLocation,
      'description': description,
      'cover_url': coverUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      isbn: map['isbn'] as String,
      publisher: map['publisher'] as String? ?? '',
      publishYear: map['publish_year'] as int? ?? 2024,
      category: map['category'] as String? ?? 'General',
      shelfLocation: map['shelf_location'] as String? ?? 'A-01',
      description: map['description'] as String? ?? '',
      coverUrl: map['cover_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
