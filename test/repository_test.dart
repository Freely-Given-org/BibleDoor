import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bibledoor/app_controller.dart';
import 'package:bibledoor/data/bible_repository.dart';
import 'package:bibledoor/models/bible.dart';

Map<String, List<int>> files({bool shareable = true}) => {
  'BDHeader.json': utf8.encode(
    jsonEncode({
      'Data format version': 1,
      'Version name': 'Test Bible',
      'Version abbreviation': 'TEST',
      'Shareable': shareable,
    }),
  ),
  'BDBookNames.1.json': utf8.encode(
    jsonEncode([
      ['TIT', 'Tit', 'Titus', 'Titus', 3, 4, 0],
    ]),
  ),
  'BDDivisionNames.1.json': utf8.encode('["New Testament"]'),
  'ByBook.1.BDTXT/TIT.1.bd.txt': File('test/fixtures/TIT.1.bd.txt')
      .readAsBytesSync(),
  'ByBook.1.BDTXT/TIT.1.bd.idx': File('test/fixtures/TIT.1.bd.idx')
      .readAsBytesSync(),
};
Uint8List zip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  late Directory folder;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('bibledoor-test-');
  });
  tearDown(() async {
    await folder.delete(recursive: true);
  });
  test(
    'install validates, caches, and reopens offline without any HTTP',
    () async {
      final source = files();
      var calls = 0;
      final repo = BibleRepository(
        folder,
        client: MockClient((request) async {
          calls++;
          expect(request.url.scheme, 'https');
          final name = request.url.pathSegments.skip(2).join('/');
          return http.Response.bytes(
            source[name] ?? [],
            source.containsKey(name) ? 200 : 404,
          );
        }),
      );
      final version = await repo.install('TEST-123-456');
      expect((await repo.cachedBooks(version)), {'TIT'});
      expect((await repo.book(version, 'TIT')).sections.length, 4);
      final callsAfterInstall = calls;
      final reopened = BibleRepository(
        folder,
        client: MockClient((_) async => throw StateError('offline')),
      );
      expect((await reopened.installed()).single.name, 'Test Bible');
      expect((await reopened.book(version, 'TIT')).sections.length, 4);
      expect(calls, callsAfterInstall);
      repo.dispose();
      reopened.dispose();
    },
  );
  test('404 text format falls back to legacy JSON', () async {
    final source = files()..removeWhere((key, _) => key.contains('BDTXT'));
    source['ByBook.1.JSON/TIT.1.json'] = File('test/fixtures/TIT.1.json')
        .readAsBytesSync();
    final repo = BibleRepository(
      folder,
      client: MockClient((request) async {
        final name = request.url.pathSegments.skip(2).join('/');
        return http.Response.bytes(
          source[name] ?? [],
          source.containsKey(name) ? 200 : 404,
        );
      }),
    );
    final version = await repo.install('test-123-456');
    expect((await repo.book(version, 'TIT')).sections.length, 4);
    repo.dispose();
  });
  test('checksum mismatch leaves no installed or partial Bible', () async {
    final source = files();
    source['BDChecksums.1.json'] = utf8.encode(
      jsonEncode({'TIT.1.bd.txt': '0' * 32}),
    );
    final repo = BibleRepository(
      folder,
      client: MockClient((request) async {
        final name = request.url.pathSegments.skip(2).join('/');
        return http.Response.bytes(
          source[name] ?? [],
          source.containsKey(name) ? 200 : 404,
        );
      }),
    );
    await expectLater(
      repo.install('test-123-456'),
      throwsA(isA<BibleException>()),
    );
    expect(await repo.installed(), isEmpty);
    expect(await Directory('${folder.path}/bibles').list().toList(), isEmpty);
    repo.dispose();
  });
  test('cross-host and plaintext redirects are refused', () async {
    final repo = BibleRepository(
      folder,
      client: MockClient(
        (_) async => http.Response(
          '',
          302,
          headers: {'location': 'http://evil.example/BDHeader.json'},
        ),
      ),
    );
    await expectLater(
      repo.install('test-123-456'),
      throwsA(isA<BibleException>()),
    );
    repo.dispose();
  });
  test(
    'import/export roundtrip, Unicode and checksums preserved, no private key',
    () async {
      final source = files();
      source['BDChecksums.1.json'] = utf8.encode(
        jsonEncode({
          for (final e in source.entries)
            e.key: md5.convert(e.value).toString(),
        }),
      );
      final repo = BibleRepository(folder);
      final imported = await repo.importPackage(
        zip(source.map((k, v) => MapEntry('MyBible/$k', v))),
      );
      expect(imported.key, startsWith('local-'));
      expect(
        (await repo.book(imported, 'TIT')).sections[1].text,
        contains('Paul, a servant of God'),
      );
      final exported = await repo.exportPackage(imported);
      final archive = ZipDecoder().decodeBytes(exported);
      expect(archive.files.any((f) => f.name.contains(imported.key)), isFalse);
      final another = await repo.importPackage(exported);
      expect(another.name, imported.name);
      repo.dispose();
    },
  );
  test(
    'unsafe archives and incomplete packages are rejected before installation',
    () async {
      final repo = BibleRepository(folder);
      await expectLater(
        repo.importPackage(
          zip({
            ...files(),
            '../escape.txt': [1],
          }),
        ),
        throwsA(isA<BibleException>()),
      );
      await expectLater(
        repo.importPackage(zip(files()..remove('ByBook.1.BDTXT/TIT.1.bd.idx'))),
        throwsA(isA<BibleException>()),
      );
      expect(await repo.installed(), isEmpty);
      expect(await File('${folder.parent.path}/escape.txt').exists(), isFalse);
      repo.dispose();
    },
  );
  test('publisher sharing restriction is enforced in the data layer', () async {
    final repo = BibleRepository(folder);
    final version = await repo.importPackage(zip(files(shareable: false)));
    await expectLater(
      repo.exportPackage(version),
      throwsA(isA<BibleException>()),
    );
    repo.dispose();
  });
  test('bookmarks, settings, compare and passage survive restart; removal clears saved data', () async {
    final repo = BibleRepository(folder);
    final version = await repo.importPackage(zip(files()));
    final c = AppController(repo);
    await c.initialize();
    await c.navigate(const Passage('TIT', 2, 1));
    c.toggleBookmark();
    c.fontSize = 27;
    c.showNumbers = true;
    await c.setCompare(version);
    await c.save();
    final restored = AppController(repo);
    await restored.initialize();
    expect(restored.primary.section!.start.chapter, 2);
    expect(restored.bookmarks.single.passage.chapter, 2);
    expect(restored.fontSize, 27);
    expect(restored.showNumbers, isTrue);
    expect(restored.compare, isTrue);
    final hits = await restored.search('grace', version);
    expect(hits, isNotEmpty);
    await restored.remove(version);
    expect(restored.bookmarks, isEmpty);
    expect(restored.primary.version, isNull);
    expect(await repo.installed(), isEmpty);
    await c.save();
    await restored.save();
    c.dispose();
    restored.dispose();
    repo.dispose();
  });
  test(
    'failed update keeps the old Bible; valid update replaces cached text',
    () async {
      final source = files();
      final repo = BibleRepository(
        folder,
        client: MockClient((request) async {
          final name = request.url.pathSegments.skip(2).join('/');
          return http.Response.bytes(
            source[name] ?? [],
            source.containsKey(name) ? 200 : 404,
          );
        }),
      );
      final old = await repo.install('test-123-456');
      await repo.book(old, 'TIT');
      source['BDChecksums.1.json'] = utf8.encode(
        jsonEncode({'TIT.1.bd.txt': '0' * 32}),
      );
      await expectLater(
        repo.install(old.key, refresh: true),
        throwsA(isA<BibleException>()),
      );
      expect((await repo.installed()).single.name, 'Test Bible');
      expect((await repo.book(old, 'TIT')).sections[1].text, contains('Paul,'));
      source.remove('BDChecksums.1.json');
      source['ByBook.1.BDTXT/TIT.1.bd.txt'] = utf8.encode(
        utf8
            .decode(source['ByBook.1.BDTXT/TIT.1.bd.txt']!)
            .replaceAll('Paul', 'Saul'),
      );
      final updated = await repo.install(old.key, refresh: true);
      expect(
        (await repo.book(updated, 'TIT')).sections[1].text,
        contains('Saul,'),
      );
      repo.dispose();
    },
  );

  test('linked reference navigation works from either reading pane', () async {
    final repo = BibleRepository(folder);
    final version = await repo.importPackage(zip(files()));
    final c = AppController(repo);
    await c.initialize();
    await c.setCompare(version);
    await c.navigate(const Passage('TIT', 3, 1), second: true);
    expect(c.primary.section!.start.chapter, 3);
    expect(c.secondary.section!.start.chapter, 3);
    c.linked = false;
    await c.navigate(const Passage('TIT', 2, 1), second: true);
    expect(c.primary.section!.start.chapter, 3);
    expect(c.secondary.section!.start.chapter, 2);
    await c.save();
    c.dispose();
    repo.dispose();
  });
}
