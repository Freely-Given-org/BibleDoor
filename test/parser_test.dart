import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bibledoor/data/bible_parser.dart';
import 'package:bibledoor/data/reference_parser.dart';
import 'package:bibledoor/models/bible.dart';

const titus = BibleBook(
  'TIT',
  'Tit',
  'Titus',
  'Paul’s Letter to Titus',
  3,
  4,
  0,
);
void main() {
  test('keys accept publisher prefixes but reject paths and URLs', () {
    for (final key in ['webbe-123-456', 'oet-rv-123-456', 'word2-123-456']) {
      expect(isValidKey(key), isTrue);
    }
    for (final key in [
      '../a-123-456',
      'https://evil/a-123-456',
      'word-1-2',
      'a-123-456/',
    ]) {
      expect(isValidKey(key), isFalse);
    }
    expect(normalizeKey(' WEBBE-123-456 '), 'webbe-123-456');
  });
  test(
    'real WEBBE text export retains all 46 Titus verse markers and notes',
    () {
      final book = BibleParser.text(
        titus,
        File('test/fixtures/TIT.1.bd.txt').readAsStringSync(),
        decodeBibleJson(File('test/fixtures/TIT.1.bd.idx').readAsStringSync()),
      );
      expect(book.sections.length, 4);
      expect(book.sections.first.title, 'Paul’s Letter to Titus');
      expect(book.sections[1].start.chapter, 1);
      expect(book.sections[3].end.verse, 15);
      final runs = book.sections
          .expand((s) => s.paragraphs)
          .expand((p) => p.runs)
          .toList();
      expect(runs.where((r) => r.verse != null).length, 46);
      expect(book.sections[1].text, contains('Paul, a servant of God'));
      expect(
        book.sections.map((s) => s.text).join(),
        isNot(contains('strong=')),
      );
      expect(book.sections[1].notes.first.text, contains('Anointed One'));
      expect(book.sections[3].text, contains('Grace be with you all'));
    },
  );
  test('legacy JSON preserves main text, paragraphs, and BOS footnotes', () {
    final book = BibleParser.json(
      titus,
      decodeBibleJson(File('test/fixtures/TIT.1.json').readAsStringSync()),
      hasHeadings: true,
    );
    expect(book.sections.length, 4);
    expect(book.sections[1].text, contains('Paul, a servant of God'));
    expect(book.sections[1].notes.first.text, contains('Anointed One'));
    expect(
      book.sections
          .expand((s) => s.paragraphs)
          .expand((p) => p.runs)
          .where((r) => r.verse != null)
          .length,
      46,
    );
  });
  test(
    'BOM and non-BMP Unicode offsets are code points, not bytes or UTF-16',
    () {
      const first = 's1=שלום 🌿\np={c1}{v1}Ἐν ἀρχῇ.\n';
      const second = 's1=Next\np={v3-4}שלום\\f + \\ft A note.\\f*';
      final book = BibleParser.text(titus, '\uFEFF$first$second', [
        [1, 1, 0, first.runes.length, 2],
        [1, 3, first.runes.length, second.runes.length, 4],
      ]);
      expect(book.sections.first.title, 'שלום 🌿');
      expect(book.sections.last.title, 'Next');
      expect(book.sections.last.notes.single.text, 'A note.');
      expect(book.sectionFor(const Passage('TIT', 1, 4)), 1);
      expect(decodeBibleJson('\uFEFF[1]'), [1]);
    },
  );
  test('inline styles, words of Jesus, and cross-chapter sections survive', () {
    const text =
        's1=Teaching\np={c1}{v5}\\wj Say \\add this\\add* now.\\wj*\np={c2}{v1}More.\\x - \\xt Titus 3:1\\x*';
    final book = BibleParser.text(titus, text, [
      [1, 5, 0, text.runes.length, 1, 2],
    ]);
    final runs = book.sections.single.paragraphs.expand((p) => p.runs);
    expect(runs.any((r) => r.italic && r.jesus && r.text == 'this'), isTrue);
    expect(book.sections.single.contains(2, 1), isTrue);
    expect(book.sections.single.notes.single.crossReference, isTrue);
  });
  test('bad indexes fail explicitly and unknown metadata is tolerated', () {
    expect(
      () => BibleParser.text(titus, 'p=text', [
        [1, 1, 0, 999, 1],
      ]),
      throwsA(isA<BibleException>()),
    );
    expect(
      () => BibleParser.text(titus, 'p=text', [
        [1, 1, -1, 5, 1],
      ]),
      throwsA(isA<BibleException>()),
    );
    expect(
      () => BibleVersion.validateHeader({'Data format version': 2}),
      throwsA(isA<BibleException>()),
    );
    expect(
      BibleVersion.validateHeader({
        'Data format version': 1,
        'Version name': 'Example',
        'Version abbreviation': 'EX',
        'Future field': 42,
      })['Future field'],
      42,
    );
  });
  test(
    'local book names and verse bridges resolve without requiring 66 books',
    () {
      final version = BibleVersion(
        key: 'example-123-456',
        header: const {'Version name': 'Example', 'Version abbreviation': 'EX'},
        books: [
          titus,
          const BibleBook(
            'CH1',
            '1Kru',
            '1 Krunikas',
            'An-ayan ne Krunikas',
            29,
            32,
            1,
          ),
        ],
        divisions: [],
      );
      expect(
        parseReference('1 Krunikas 12:3', version),
        const Passage('CH1', 12, 3),
      );
      expect(parseReference('Tit 3:1-4', version), const Passage('TIT', 3, 1));
      expect(parseReference('Titus 9:2', version), isNull);
      expect(parseReference('Titus 2', version), const Passage('TIT', 2, 1));
    },
  );
}
