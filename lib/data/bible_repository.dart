import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/bible.dart';
import 'bible_parser.dart';

class BibleRepository {
  BibleRepository(this.root, {http.Client? client, Uri? server})
    : client = client ?? http.Client(),
      server = server ?? Uri.parse('https://Freely-Given.org/Links/');
  final Directory root;
  final http.Client client;
  final Uri server;
  final Map<String, BookContent> _books = {};
  final Map<String, Future<BookContent>> _pending = {};
  static const maxFileBytes = 32 * 1024 * 1024;
  static const maxPackageBytes = 160 * 1024 * 1024;

  Directory directory(String key) {
    if (!isValidKey(key) && !RegExp(r'^local-[a-f0-9]{16}$').hasMatch(key)) {
      throw const BibleException('Invalid Bible key.');
    }
    return Directory('${root.path}/bibles/$key');
  }

  Future<void> initialize() async {
    await root.create(recursive: true);
    final bibles = Directory('${root.path}/bibles');
    if (!await bibles.exists()) return;
    await for (final entry in bibles.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final name = entry.path.split('/').last;
      if (name.startsWith('.backup-')) {
        final target = directory(name.substring('.backup-'.length));
        if (!await target.exists()) {
          await entry.rename(target.path);
        } else {
          await entry.delete(recursive: true);
        }
      }
    }
  }

  Future<List<BibleVersion>> installed() async {
    final folder = Directory('${root.path}/bibles');
    if (!await folder.exists()) return [];
    final versions = <BibleVersion>[];
    await for (final entry in folder.list(followLinks: false)) {
      if (entry is! Directory || entry.path.split('/').last.startsWith('.')) {
        continue;
      }
      final key = entry.path.split('/').last;
      try {
        versions.add(await _metadata(key, entry));
      } on Object {
        /* Incomplete folders never appear as usable Bibles. */
      }
    }
    return versions..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<BibleVersion> _metadata(String key, Directory folder) async {
    final header = BibleVersion.validateHeader(
      decodeBibleJson(
        await File('${folder.path}/BDHeader.json').readAsString(),
      ),
    );
    final raw = decodeBibleJson(
      await File('${folder.path}/BDBookNames.1.json').readAsString(),
    );
    if (raw is! List || raw.isEmpty || raw.length > 200) {
      throw const BibleException('This Bible has no valid book list.');
    }
    final books = raw.map(BibleBook.fromJson).toList();
    if (books.map((b) => b.code).toSet().length != books.length) {
      throw const BibleException('The Bible book list contains duplicates.');
    }
    final file = File('${folder.path}/BDDivisionNames.1.json');
    final divisions = await file.exists()
        ? decodeBibleJson(await file.readAsString())
        : <String>[];
    return BibleVersion(
      key: key,
      header: header,
      books: books,
      divisions: divisions is List
          ? divisions.map((v) => v.toString()).toList()
          : [],
    );
  }

  Future<Uint8List?> _download(Uri uri, {bool optional = false}) async {
    try {
      for (var redirects = 0; redirects <= 4; redirects++) {
        if (uri.scheme != 'https' ||
            uri.host.toLowerCase() != server.host.toLowerCase()) {
          throw const BibleException(
            'The server redirected to an untrusted address.',
          );
        }
        final request = http.Request('GET', uri)..followRedirects = false;
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 25));
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          await response.stream.drain<void>().timeout(
            const Duration(seconds: 25),
          );
          final location = response.headers['location'];
          if (location == null) break;
          uri = uri.resolve(location);
          continue;
        }
        if (response.statusCode == 404 && optional) {
          await response.stream.drain<void>().timeout(
            const Duration(seconds: 25),
          );
          return null;
        }
        if (response.statusCode != 200) {
          await response.stream.drain<void>().timeout(
            const Duration(seconds: 25),
          );
          throw BibleException(
            response.statusCode == 404
                ? 'This key or book was not found. Check the key with its publisher.'
                : 'The Bible server is unavailable (${response.statusCode}). Please try again.',
          );
        }
        if ((response.contentLength ?? 0) > maxFileBytes) {
          throw const BibleException('This Bible file is too large.');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 25),
        )) {
          if (bytes.length + chunk.length > maxFileBytes) {
            throw const BibleException('This Bible file is too large.');
          }
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      }
      throw const BibleException(
        'The Bible server returned too many redirects.',
      );
    } on SocketException {
      throw const BibleException(
        'Could not connect. Check your connection, or read a downloaded book.',
      );
    } on http.ClientException {
      throw const BibleException(
        'Could not connect securely to the Bible server. Please try again.',
      );
    } on TimeoutException {
      throw const BibleException(
        'The download timed out. Please try again when your connection improves.',
      );
    }
  }

  Future<void> _write(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.part');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  }

  Future<Map<String, dynamic>> _checksums(Directory folder) async {
    final file = File('${folder.path}/BDChecksums.1.json');
    if (!await file.exists()) return {};
    final result = decodeBibleJson(await file.readAsString());
    if (result is! Map<String, dynamic>) {
      throw const BibleException('The checksum list is invalid.');
    }
    return result;
  }

  void _verify(String path, List<int> bytes, Map<String, dynamic> checksums) {
    final expected = checksums[path] ?? checksums[path.split('/').last];
    if (expected != null &&
        (expected is! String ||
            md5.convert(bytes).toString() != expected.toLowerCase())) {
      throw const BibleException(
        'A Bible file failed its integrity check. Please download it again.',
      );
    }
  }

  Future<BibleVersion> install(String input, {bool refresh = false}) async {
    final key = normalizeKey(input);
    if (!isValidKey(key)) {
      throw const BibleException('Enter a key such as webbe-123-456.');
    }
    final target = directory(key);
    final exists = await target.exists();
    if (exists && !refresh) return _metadata(key, target);
    final previousBooks = exists
        ? await cachedBooks(await _metadata(key, target))
        : <String>{};
    final stage = Directory('${root.path}/bibles/.pending-$key');
    if (await stage.exists()) await stage.delete(recursive: true);
    await stage.create(recursive: true);
    try {
      for (final name in [
        'BDHeader.json',
        'BDBookNames.1.json',
        'BDDivisionNames.1.json',
        'BDChecksums.1.json',
      ]) {
        final bytes = await _download(
          server.resolve('$key/$name'),
          optional:
              name == 'BDChecksums.1.json' || name == 'BDDivisionNames.1.json',
        );
        if (bytes != null) await _write(File('${stage.path}/$name'), bytes);
      }
      final checksums = await _checksums(stage);
      for (final name in [
        'BDHeader.json',
        'BDBookNames.1.json',
        'BDDivisionNames.1.json',
      ]) {
        final file = File('${stage.path}/$name');
        if (await file.exists()) {
          _verify(name, await file.readAsBytes(), checksums);
        }
      }
      final version = await _metadata(key, stage);
      final initial =
          version.books.where((b) => b.code == 'TIT').firstOrNull ??
          version.books.where((b) => b.chapters > 0).firstOrNull ??
          version.books.first;
      await _fetchBook(version, initial, stage);
      for (final book in version.books.where(
        (b) => previousBooks.contains(b.code) && b.code != initial.code,
      )) {
        await _fetchBook(version, book, stage);
      }
      final backup = Directory('${root.path}/bibles/.backup-$key');
      if (exists) {
        if (await backup.exists()) await backup.delete(recursive: true);
        await target.rename(backup.path);
      }
      try {
        await stage.rename(target.path);
      } on Object {
        if (exists) await backup.rename(target.path);
        rethrow;
      }
      if (await backup.exists()) await backup.delete(recursive: true);
      _books.removeWhere((id, _) => id.startsWith('$key/'));
      return version;
    } finally {
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  Future<BookContent> book(BibleVersion version, String code) {
    final id = '${version.key}/$code';
    if (_books.containsKey(id)) return Future.value(_books[id]);
    return _pending.putIfAbsent(id, () async {
      try {
        final result = await _fetchBook(
          version,
          version.book(code),
          directory(version.key),
        );
        // Keep memory bounded while a whole Bible is downloaded or searched.
        if (_books.length >= 8) _books.remove(_books.keys.first);
        _books[id] = result;
        return result;
      } finally {
        _pending.remove(id);
      }
    });
  }

  Future<BookContent> _fetchBook(
    BibleVersion version,
    BibleBook book,
    Directory folder,
  ) async {
    final textPath = 'ByBook.1.BDTXT/${book.code}.1.bd.txt';
    final indexPath = 'ByBook.1.BDTXT/${book.code}.1.bd.idx';
    final jsonPath = 'ByBook.1.JSON/${book.code}.1.json';
    final textFile = File('${folder.path}/$textPath'),
        indexFile = File('${folder.path}/$indexPath');
    final jsonFile = File('${folder.path}/$jsonPath');
    if (await textFile.exists() && await indexFile.exists()) {
      return BibleParser.text(
        book,
        await textFile.readAsString(),
        decodeBibleJson(await indexFile.readAsString()),
      );
    }
    if (await jsonFile.exists()) {
      return BibleParser.json(
        book,
        decodeBibleJson(await jsonFile.readAsString()),
        hasHeadings: version.hasHeadings,
      );
    }
    if (version.key.startsWith('local-')) {
      throw const BibleException(
        'This book is not in the imported package. Ask for a complete package.',
      );
    }
    final checksums = await _checksums(folder);
    final text = await _download(
      server.resolve('${version.key}/$textPath'),
      optional: true,
    );
    final index = text == null
        ? null
        : await _download(
            server.resolve('${version.key}/$indexPath'),
            optional: true,
          );
    if (text != null && index != null) {
      _verify(textPath, text, checksums);
      _verify(indexPath, index, checksums);
      final parsed = BibleParser.text(
        book,
        utf8.decode(text),
        decodeBibleJson(utf8.decode(index)),
      );
      await _write(textFile, text);
      await _write(indexFile, index);
      return parsed;
    }
    final json = (await _download(server.resolve('${version.key}/$jsonPath')))!;
    _verify(jsonPath, json, checksums);
    final parsed = BibleParser.json(
      book,
      decodeBibleJson(utf8.decode(json)),
      hasHeadings: version.hasHeadings,
    );
    await _write(jsonFile, json);
    return parsed;
  }

  Future<Set<String>> cachedBooks(BibleVersion version) async {
    final folder = directory(version.key);
    final result = <String>{};
    for (final book in version.books) {
      if ((await File('${folder.path}/ByBook.1.BDTXT/${book.code}.1.bd.txt')
                  .exists() &&
              await File('${folder.path}/ByBook.1.BDTXT/${book.code}.1.bd.idx')
                  .exists()) ||
          await File('${folder.path}/ByBook.1.JSON/${book.code}.1.json')
              .exists()) {
        result.add(book.code);
      }
    }
    return result;
  }

  Future<void> remove(BibleVersion version) async {
    final folder = directory(version.key);
    if (await folder.exists()) await folder.delete(recursive: true);
    _books.removeWhere((key, _) => key.startsWith('${version.key}/'));
  }

  /// Only known filenames are ever read from an archive; nothing is extracted
  /// using untrusted paths. Inspect declared sizes before decompression.
  Future<BibleVersion> importPackage(Uint8List bytes) async {
    if (bytes.length > maxFileBytes) {
      throw const BibleException('Choose a ZIP smaller than 32 MB.');
    }
    // Validate the central directory before ZipDecoder can expand even a symlink.
    final central = ZipDirectory()..read(InputMemoryStream(bytes));
    final names = <String>{};
    var declaredBytes = 0;
    if (central.fileHeaders.length > 1000) {
      throw const BibleException('This ZIP contains too many files.');
    }
    for (final entry in central.fileHeaders) {
      declaredBytes += entry.uncompressedSize;
      final file = entry.file;
      if (!names.add(entry.filename) ||
          entry.uncompressedSize > maxFileBytes ||
          declaredBytes > maxPackageBytes ||
          entry.filename.contains('..') ||
          entry.filename.startsWith('/') ||
          entry.filename.contains('\\') ||
          (entry.externalFileAttributes >> 16) & 0xf000 == 0xa000 ||
          file == null ||
          file.filename != entry.filename ||
          file.uncompressedSize != entry.uncompressedSize) {
        throw const BibleException(
          'This ZIP contains duplicate, unsafe, or oversized files.',
        );
      }
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.length > 1000) {
      throw const BibleException('This ZIP contains too many files.');
    }
    var total = 0;
    for (final entry in archive) {
      total += entry.size;
      if (entry.size > maxFileBytes ||
          total > maxPackageBytes ||
          entry.isSymbolicLink ||
          entry.name.contains('..') ||
          entry.name.startsWith('/') ||
          entry.name.contains('\\')) {
        throw const BibleException(
          'This ZIP contains unsafe paths or oversized files.',
        );
      }
    }
    final headers = archive.files
        .where(
          (f) =>
              f.isFile &&
              (f.name == 'BDHeader.json' || f.name.endsWith('/BDHeader.json')),
        )
        .toList();
    if (headers.length != 1) {
      throw const BibleException(
        'Choose a ZIP containing exactly one Bible Door export, including BDHeader.json.',
      );
    }
    final prefix = headers.single.name.substring(
      0,
      headers.single.name.length - 'BDHeader.json'.length,
    );
    final key = 'local-${sha256.convert(bytes).toString().substring(0, 16)}';
    final target = directory(key);
    if (await target.exists()) return _metadata(key, target);
    final stage = Directory('${root.path}/bibles/.pending-$key');
    if (await stage.exists()) await stage.delete(recursive: true);
    await stage.create(recursive: true);
    try {
      final seen = <String>{};
      for (final file in archive) {
        if (!file.isFile || !file.name.startsWith(prefix)) continue;
        final path = file.name.substring(prefix.length);
        if (!RegExp(
          r'^(BDHeader\.json|BD(?:BookNames|DivisionNames|Checksums)\.1\.json|ByBook\.1\.BDTXT/[A-Z0-9]{3}\.1\.bd\.(txt|idx)|ByBook\.1\.JSON/[A-Z0-9]{3}\.1\.json)$',
        ).hasMatch(path)) {
          continue;
        }
        if (!seen.add(path)) {
          throw const BibleException('This ZIP has duplicate Bible files.');
        }
        final content = file.content;
        if (content.length != file.size || getCrc32(content) != file.crc32) {
          throw const BibleException('A file in this ZIP is damaged.');
        }
        await _write(File('${stage.path}/$path'), content);
      }
      final checksums = await _checksums(stage);
      for (final path in seen) {
        if (path != 'BDChecksums.1.json') {
          _verify(
            path,
            await File('${stage.path}/$path').readAsBytes(),
            checksums,
          );
        }
      }
      final version = await _metadata(key, stage);
      var readable = 0;
      for (final b in version.books) {
        if (seen.contains('ByBook.1.BDTXT/${b.code}.1.bd.txt') ||
            seen.contains('ByBook.1.JSON/${b.code}.1.json')) {
          await _fetchBook(version, b, stage);
          readable++;
        }
      }
      if (readable == 0) {
        throw const BibleException(
          'This ZIP contains no readable books. Include BDTXT text/index pairs or ByBook JSON files.',
        );
      }
      await stage.rename(target.path);
      return version;
    } finally {
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  Future<Uint8List> exportPackage(BibleVersion version) async {
    if (!version.shareable) {
      throw const BibleException(
        'The publisher has not permitted sharing this Bible.',
      );
    }
    final archive = Archive();
    final folder = directory(version.key);
    await for (final entry in folder.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is! File || entry.path.endsWith('.part')) continue;
      final path = entry.path.substring(folder.path.length + 1);
      final bytes = await entry.readAsBytes();
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }
    // Key codes are intentionally absent from exports, including private links.
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<Map<String, dynamic>> readState() async {
    final file = File('${root.path}/state.json');
    if (!await file.exists()) return {};
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on Object {
      throw const BibleException(
        'Saved preferences could not be read. Your downloaded Bibles are still available.',
      );
    }
  }

  Future<void> writeState(Map<String, dynamic> state) =>
      _write(File('${root.path}/state.json'), utf8.encode(jsonEncode(state)));
  void dispose() => client.close();
}
