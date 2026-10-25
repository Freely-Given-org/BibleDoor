import '../models/bible.dart';

Passage? parseReference(String input, BibleVersion version) {
  final match = RegExp(
    r'^\s*(.+?)\s+(\d+)(?:\s*[:.]\s*(\d+)(?:\s*[-–]\s*\d+)?)?\s*$',
  ).firstMatch(input);
  if (match == null) return null;
  String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s.]'), '');
  final name = normalize(match[1]!);
  final book = version.books
      .where(
        (b) => [
          b.name,
          b.abbreviation,
          b.code,
          b.title,
        ].any((n) => normalize(n) == name),
      )
      .firstOrNull;
  if (book == null) return null;
  final chapter = int.parse(match[2]!);
  final verse = int.tryParse(match[3] ?? '') ?? 1;
  if (chapter < 1 || chapter > book.chapters || verse < 1) return null;
  return Passage(book.code, chapter, verse);
}
