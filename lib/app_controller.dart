import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'data/bible_repository.dart';
import 'models/bible.dart';

class ReaderPane {
  BibleVersion? version;
  BookContent? content;
  int index = 0;
  Passage? target;
  bool loading = false;
  int request = 0;
  String? error;
  BibleSection? get section =>
      content == null ? null : content!.sections[index];
}

class SearchHit {
  const SearchHit(this.version, this.section, this.snippet);
  final BibleVersion version;
  final BibleSection section;
  final String snippet;
}

class AppController extends ChangeNotifier {
  AppController(this.repository);
  final BibleRepository repository;
  final primary = ReaderPane(), secondary = ReaderPane();
  List<BibleVersion> versions = [];
  final Map<String, Set<String>> cached = {};
  List<SavedPassage> bookmarks = [], recent = [];
  final List<Passage> _history = [];
  bool ready = false, busy = false, compare = false, linked = true;
  bool showNumbers = false, redLetters = false, serif = true;
  ThemeMode themeMode = ThemeMode.system;
  double fontSize = 20;
  String? error, status;
  double? progress;
  bool _cancelDownload = false;
  Future<void> _saving = Future.value();

  Future<void> initialize() async {
    await repository.initialize();
    versions = await repository.installed();
    Map<String, dynamic> state = {};
    try {
      state = await repository.readState();
    } on Object catch (e) {
      error = '$e';
    }
    try {
      fontSize = ((state['fontSize'] as num?)?.toDouble() ?? 20).clamp(14, 32);
      showNumbers = state['showNumbers'] == true;
      redLetters = state['redLetters'] == true;
      serif = state['serif'] != false;
      themeMode =
          ThemeMode.values.where((m) => m.name == state['theme']).firstOrNull ??
          ThemeMode.system;
      linked = state['linked'] != false;
      bookmarks = _savedList(state['bookmarks']);
      recent = _savedList(state['recent']);
    } on Object {
      error = 'Some saved preferences could not be restored.';
    }
    for (final version in versions) {
      cached[version.key] = await repository.cachedBooks(version);
    }
    ready = true;
    notifyListeners();
    final version =
        versions.where((v) => v.key == state['primary']).firstOrNull ??
        versions.firstOrNull;
    if (version != null) {
      Passage? passage;
      try {
        if (state['passage'] is Map<String, dynamic>) {
          passage = Passage.fromJson(state['passage']);
        }
      } on Object {
        /* Use first book. */
      }
      await openVersion(version, passage: passage);
    }
    final second = versions
        .where((v) => v.key == state['secondary'])
        .firstOrNull;
    if (state['compare'] == true && second != null) {
      Passage? passage;
      try {
        if (state['secondPassage'] is Map<String, dynamic>) {
          passage = Passage.fromJson(state['secondPassage']);
        }
      } on Object {
        /* Use primary passage. */
      }
      compare = true;
      await openVersion(
        second,
        second: true,
        passage: passage ?? primary.target,
      );
    }
  }

  List<SavedPassage> _savedList(Object? value) => value is List
      ? value
            .whereType<Map<String, dynamic>>()
            .map(SavedPassage.fromJson)
            .where(
              (s) => versions.any(
                (v) =>
                    v.key == s.version &&
                    v.books.any((b) => b.code == s.passage.book),
              ),
            )
            .toList()
      : [];

  Future<void> save() {
    final state = <String, dynamic>{
      'fontSize': fontSize,
      'showNumbers': showNumbers,
      'redLetters': redLetters,
      'serif': serif,
      'theme': themeMode.name,
      'linked': linked,
      'compare': compare,
      'primary': primary.version?.key,
      'secondary': secondary.version?.key,
      'passage': primary.target?.toJson(),
      'secondPassage': secondary.target?.toJson(),
      'bookmarks': bookmarks.map((s) => s.toJson()).toList(),
      'recent': recent.map((s) => s.toJson()).toList(),
    };
    _saving = _saving.then((_) => repository.writeState(state)).catchError((
      Object e,
    ) {
      error =
          'Could not save your reading preferences. Check available storage.';
      notifyListeners();
    });
    return _saving;
  }

  void preferencesChanged() {
    notifyListeners();
    unawaited(save());
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  bool get canGoBack => _history.isNotEmpty;

  Future<bool> operation(Future<void> Function() work) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await work();
      return true;
    } on Object catch (e) {
      error = e is BibleException ? e.message : 'That could not be completed. Check the file, connection, and available storage, then try again.';
      return false;
    } finally {
      busy = false;
      status = null;
      progress = null;
      notifyListeners();
    }
  }

  Future<bool> add(String key) => operation(() async {
    status = 'Opening your Bible…';
    notifyListeners();
    final version = await repository.install(key);
    await _added(version);
  });
  Future<void> refresh(BibleVersion version) => operation(() async {
    status = 'Updating ${version.abbreviation} and its downloaded books…';
    notifyListeners();
    final updated = await repository.install(version.key, refresh: true);
    versions = await repository.installed();
    cached[updated.key] = await repository.cachedBooks(updated);
    bool removedBook(SavedPassage s) =>
        s.version == updated.key &&
        !updated.books.any((b) => b.code == s.passage.book);
    bookmarks.removeWhere(removedBook);
    recent.removeWhere(removedBook);
    if (primary.version?.key == updated.key) {
      await openVersion(updated, passage: primary.target);
    }
    if (secondary.version?.key == updated.key) {
      await openVersion(updated, second: true, passage: secondary.target);
    }
  }).then((_) {});

  Future<bool> import(Uint8List bytes) => operation(() async {
    status = 'Checking your Bible package…';
    notifyListeners();
    final version = await repository.importPackage(bytes);
    await _added(version);
  });
  Future<void> _added(BibleVersion version) async {
    versions = await repository.installed();
    cached[version.key] = await repository.cachedBooks(version);
    await openVersion(version);
  }

  Future<void> openVersion(
    BibleVersion version, {
    bool second = false,
    Passage? passage,
  }) async {
    final pane = second ? secondary : primary;
    if (pane.version?.key != version.key) {
      pane.content = null;
      if (!second) _history.clear();
    }
    pane.version = version;
    final available = cached[version.key] ?? {};
    final first =
        version.books
            .where((b) => b.code == 'TIT' && available.contains(b.code))
            .firstOrNull ??
        version.books
            .where((b) => b.chapters > 0 && available.contains(b.code))
            .firstOrNull ??
        version.books.where((b) => available.contains(b.code)).firstOrNull ??
        version.books.first;
    if (passage == null || !version.books.any((b) => b.code == passage!.book)) {
      passage = Passage(first.code, first.chapters > 0 ? 1 : -1, 1);
    }
    await navigate(passage, second: second, remember: false);
  }

  Future<void> navigate(
    Passage passage, {
    bool second = false,
    bool remember = true,
    bool sync = true,
  }) async {
    final pane = second ? secondary : primary;
    final version = pane.version;
    if (version == null) return;
    final request = ++pane.request;
    if (!version.books.any((b) => b.code == passage.book)) {
      pane.content = null;
      pane.target = passage;
      pane.error = 'This translation does not include that book.';
      pane.loading = false;
      notifyListeners();
      return;
    }
    if (!second &&
        remember &&
        primary.target != null &&
        primary.target != passage) {
      _history.add(primary.target!);
      if (_history.length > 50) _history.removeAt(0);
    }
    pane.target = passage;
    pane.loading = true;
    pane.error = null;
    notifyListeners();
    try {
      final content = await repository.book(version, passage.book);
      if (request != pane.request) return;
      pane.content = content;
      pane.index = content.sectionFor(passage);
      cached[version.key] = await repository.cachedBooks(version);
      if (request != pane.request) return;
      if (!second) {
        recent.removeWhere(
          (s) => s.version == version.key && s.passage.book == passage.book,
        );
        recent.insert(
          0,
          SavedPassage(version.key, passage, pane.section!.title),
        );
        recent = recent.take(12).toList();
      }
    } on Object catch (e) {
      if (request != pane.request) return;
      pane.content = null;
      pane.error = e is BibleException ? e.message : 'This book could not be read. Please check the Bible export or try again.';
    } finally {
      if (request == pane.request) {
        pane.loading = false;
        notifyListeners();
      }
    }
    if (request != pane.request) return;
    if (sync && compare && linked && secondary.version != null) {
      await navigate(passage, second: !second, remember: second, sync: false);
    }
    unawaited(save());
  }

  Future<void> step(int direction, {bool second = false}) async {
    final pane = second ? secondary : primary;
    if (pane.loading || pane.content == null || pane.version == null) return;
    final next = pane.index + direction;
    if (next >= 0 && next < pane.content!.sections.length) {
      await navigate(pane.content!.sections[next].start, second: second);
      return;
    }
    final books = pane.version!.books;
    final index =
        books.indexWhere((b) => b.code == pane.content!.code) + direction;
    if (index < 0 || index >= books.length) return;
    final book = books[index];
    await navigate(
      Passage(
        book.code,
        direction < 0 ? book.chapters : 1,
        direction < 0 ? 9999 : 1,
      ),
      second: second,
    );
  }

  Future<void> back() async {
    if (_history.isNotEmpty) {
      await navigate(_history.removeLast(), remember: false);
    }
  }

  Future<void> setCompare(BibleVersion? version) async {
    compare = version != null;
    if (version != null) {
      await openVersion(version, second: true, passage: primary.target);
    }
    preferencesChanged();
  }

  bool get isBookmarked =>
      primary.version != null &&
      primary.section != null &&
      bookmarks.any(
        (s) =>
            s.version == primary.version!.key &&
            s.passage == primary.section!.start,
      );
  void toggleBookmark() {
    if (primary.version == null || primary.section == null) return;
    final version = primary.version!, section = primary.section!;
    if (isBookmarked) {
      bookmarks.removeWhere(
        (s) => s.version == version.key && s.passage == section.start,
      );
    } else {
      bookmarks.insert(
        0,
        SavedPassage(version.key, section.start, section.title),
      );
    }
    preferencesChanged();
  }

  Future<void> downloadAll(BibleVersion version) => operation(() async {
    _cancelDownload = false;
    for (var i = 0; i < version.books.length; i++) {
      if (_cancelDownload) break;
      final book = version.books[i];
      status = 'Downloading ${book.name} · ${i + 1} of ${version.books.length}';
      progress = i / version.books.length;
      notifyListeners();
      await repository.book(version, book.code);
      cached[version.key] = await repository.cachedBooks(version);
      notifyListeners();
    }
  });
  void cancelDownload() {
    _cancelDownload = true;
    status = 'Stopping after the current book…';
    notifyListeners();
  }

  Future<void> remove(BibleVersion version) => operation(() async {
    await repository.remove(version);
    versions.removeWhere((v) => v.key == version.key);
    cached.remove(version.key);
    bookmarks.removeWhere((s) => s.version == version.key);
    recent.removeWhere((s) => s.version == version.key);
    if (secondary.version?.key == version.key) {
      compare = false;
      secondary.version = null;
      secondary.content = null;
      secondary.request++;
    }
    if (primary.version?.key == version.key) {
      primary.version = null;
      primary.content = null;
      primary.target = null;
      primary.request++;
      _history.clear();
      if (versions.isNotEmpty) await openVersion(versions.first);
    }
    await save();
  }).then((_) {});

  Future<List<SearchHit>> search(
    String query,
    BibleVersion version, {
    bool Function()? cancelled,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return [];
    final results = <SearchHit>[];
    for (final book in version.books) {
      if (cancelled?.call() == true) return [];
      if (!(cached[version.key]?.contains(book.code) ?? false)) continue;
      final content = await repository.book(version, book.code);
      for (final section in content.sections) {
        final text = section.text.replaceAll(RegExp(r'\s+'), ' ');
        final index = text.toLowerCase().indexOf(normalized);
        if (index >= 0) {
          final start = (index - 60).clamp(0, text.length);
          final end = (index + normalized.length + 110).clamp(0, text.length);
          results.add(
            SearchHit(
              version,
              section,
              '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}',
            ),
          );
          if (results.length >= 200) return results;
        }
      }
      await Future<void>.delayed(Duration.zero);
    }
    return results;
  }
}
