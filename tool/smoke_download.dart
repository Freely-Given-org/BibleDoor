// Explicit online smoke check. Uses only a public key and temporary storage.
import 'dart:io';

import 'package:bibledoor/data/bible_repository.dart';

Future<void> main(List<String> args) async {
  final folder = await Directory.systemTemp.createTemp('bibledoor-online-');
  final repo = BibleRepository(folder);
  try {
    final bible = await repo.install(args.firstOrNull ?? 'webbe-123-456');
    final book = await repo.book(bible, 'TIT');
    stdout.writeln(
      '${bible.abbreviation}: ${bible.books.length} books; Titus: ${book.sections.length} sections. HTTPS download and parsing passed.',
    );
  } finally {
    repo.dispose();
    await folder.delete(recursive: true);
  }
}
