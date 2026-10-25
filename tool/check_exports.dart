// Run with a local BOS_BibleDoor_Export folder as its only argument.
import 'dart:io';

import 'package:bibledoor/data/bible_parser.dart';
import 'package:bibledoor/models/bible.dart';

void main(List<String> args) {
  if (args.length != 1) {
    throw ArgumentError('Pass a Bible Door export directory.');
  }
  final root = args.single;
  final books = (decodeBibleJson(
    File('$root/BDBookNames.1.json').readAsStringSync(),
  ) as List).map(BibleBook.fromJson);
  var total = 0;
  for (final book in books) {
    final text = File('$root/ByBook.1.BDTXT/${book.code}.1.bd.txt');
    final index = File('$root/ByBook.1.BDTXT/${book.code}.1.bd.idx');
    if (text.existsSync() && index.existsSync()) {
      final parsed = BibleParser.text(
        book,
        text.readAsStringSync(),
        decodeBibleJson(index.readAsStringSync()),
      );
      total += parsed.sections.length;
    } else {
      final json = File('$root/ByBook.1.JSON/${book.code}.1.json');
      if (json.existsSync()) {
        total += BibleParser.json(
          book,
          decodeBibleJson(json.readAsStringSync()),
          hasHeadings: true,
        ).sections.length;
      }
    }
  }
  stdout.writeln('Parsed ${books.length} books and $total sections.');
}
