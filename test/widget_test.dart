import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bibledoor/app_controller.dart';
import 'package:bibledoor/data/bible_parser.dart';
import 'package:bibledoor/data/bible_repository.dart';
import 'package:bibledoor/main.dart';
import 'package:bibledoor/models/bible.dart';

class MemoryRepository extends BibleRepository {
  MemoryRepository(super.root);
  @override
  Future<void> writeState(Map<String, dynamic> state) async {}
}

void main() {
  late Directory directory;
  late AppController c;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('bibledoor-widget-');
    c = AppController(MemoryRepository(directory))..ready = true;
  });
  tearDown(() {
    c.dispose();
    c.repository.dispose();
    directory.deleteSync(recursive: true);
  });
  testWidgets(
    'first-run experience opens Library and validates key without network',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(BibleDoorApp(controller: c));
      expect(find.text('A little key.\nA world of meaning.'), findsOneWidget);
      await tester.ensureVisible(find.text('Open your first Bible'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open your first Bible'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '../bad');
      await tester.tap(find.text('Open Bible'));
      await tester.pumpAndSettle();
      expect(find.text('Use a key such as webbe-123-456.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('reading, dark mode, and comparison fit phone and tablet', (
    tester,
  ) async {
    const book = BibleBook('TIT', 'Tit', 'Titus', 'Titus', 3, 4, 0);
    final version = BibleVersion(
      key: 'test-123-456',
      header: const {
        'Version name': 'World English Bible',
        'Version abbreviation': 'WEB',
      },
      books: [book],
      divisions: ['New Testament'],
    );
    c.versions = [version];
    c.cached[version.key] = {'TIT'};
    c.primary.version = version;
    c.primary.content = BibleParser.text(
      book,
      File('test/fixtures/TIT.1.bd.txt').readAsStringSync(),
      decodeBibleJson(File('test/fixtures/TIT.1.bd.idx').readAsStringSync()),
    );
    c.primary.index = 1;
    c.primary.target = const Passage('TIT', 1, 1);
    c.secondary.version = version;
    c.secondary.content = c.primary.content;
    c.secondary.index = 2;
    c.secondary.target = const Passage('TIT', 2, 1);
    for (final size in [const Size(360, 740), const Size(1024, 768)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(size);
      c.compare = true;
      c.themeMode = ThemeMode.dark;
      await tester.pumpWidget(BibleDoorApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('References & scrolling linked'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Bookmark section'));
      await tester.pumpAndSettle();
      expect(c.bookmarks, isNotEmpty);
      c.bookmarks.clear();
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
