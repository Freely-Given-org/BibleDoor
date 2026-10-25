import 'dart:convert';

/// Bible Door keys can have a multi-word prefix (for example oet-rv-123-456).
String normalizeKey(String value) => value.trim().toLowerCase();
bool isValidKey(String value) =>
    RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*-\d{3}-\d{3}$').hasMatch(value) &&
    value.length <= 100;

Object? decodeBibleJson(String source) =>
    jsonDecode(source.replaceFirst(RegExp(r'^\uFEFF'), ''));

class BibleException implements Exception {
  const BibleException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BibleBook {
  const BibleBook(
    this.code,
    this.abbreviation,
    this.name,
    this.title,
    this.chapters,
    this.sectionCount,
    this.division,
  );
  final String code, abbreviation, name, title;
  final int chapters, sectionCount, division;

  factory BibleBook.fromJson(Object? value) {
    if (value is! List ||
        value.length < 7 ||
        value.take(4).any((v) => v is! String) ||
        value.skip(4).take(3).any((v) => v is! int)) {
      throw const BibleException('This Bible has an invalid book list.');
    }
    final code = value[0] as String;
    if (!RegExp(r'^[A-Z0-9]{3}$').hasMatch(code)) {
      throw const BibleException('This Bible has an invalid book code.');
    }
    return BibleBook(
      code,
      value[1],
      value[2],
      value[3],
      value[4],
      value[5],
      value[6],
    );
  }
  List<Object> toJson() => [
    code,
    abbreviation,
    name,
    title,
    chapters,
    sectionCount,
    division,
  ];
}

class BibleVersion {
  const BibleVersion({
    required this.key,
    required this.header,
    required this.books,
    required this.divisions,
  });
  final String key;
  final Map<String, dynamic> header;
  final List<BibleBook> books;
  final List<String> divisions;
  String get name => header['Version name'] as String;
  String get abbreviation => header['Version abbreviation'] as String;
  bool get shareable => header['Shareable'] == true;
  bool get hasHeadings => header['Has section headings'] == true;
  String get date => header['Conversion date']?.toString() ?? 'Not supplied';
  BibleBook book(String code) => books.firstWhere((book) => book.code == code);

  static Map<String, dynamic> validateHeader(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['Data format version'] != 1 ||
        value['Version name'] is! String ||
        (value['Version name'] as String).trim().isEmpty ||
        value['Version abbreviation'] is! String) {
      throw const BibleException(
        'This Bible uses an unsupported or incomplete data format. '
        'Ask its publisher for a Bible Door format 1 export.',
      );
    }
    return value;
  }
}

class Passage {
  const Passage(this.book, this.chapter, this.verse);
  final String book;
  final int chapter, verse;
  Map<String, dynamic> toJson() => {
    'book': book,
    'chapter': chapter,
    'verse': verse,
  };
  factory Passage.fromJson(Map<String, dynamic> json) => Passage(
    json['book'] as String,
    json['chapter'] as int,
    json['verse'] as int,
  );
  @override
  bool operator ==(Object other) =>
      other is Passage &&
      book == other.book &&
      chapter == other.chapter &&
      verse == other.verse;
  @override
  int get hashCode => Object.hash(book, chapter, verse);
  String label(BibleVersion version) => chapter < 1
      ? '${version.book(book).name} · Introduction'
      : '${version.book(book).name} $chapter:$verse';
}

class TextRun {
  const TextRun(
    this.text, {
    this.italic = false,
    this.bold = false,
    this.jesus = false,
    this.verse,
    this.chapter,
  });
  final String text;
  final bool italic, bold, jesus;
  final String? verse;
  final int? chapter;
}

class BibleParagraph {
  const BibleParagraph(this.marker, this.runs);
  final String marker;
  final List<TextRun> runs;
  String get text =>
      runs.where((r) => r.verse == null).map((r) => r.text).join();
  bool get heading =>
      RegExp(r'^(s\d?|ms\d?|mt\d?|mte\d?|imt\d?|is\d?)$').hasMatch(marker);
  bool get poetry => RegExp(r'^(q|qm|iq|li)\d?$').hasMatch(marker);
}

class BibleNote {
  const BibleNote(this.text, this.reference, {this.crossReference = false});
  final String text;
  final Passage reference;
  final bool crossReference;
}

class BibleSection {
  const BibleSection({
    required this.start,
    required this.end,
    required this.paragraphs,
    required this.notes,
    required this.title,
  });
  final Passage start, end;
  final List<BibleParagraph> paragraphs;
  final List<BibleNote> notes;
  final String title;
  String get text => paragraphs.map((p) => p.text).join('\n');
  bool contains(int chapter, int verse) =>
      (chapter > start.chapter ||
          chapter == start.chapter && verse >= start.verse) &&
      (chapter < end.chapter || chapter == end.chapter && verse <= end.verse);
}

class BookContent {
  const BookContent(this.code, this.sections);
  final String code;
  final List<BibleSection> sections;
  int sectionFor(Passage passage) {
    final exact = sections.indexWhere(
      (s) => s.contains(passage.chapter, passage.verse),
    );
    if (exact >= 0) return exact;
    // Missing verses and verse bridges resolve to the nearest preceding section.
    var nearest = 0;
    for (var i = 0; i < sections.length; i++) {
      final start = sections[i].start;
      if (start.chapter < passage.chapter ||
          start.chapter == passage.chapter && start.verse <= passage.verse) {
        nearest = i;
      }
    }
    return nearest;
  }
}

class SavedPassage {
  const SavedPassage(this.version, this.passage, this.title);
  final String version, title;
  final Passage passage;
  Map<String, dynamic> toJson() => {
    'version': version,
    'passage': passage.toJson(),
    'title': title,
  };
  factory SavedPassage.fromJson(Map<String, dynamic> json) => SavedPassage(
    json['version'] as String,
    Passage.fromJson(json['passage'] as Map<String, dynamic>),
    json['title'] as String,
  );
}
