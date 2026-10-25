import '../models/bible.dart';

/// Reads the current BOS text export and the older JSON line representation.
/// Index offsets are Python Unicode-code-point offsets, NOT UTF-8 byte offsets
/// or Dart UTF-16 offsets. Keep this conversion before slicing sections.
class BibleParser {
  static BookContent text(BibleBook book, String source, Object? index) {
    if (index is! List || index.isEmpty) {
      throw const BibleException(
        'The Bible section index is missing or empty.',
      );
    }
    final points = source.replaceFirst(RegExp(r'^\uFEFF'), '').runes.toList();
    final sections = <BibleSection>[];
    var previousEnd = 0;
    for (final row in index) {
      if (row is! List ||
          row.length < 5 ||
          row.length > 6 ||
          row.any((value) => value is! int)) {
        throw const BibleException('The Bible section index is invalid.');
      }
      final values = row.cast<int>();
      final offset = values[2], length = values[3];
      if (offset < previousEnd ||
          length < 1 ||
          offset + length > points.length) {
        throw const BibleException(
          'Bible text and section index do not match.',
        );
      }
      previousEnd = offset + length;
      final start = Passage(book.code, values[0], values[1]);
      final end = Passage(
        book.code,
        values.length == 6 ? values[5] : values[0],
        values[4],
      );
      sections.add(
        _section(
          book,
          String.fromCharCodes(points.sublist(offset, offset + length)),
          start,
          end,
        ),
      );
    }
    return BookContent(book.code, sections);
  }

  static BibleSection _section(
    BibleBook book,
    String source,
    Passage start,
    Passage end,
  ) {
    final paragraphs = <BibleParagraph>[];
    final notes = <BibleNote>[];
    var chapter = start.chapter, verse = start.verse;
    final paragraphPattern = RegExp(r'(?:^|\n)([a-z][a-z0-9¤]*)=');
    final matches = paragraphPattern.allMatches(source).toList();
    if (matches.isEmpty) {
      throw const BibleException('A Bible section has no paragraphs.');
    }
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final raw = source.substring(
        match.end,
        i + 1 < matches.length ? matches[i + 1].start : source.length,
      );
      final runs = <TextRun>[];
      // Word attributes are metadata; retain the actual word, including nested styles.
      final words = raw.replaceAllMapped(
        RegExp(r'\\\+?w\s+([^|]*?)(?:\|[^\\]*?)?\\\+?w\*'),
        (m) => m[1]!,
      );
      final token = RegExp(
        r'\{c(\d+)\}|\{v([^}]+)\}|\\(f|fe|x)\s(.*?)\\\3\*|\\(\+?[a-z][a-z0-9]*)(\*)?\s?',
        dotAll: true,
      );
      final styles = <String>{};
      var position = 0;
      void append(String value) {
        if (value.isNotEmpty) {
          runs.add(
            TextRun(
              value,
              italic: styles.any(
                (s) => ['add', 'it', 'em', 'bk', 'qt'].contains(s),
              ),
              bold: styles.contains('bd') || styles.contains('bdit'),
              jesus: styles.contains('wj'),
            ),
          );
        }
      }

      for (final t in token.allMatches(words)) {
        append(words.substring(position, t.start));
        position = t.end;
        if (t[1] != null) {
          chapter = int.parse(t[1]!);
        } else if (t[2] != null) {
          verse =
              int.tryParse(RegExp(r'\d+').firstMatch(t[2]!)?.group(0) ?? '') ??
              verse;
          runs.add(TextRun(' ${t[2]} ', verse: t[2], chapter: chapter));
        } else if (t[3] != null) {
          notes.add(
            BibleNote(
              cleanNote(t[4]!),
              Passage(book.code, chapter, verse),
              crossReference: t[3] == 'x',
            ),
          );
          runs.add(TextRun(' [${notes.length}] '));
        } else {
          final marker = t[5]!.replaceFirst('+', '');
          if (t[6] != null) {
            styles.remove(marker);
          } else {
            styles.add(marker);
          }
        }
      }
      append(words.substring(position));
      paragraphs.add(BibleParagraph(match[1]!, runs));
    }
    final headings = paragraphs.where(
      (p) => p.heading && p.text.trim().isNotEmpty,
    );
    return BibleSection(
      start: start,
      end: end,
      paragraphs: paragraphs,
      notes: notes,
      title: headings.isNotEmpty
          ? headings.first.text.trim()
          : start.chapter < 1
          ? 'Introduction'
          : '${book.name} ${start.chapter}',
    );
  }

  static String cleanNote(String text) => text
      .replaceFirst(RegExp(r'^[+\-]\s*'), '')
      .replaceAll(RegExp(r'\\\+?[a-z][a-z0-9]*\*?\s?'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static BookContent json(
    BibleBook book,
    Object? value, {
    required bool hasHeadings,
  }) {
    if (value is! List || value.isEmpty) {
      throw const BibleException('The Bible book is empty.');
    }
    final groups = <({String text, Passage start, Passage end})>[];
    var chapter = -1, verse = 1;
    var start = Passage(book.code, -1, 1), end = start;
    var buffer = StringBuffer();
    final headings =
        hasHeadings &&
        value.any((row) => row is List && row.isNotEmpty && row[0] == 's1');
    void flush() {
      if (buffer.isNotEmpty) {
        groups.add((text: buffer.toString(), start: start, end: end));
      }
      buffer = StringBuffer();
    }

    final paragraph = RegExp(
      r'^(?:i?p|i?m|q|qm|iq|li|s|ms|mt|mte|imt|is|r|d|sp|b|ib|nb|cls|pc|pr|pm|pmc|pmr|pi|mi|tr)\d*$',
    );
    for (final row in value) {
      if (row is! List || row.isEmpty || row[0] is! String) {
        throw const BibleException('The Bible book contains an invalid line.');
      }
      final marker = row[0] as String;
      var content = row.length > 1 && row[1] != null ? row[1].toString() : '';
      if (marker == 'c') {
        if (chapter < 1 || !headings || ['PSA', 'LAM'].contains(book.code)) {
          flush();
        }
        chapter = int.tryParse(content) ?? chapter;
        verse = 1;
        if (buffer.isEmpty) start = Passage(book.code, chapter, verse);
        end = Passage(book.code, chapter, verse);
        buffer.write('\np={c$chapter}');
      } else if (marker == 'v=' || marker == 'v') {
        verse =
            int.tryParse(RegExp(r'\d+').firstMatch(content)?.group(0) ?? '') ??
            verse;
        if (chapter < 1) chapter = 1;
        if (marker == 'v') {
          end = Passage(book.code, chapter, verse);
          buffer.write('{v$content}');
        }
      } else if (paragraph.hasMatch(marker) ||
          marker == 'v~' ||
          marker == 'p~') {
        if (marker == 's1' && headings) {
          flush();
          start = Passage(book.code, chapter, verse);
        }
        if (row.length > 2 && row[2] is List) {
          // BOS extras use Unicode character offsets into the clean text.
          final chars = content.runes.toList();
          final inserts = <({int offset, String note})>[];
          for (final extra in row[2] as List) {
            if (extra is List &&
                extra.length >= 3 &&
                extra[1] is int &&
                ['fn', 'f', 'xr', 'x'].contains(extra[0])) {
              final code = ['xr', 'x'].contains(extra[0]) ? 'x' : 'f';
              inserts.add((
                offset: (extra[1] as int).clamp(0, chars.length),
                note: '\\$code ${extra[2]}\\$code*',
              ));
            }
          }
          inserts.sort((a, b) => b.offset.compareTo(a.offset));
          for (final insert in inserts) {
            chars.insertAll(insert.offset, insert.note.runes);
          }
          content = String.fromCharCodes(chars);
        }
        if (marker == 'v~' || marker == 'p~') {
          buffer.write('$content ');
        } else {
          buffer.write('\n$marker=$content');
        }
      }
    }
    flush();
    if (groups.isEmpty) {
      throw const BibleException('No readable text was found in this book.');
    }
    return BookContent(
      book.code,
      groups
          .map((g) => _section(book, g.text.trimLeft(), g.start, g.end))
          .toList(),
    );
  }
}
