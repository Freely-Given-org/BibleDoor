import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../data/reference_parser.dart';
import '../models/bible.dart';
import 'theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.onRead,
  });
  final AppController controller;
  final VoidCallback onRead;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final query = TextEditingController();
  List<SearchHit> results = [];
  bool searching = false, searched = false;
  String? error, searchedKey;
  int generation = 0;
  AppController get c => widget.controller;
  @override
  void dispose() {
    generation++;
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final version = c.primary.version;
    if (version == null) return;
    final reference = parseReference(query.text, version);
    if (reference != null) {
      await c.navigate(reference);
      widget.onRead();
      return;
    }
    if (query.text.trim().length < 2) {
      setState(
        () => error = 'Enter at least two characters, or a passage reference.',
      );
      return;
    }
    final request = ++generation;
    setState(() {
      searching = true;
      error = null;
      results = [];
      searched = true;
      searchedKey = version.key;
    });
    try {
      final found = await c.search(
        query.text,
        version,
        cancelled: () => request != generation || !mounted,
      );
      if (mounted && request == generation) setState(() => results = found);
    } on Object {
      if (mounted && request == generation) {
        setState(
          () => error = 'Some downloaded text could not be searched. Try opening the affected book.',
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => searching = false);
    }
  }

  Future<void> open(SavedPassage saved) async {
    final version = c.versions.where((v) => v.key == saved.version).firstOrNull;
    if (version == null) return;
    await c.openVersion(version, passage: saved.passage);
    widget.onRead();
  }

  @override
  Widget build(BuildContext context) {
    final version = c.primary.version;
    final current = searched && searchedKey == version?.key;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 950),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const PageHeading(
              'Find & return',
              'Words worth finding.',
              'Search your downloaded text, or return to a saved passage.',
            ),
            if (version == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Add a Bible in your Library to start searching.',
                  ),
                ),
              )
            else ...[
              TextField(
                controller: query,
                onSubmitted: (_) => search(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search ${version.abbreviation}',
                  hintText: 'A word, phrase, or book chapter:verse',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: search,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Searches ${c.cached[version.key]?.length ?? 0} downloaded books. Download all books from the Library for a complete search.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (searching)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: LinearProgressIndicator(),
                ),
              if (current && !searching) ...[
                const SizedBox(height: 24),
                Text(
                  results.length == 200
                      ? 'First 200 matching sections · refine your search'
                      : '${results.length} matching sections',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No matches in downloaded books. Try another phrase or download more books.',
                    ),
                  ),
                ...results.map(
                  (hit) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(18),
                        title: Text(
                          hit.section.start.label(hit.version),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            hit.snippet,
                            style: const TextStyle(height: 1.6),
                          ),
                        ),
                        onTap: () async {
                          await c.openVersion(
                            hit.version,
                            passage: hit.section.start,
                          );
                          widget.onRead();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 32),
            const Text(
              'Bookmarks',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (c.bookmarks.isEmpty)
              const Text(
                'Save a section with the bookmark button while reading. It will be waiting here.',
                style: TextStyle(height: 1.6),
              ),
            ...c.bookmarks.map(
              (saved) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: Text(saved.title),
                    subtitle: Text(
                      '${saved.passage.label(c.versions.firstWhere((v) => v.key == saved.version))} · ${c.versions.firstWhere((v) => v.key == saved.version).abbreviation}',
                    ),
                    onTap: () => open(saved),
                    trailing: IconButton(
                      tooltip: 'Remove bookmark',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        c.bookmarks.remove(saved);
                        c.preferencesChanged();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Recently read',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (c.recent.isEmpty)
              const Text('Your recent books will appear here.'),
            ...c.recent
                .take(6)
                .map(
                  (saved) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text(
                      saved.passage.label(
                        c.versions.firstWhere((v) => v.key == saved.version),
                      ),
                    ),
                    subtitle: Text(saved.title),
                    onTap: () => open(saved),
                  ),
                ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
