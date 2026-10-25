import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/bible.dart';

/// Publication and local-download information shown from the Library.
class BibleDetails extends StatelessWidget {
  const BibleDetails({
    super.key,
    required this.version,
    required this.offlineBooks,
  });

  final BibleVersion version;
  final int offlineBooks;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${version.abbreviation} · $offlineBooks of ${version.books.length} books available offline',
        style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5),
      ),
      const SizedBox(height: 12),
      Text(
        '${version.key.startsWith('local-') ? 'Imported from a Bible Door ZIP' : 'Downloaded from Freely-Given.org'}\n'
        'Bible Door export date: ${version.date}\n'
        '${version.hasHeadings ? 'Includes section headings' : 'Uses chapter-based reading'}\n'
        '${version.shareable ? 'Publisher permits package sharing.' : 'Publisher has not permitted package sharing.'}',
        style: const TextStyle(height: 1.6),
      ),
      const SizedBox(height: 12),
      Text(
        'Translation notices and copyright information may be included in the preface and book introductions.',
        style: TextStyle(
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

Future<void> confirmRemoveBible(
  BuildContext context,
  AppController controller,
  BibleVersion version,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove this Bible?'),
      content: Text(
        'Remove ${version.name}, its downloaded books, and its bookmarks from this device?'
        '${version.key.startsWith('local-') ? '\n\nKeep the original ZIP if you want to import it again.' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep Bible'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  if (controller.busy ||
      controller.primary.loading ||
      controller.secondary.loading) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please wait for the current book operation to finish.'),
      ),
    );
    return;
  }
  await controller.remove(version);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        controller.error ?? '${version.name} removed from this device.',
      ),
    ),
  );
}
