import 'dart:io';

import 'package:bibledoor/app_controller.dart';
import 'package:bibledoor/data/bible_repository.dart';
import 'package:bibledoor/main.dart';
import 'package:bibledoor/models/bible.dart';
import 'package:bibledoor/ui/about.dart';
import 'package:bibledoor/ui/library.dart';
import 'package:bibledoor/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutRepository extends BibleRepository {
  AboutRepository() : super(Directory('/unused-about-test'));
  final removed = <String>[];
  @override
  Future<void> writeState(Map<String, dynamic> state) async {}
  @override
  Future<void> remove(BibleVersion version) async => removed.add(version.key);
}

const webbe = BibleVersion(
  key: 'webbe-123-456',
  header: {
    'Version name': 'World English Bible (British edition)',
    'Version abbreviation': 'WEBBE',
    'Conversion date': '2023-02-06',
    'Has section headings': true,
    'Shareable': true,
  },
  books: [
    BibleBook('TIT', 'Tit', 'Titus', 'Titus', 3, 4, 0),
    BibleBook('JHN', 'Jn', 'John', 'John', 21, 50, 0),
  ],
  divisions: ['New Testament'],
);
const imported = BibleVersion(
  key: 'local-test',
  header: {
    'Version name': 'Imported translation',
    'Version abbreviation': 'LOCAL',
  },
  books: [BibleBook('TIT', 'Tit', 'Titus', 'Titus', 3, 4, 0)],
  divisions: ['New Testament'],
);

void main() {
  late AboutRepository repo;
  late AppController c;
  setUp(() {
    repo = AboutRepository();
    c = AppController(repo)..ready = true;
    PackageInfo.setMockInitialValues(
      appName: 'Bible Door',
      packageName: 'org.freelygiven.bibledoor',
      version: '9.8.7',
      buildNumber: '42',
      buildSignature: '',
    );
  });
  tearDown(() {
    c.dispose();
    repo.dispose();
  });

  testWidgets('Settings puts Privacy last and About only describes the app', (
    tester,
  ) async {
    await tester.pumpWidget(BibleDoorApp(controller: c));
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('About Bible Door'), 300);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Privacy')).dy,
      greaterThan(tester.getTopLeft(find.text('About Bible Door')).dy),
    );
    await tester.tap(find.text('About Bible Door'));
    await tester.pumpAndSettle();
    expect(find.text('Version 9.8.7 (build 42)'), findsOneWidget);
    expect(find.textContaining('Installed Bibles'), findsNothing);
    expect(find.text('Remove from device'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsNothing);
    expect(find.text('App information and websites'), findsOneWidget);
  });

  testWidgets(
    'About opens both websites externally and handles browser failure',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      var fail = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        if (fail) throw PlatformException(code: 'no-browser');
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(MaterialApp(home: const AboutScreen()));
      await tester.pumpAndSettle();
      for (final name in ['Freely-Given.org', 'OET.Bible']) {
        await tester.ensureVisible(find.text(name));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      expect(calls.map((c) => Uri.parse(c.arguments['url'] as String).host), [
        'freely-given.org',
        'oet.bible',
      ]);
      expect(
        calls.every(
          (c) =>
              c.arguments['useWebView'] == false &&
              c.arguments['useSafariVC'] == false,
        ),
        isTrue,
      );
      fail = true;
      await tester.tap(find.text('OET.Bible'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not open the browser.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Bible information and confirmed removal stay in sync on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      c.versions = [webbe, imported];
      c.cached[webbe.key] = {'TIT'};
      c.bookmarks = [
        SavedPassage(webbe.key, const Passage('TIT', 1, 1), 'Keep me'),
        SavedPassage(imported.key, const Passage('TIT', 1, 1), 'Remove me'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: AnimatedBuilder(
            animation: c,
            builder: (context, _) => Scaffold(
              body: LibraryScreen(controller: c, onRead: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> menu(BibleVersion version, String item) async {
        final card = find.byKey(ValueKey('library-bible-${version.key}'));
        final options = find.descendant(
          of: card,
          matching: find.byTooltip('Bible options'),
        );
        await tester.scrollUntilVisible(
          options,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(options);
        await tester.pumpAndSettle();
        await tester.tap(find.text(item));
        await tester.pumpAndSettle();
      }

      await menu(webbe, 'About this Bible');
      expect(
        find.text('WEBBE · 1 of 2 books available offline'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Bible Door export date: 2023-02-06'),
        findsOneWidget,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await menu(imported, 'About this Bible');
      expect(
        find.textContaining('Imported from a Bible Door ZIP'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Publisher has not permitted package sharing.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await menu(imported, 'Remove from device');
      expect(find.textContaining('Keep the original ZIP'), findsOneWidget);
      await tester.tap(find.text('Keep Bible'));
      await tester.pumpAndSettle();
      expect(repo.removed, isEmpty);
      await menu(imported, 'Remove from device');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(repo.removed, [imported.key]);
      expect(c.versions, [webbe]);
      expect(c.bookmarks.single.version, webbe.key);
      expect(
        find.byKey(const ValueKey('library-bible-local-test')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Library links to free Bible demos and explains where to find keys',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      String? opened;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        opened = call.arguments['url'] as String;
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryScreen(controller: c, onRead: () {}),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Find free Bibles'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('near the bottom'), findsOneWidget);
      await tester.tap(find.text('Find free Bibles'));
      await tester.pumpAndSettle();
      expect(opened, 'https://freely-given.org/Software/BibleDropBox/Demos/');
    },
  );
}
