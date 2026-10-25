import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../data/reference_parser.dart';
import '../models/bible.dart';

Future<void> showPassagePicker(
  BuildContext context,
  AppController controller, {
  bool second = false,
}) async {
  final passage = await showModalBottomSheet<Passage>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _PassagePicker(controller: controller, second: second),
  );
  if (passage != null) await controller.navigate(passage, second: second);
}

class _PassagePicker extends StatefulWidget {
  const _PassagePicker({required this.controller, required this.second});
  final AppController controller;
  final bool second;
  @override
  State<_PassagePicker> createState() => _PassagePickerState();
}

class _PassagePickerState extends State<_PassagePicker> {
  final reference = TextEditingController();
  String? message;
  BibleBook? selected;
  BookContent? content;
  bool loading = false;
  int generation = 0;
  AppController get c => widget.controller;
  BibleVersion get version =>
      (widget.second ? c.secondary : c.primary).version!;
  @override
  void dispose() {
    reference.dispose();
    super.dispose();
  }

  Future<void> choose(BibleBook book) async {
    final request = ++generation;
    setState(() {
      selected = book;
      content = null;
      loading = true;
      message = null;
    });
    try {
      final result = await c.repository.book(version, book.code);
      c.cached[version.key] = await c.repository.cachedBooks(version);
      if (mounted && request == generation) setState(() => content = result);
    } on Object catch (e) {
      if (mounted && request == generation) {
        setState(
          () => message = e is BibleException
              ? e.message
              : 'Could not load this book.',
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  void go() {
    final result = parseReference(reference.text, version);
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      setState(
        () => message =
            'Use a book name from this Bible, followed by chapter and verse, for example “${version.books.where((b) => b.chapters > 0).firstOrNull?.name ?? 'Titus'} 1:1”.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .84,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (selected != null)
                IconButton(
                  tooltip: 'All books',
                  onPressed: () {
                    generation++;
                    setState(() {
                      selected = null;
                      content = null;
                      message = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Text(
                  selected?.name ?? 'Find a passage',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reference,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => go(),
            decoration: InputDecoration(
              labelText: 'Book chapter:verse',
              hintText: 'Paste or type a reference',
              suffixIcon: IconButton(
                tooltip: 'Go to reference',
                onPressed: go,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: selected == null
                ? _books()
                : loading
                ? const Center(child: CircularProgressIndicator())
                : content == null
                ? Center(
                    child: FilledButton(
                      onPressed: () => choose(selected!),
                      child: const Text('Try again'),
                    ),
                  )
                : ListView(
                    children: [
                      if (selected!.chapters > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(
                              selected!.chapters,
                              (i) => OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(52, 48),
                                  padding: const EdgeInsets.all(8),
                                ),
                                onPressed: () => Navigator.pop(
                                  context,
                                  Passage(selected!.code, i + 1, 1),
                                ),
                                child: Text('${i + 1}'),
                              ),
                            ),
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'SECTIONS',
                          style: TextStyle(letterSpacing: 2, fontSize: 11),
                        ),
                      ),
                      ...content!.sections.map(
                        (s) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.title),
                          subtitle: Text(
                            s.start.chapter < 1
                                ? 'Introduction'
                                : '${s.start.chapter}:${s.start.verse} – ${s.end.chapter}:${s.end.verse}',
                          ),
                          onTap: () => Navigator.pop(context, s.start),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
  Widget _books() {
    final recent = c.recent
        .where((s) => s.version == version.key)
        .take(3)
        .toList();
    return ListView(
      children: [
        if (recent.isNotEmpty) ...[
          const Text(
            'RECENT BOOKS',
            style: TextStyle(letterSpacing: 2, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: recent
                .map(
                  (s) => ActionChip(
                    label: Text(version.book(s.passage.book).name),
                    onPressed: () => choose(version.book(s.passage.book)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
        ...version.books.asMap().entries.expand((entry) {
          final book = entry.value;
          final divisionChanged =
              entry.key == 0 ||
              version.books[entry.key - 1].division != book.division;
          return <Widget>[
            if (divisionChanged &&
                book.division >= 0 &&
                book.division < version.divisions.length)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  version.divisions[book.division].toUpperCase(),
                  style: TextStyle(
                    letterSpacing: 1.4,
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(book.name),
              subtitle: Text(book.title),
              trailing: Icon(
                c.cached[version.key]?.contains(book.code) == true
                    ? Icons.offline_pin_outlined
                    : Icons.cloud_download_outlined,
                size: 20,
              ),
              onTap: () => choose(book),
            ),
          ];
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}
