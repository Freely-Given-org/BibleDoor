import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bibledoor/app_controller.dart';
import 'package:bibledoor/data/bible_repository.dart';
import 'package:bibledoor/main.dart';
import 'package:bibledoor/models/bible.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native storage, offline reading, navigation, search, settings and restart',
    (tester) async {
      final root = Directory(
        '${(await getTemporaryDirectory()).path}/bibledoor-smoke-${DateTime.now().microsecondsSinceEpoch}',
      );
      final repo = BibleRepository(root);
      const first =
          's1=The first section\np={c1}{v1}A passage for testing.\\f + \\ft A note.\\f*';
      const second =
          's1=The second section\np={v2}Read in context and keep your place.';
      final files = <String, String>{
        'BDHeader.json': jsonEncode({
          'Data format version': 1,
          'Version name': 'Smoke test Bible',
          'Version abbreviation': 'TEST',
          'Shareable': true,
        }),
        'BDBookNames.1.json': jsonEncode([
          ['TIT', 'Tit', 'Titus', 'Titus', 1, 2, 0],
        ]),
        'ByBook.1.BDTXT/TIT.1.bd.txt': '$first$second',
        'ByBook.1.BDTXT/TIT.1.bd.idx': jsonEncode([
          [1, 1, 0, first.runes.length, 1],
          [1, 2, first.runes.length, second.runes.length, 2],
        ]),
      };
      final archive = Archive();
      for (final e in files.entries) {
        final bytes = utf8.encode(e.value);
        archive.addFile(ArchiveFile(e.key, bytes.length, bytes));
      }
      final version = await repo.importPackage(
        Uint8List.fromList(ZipEncoder().encode(archive)),
      );
      final c = AppController(repo);
      await c.initialize();
      await tester.pumpWidget(BibleDoorApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('The first section'), findsOneWidget);
      await tester.tap(find.byTooltip('Next section'));
      await tester.pumpAndSettle();
      expect(find.text('The second section'), findsOneWidget);
      await tester.tap(find.byTooltip('Bookmark section'));
      await tester.pumpAndSettle();
      expect(c.isBookmarked, isTrue);
      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'context');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('1 matching sections'), findsOneWidget);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(c.themeMode, ThemeMode.dark);
      await tester.scrollUntilVisible(find.text('About Bible Door'), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text('About Bible Door'));
      await tester.pumpAndSettle();
      expect(find.text('Version 1.0.2 (build 3)'), findsOneWidget);
      expect(find.textContaining('Installed Bibles'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await c.save();
      final restored = AppController(repo);
      await restored.initialize();
      expect(restored.primary.section!.start, const Passage('TIT', 1, 2));
      expect(restored.bookmarks.length, 1);
      expect(restored.themeMode, ThemeMode.dark);
      expect(await repo.exportPackage(version), isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await c.save();
      await restored.save();
      c.dispose();
      restored.dispose();
      repo.dispose();
      await root.delete(recursive: true);
    },
  );
}
