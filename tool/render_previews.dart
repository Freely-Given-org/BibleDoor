// Run: flutter test tool/render_previews.dart
// These are real widget renders for layout review, not Play Store device captures.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bibledoor/ui/about.dart';
import 'package:bibledoor/ui/theme.dart';
import 'package:bibledoor/app_controller.dart';
import 'package:bibledoor/data/bible_parser.dart';
import 'package:bibledoor/data/bible_repository.dart';
import 'package:bibledoor/main.dart';
import 'package:bibledoor/models/bible.dart';

class PreviewRepository extends BibleRepository {
  PreviewRepository(super.root);
  @override
  Future<void> writeState(Map<String, dynamic> state) async {}
}

void main() {
  testWidgets('render phone and tablet previews', (tester) async {
    final output = Directory('docs/screenshots')..createSync(recursive: true);
    for (final entry in {
      'Roboto': '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
      'BibleSerif': '/usr/share/fonts/truetype/noto/NotoSerif-Regular.ttf',
    }.entries) {
      if (File(entry.value).existsSync()) {
        final loader = FontLoader(entry.key)
          ..addFont(
            Future.value(
              ByteData.sublistView(File(entry.value).readAsBytesSync()),
            ),
          );
        await loader.load();
      }
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final folder = Directory.systemTemp.createTempSync('bibledoor-preview-');
    final c = AppController(PreviewRepository(folder))..ready = true;
    final boundary = GlobalKey();
    Future<void> capture(String name, Size size, {bool about = false}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: about
              ? MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildTheme(Brightness.light),
                  home: const AboutScreen(),
                )
              : BibleDoorApp(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('welcome-phone', const Size(390, 844));
    await tester.ensureVisible(find.text('Open your first Bible'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open your first Bible'));
    await tester.pumpAndSettle();
    await capture('library-phone', const Size(390, 844));
    const book = BibleBook(
      'TIT',
      'Tit',
      'Titus',
      'Paul’s Letter to Titus',
      3,
      4,
      0,
    );
    final version = BibleVersion(
      key: 'webbe-123-456',
      header: const {
        'Version name': 'World English Bible (British edition)',
        'Version abbreviation': 'WEBBE',
        'Conversion date': '2023-02-06',
        'Has section headings': true,
        'Shareable': true,
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
    await tester.tap(find.text('Read').last);
    await capture('reader-phone', const Size(390, 844));
    c.secondary.version = version;
    c.secondary.content = c.primary.content;
    c.secondary.index = 2;
    c.secondary.target = const Passage('TIT', 2, 1);
    c.compare = true;
    c.linked = false;
    await capture('comparison-tablet', const Size(1200, 850));
    c.themeMode = ThemeMode.dark;
    await capture('comparison-dark-phone', const Size(390, 844));
    // This file is a Flutter test harness kept under tool/ for manual rendering.
    // ignore: invalid_use_of_visible_for_testing_member
    PackageInfo.setMockInitialValues(
      appName: 'Bible Door',
      packageName: 'org.freelygiven.bibledoor',
      version: '1.0.2',
      buildNumber: '3',
      buildSignature: '',
    );
    await capture('about-tablet', const Size(900, 1400), about: true);
    await capture('about-phone', const Size(390, 844), about: true);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await c.save();
      c.dispose();
      c.repository.dispose();
      await folder.delete(recursive: true);
    });
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
}
