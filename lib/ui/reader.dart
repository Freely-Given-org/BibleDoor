import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../data/reference_parser.dart';
import '../models/bible.dart';
import 'navigation.dart';
import 'theme.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.controller,
    required this.onLibrary,
  });
  final AppController controller;
  final VoidCallback onLibrary;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final firstScroll = ScrollController(), secondScroll = ScrollController();
  bool syncing = false;
  AppController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    firstScroll.addListener(() => synchronize(firstScroll, secondScroll));
    secondScroll.addListener(() => synchronize(secondScroll, firstScroll));
  }

  void synchronize(ScrollController from, ScrollController to) {
    if (syncing ||
        !c.compare ||
        !c.linked ||
        !from.hasClients ||
        !to.hasClients ||
        from.position.maxScrollExtent <= 0) {
      return;
    }
    syncing = true;
    to.jumpTo(
      (from.offset /
              from.position.maxScrollExtent *
              to.position.maxScrollExtent)
          .clamp(0, to.position.maxScrollExtent),
    );
    syncing = false;
  }

  @override
  void dispose() {
    firstScroll.dispose();
    secondScroll.dispose();
    super.dispose();
  }

  Future<void> compare() async {
    final version = await showModalBottomSheet<BibleVersion>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Read two passages together',
                style: TextStyle(fontSize: 22),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Choose a Bible for the second pane. Linked panes use the same reference and proportional scrolling. Different verse numbering is not mapped.',
              ),
            ),
            ...c.versions.map(
              (v) => ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(v.name),
                subtitle: Text(
                  v.key == c.primary.version?.key
                      ? 'Open another passage in this Bible'
                      : v.abbreviation,
                ),
                onTap: () => Navigator.pop(context, v),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (version != null) await c.setCompare(version);
  }

  @override
  Widget build(BuildContext context) {
    if (c.primary.version == null) return _welcome();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(
            children: [
              const DoorMark(size: 34),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Bible Door',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.5,
                  ),
                ),
              ),
              if (c.canGoBack)
                IconButton(
                  onPressed: c.back,
                  tooltip: 'Previous location',
                  icon: const Icon(Icons.history),
                ),
              IconButton(
                onPressed: c.primary.section == null ? null : c.toggleBookmark,
                tooltip: c.isBookmarked
                    ? 'Remove bookmark'
                    : 'Bookmark section',
                icon: Icon(
                  c.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
              ),
              IconButton(
                onPressed: c.compare ? () => c.setCompare(null) : compare,
                tooltip: c.compare ? 'Close comparison' : 'Compare Bibles',
                icon: Icon(
                  c.compare
                      ? Icons.close_fullscreen
                      : Icons.vertical_split_outlined,
                ),
              ),
            ],
          ),
        ),
        if (c.compare)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    c.linked
                        ? 'References & scrolling linked'
                        : 'Read each pane independently',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    c.linked = !c.linked;
                    if (c.linked && c.primary.target != null) {
                      c.navigate(c.primary.target!, remember: false);
                    }
                    c.preferencesChanged();
                  },
                  icon: Icon(c.linked ? Icons.link : Icons.link_off, size: 18),
                  label: Text(c.linked ? 'Unlink' : 'Link'),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final first = _Pane(
                controller: c,
                pane: c.primary,
                scroll: firstScroll,
              );
              if (!c.compare) return first;
              final second = _Pane(
                controller: c,
                pane: c.secondary,
                second: true,
                scroll: secondScroll,
              );
              return constraints.maxWidth >= 700
                  ? Row(
                      children: [
                        Expanded(flex: 6, child: first),
                        const VerticalDivider(width: 1),
                        Expanded(flex: 5, child: second),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(flex: 6, child: first),
                        const Divider(height: 1),
                        Expanded(flex: 5, child: second),
                      ],
                    );
            },
          ),
        ),
      ],
    );
  }

  Widget _welcome() => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 850),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 28),
            child: Row(
              children: [
                DoorMark(size: 38),
                SizedBox(width: 12),
                Text(
                  'Bible Door',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: forest,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OPEN. READ. DISCOVER.',
                  style: TextStyle(
                    color: Color(0xFFCFD9B5),
                    fontSize: 11,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                const DoorMark(size: 86, light: true),
                const SizedBox(height: 28),
                const Text(
                  'A little key.\nA world of meaning.',
                  style: TextStyle(
                    color: Color(0xFFFFFDF4),
                    fontSize: 40,
                    fontFamily: 'BibleSerif',
                    height: 1.15,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Make room for the whole story.\nRead Scripture in its natural flow, wherever you are.',
                  style: TextStyle(
                    color: Color(0xFFDFE6D9),
                    height: 1.65,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: widget.onLibrary,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE6E9C6),
                    foregroundColor: forest,
                  ),
                  icon: const Icon(Icons.key),
                  label: const Text('Open your first Bible'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _WelcomeFeature(
            Icons.cloud_done_outlined,
            'Yours to read offline',
            'Download a book once, and take it with you.',
          ),
          const _WelcomeFeature(
            Icons.subject,
            'The story, in context',
            'Read by section, with quiet verse numbers when you need them.',
          ),
          const _WelcomeFeature(
            Icons.vertical_split_outlined,
            'Two perspectives, together',
            'Keep two translations or passages open side by side.',
          ),
          const SizedBox(height: 16),
          const Text(
            'FROM FREELY-GIVEN.ORG',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: olive),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Pane extends StatefulWidget {
  const _Pane({
    required this.controller,
    required this.pane,
    required this.scroll,
    this.second = false,
  });
  final AppController controller;
  final ReaderPane pane;
  final ScrollController scroll;
  final bool second;
  @override
  State<_Pane> createState() => _PaneState();
}

class _PaneState extends State<_Pane> {
  final paragraphKeys = <int, GlobalKey>{};
  Passage? visible;
  String? sectionId;
  Timer? saveTimer;
  AppController get c => widget.controller;
  ReaderPane get pane => widget.pane;
  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(updateVisible);
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    widget.scroll.removeListener(updateVisible);
    super.dispose();
  }

  void updateVisible() {
    if (!mounted || pane.section == null || !widget.scroll.hasClients) return;
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox) return;
    Passage? reference;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy + 64;
    for (final entry in paragraphKeys.entries) {
      final render = entry.value.currentContext?.findRenderObject();
      if (render is! RenderBox) continue;
      final bottom = render.localToGlobal(Offset(0, render.size.height)).dy;
      if (bottom < viewportTop) continue;
      final p = pane.section!.paragraphs[entry.key];
      final run = p.runs.where((r) => r.verse != null).firstOrNull;
      if (run != null) {
        reference = Passage(
          pane.section!.start.book,
          run.chapter ?? pane.section!.start.chapter,
          int.tryParse(RegExp(r'\d+').firstMatch(run.verse!)?.group(0) ?? '') ??
              1,
        );
        break;
      }
    }
    if (reference != null && visible != reference) {
      setState(() => visible = reference);
      saveTimer?.cancel();
      final request = pane.request;
      saveTimer = Timer(const Duration(milliseconds: 500), () {
        if (request != pane.request) return;
        pane.target = reference;
        c.save();
      });
    }
  }

  void alignPassage() {
    final section = pane.section;
    if (section == null) return;
    final id =
        '${pane.version!.key}/${section.start.book}/${pane.index}/${pane.request}';
    if (sectionId == id) return;
    saveTimer?.cancel();
    sectionId = id;
    paragraphKeys.clear();
    visible = pane.target ?? section.start;
    final target = pane.target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scroll.hasClients) return;
      widget.scroll.jumpTo(0);
      if (target == null || target == section.start || target.verse == 9999) {
        return;
      }
      final index = section.paragraphs.indexWhere(
        (p) => p.runs.any(
          (r) =>
              r.verse != null &&
              r.chapter == target.chapter &&
              (int.tryParse(
                        RegExp(r'\d+').firstMatch(r.verse!)?.group(0) ?? '',
                      ) ??
                      -1) >=
                  target.verse,
        ),
      );
      final ctx = paragraphKeys[index]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: .05);
    });
  }

  @override
  Widget build(BuildContext context) {
    final version = pane.version;
    if (version == null) return const SizedBox.shrink();
    alignPassage();
    final ref = visible ?? pane.target;
    final book = version.books.where((b) => b.code == ref?.book).firstOrNull;
    final label = ref == null || book == null
        ? 'Choose a passage'
        : ref.chapter < 1
        ? '${book.name} · Introduction'
        : '${book.name} ${ref.chapter}:${ref.verse == 9999 ? pane.section?.end.verse ?? 1 : ref.verse}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      showPassagePicker(context, c, second: widget.second),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        version.abbreviation.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.expand_more, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: pane.loading
                    ? null
                    : () => c.step(-1, second: widget.second),
                tooltip: 'Previous section',
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: pane.loading
                    ? null
                    : () => c.step(1, second: widget.second),
                tooltip: 'Next section',
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Expanded(
          child: pane.loading
              ? const Center(child: CircularProgressIndicator())
              : pane.error != null
              ? EmptyMessage(
                  icon: Icons.cloud_off,
                  title: 'This passage is unavailable',
                  message: pane.error!,
                  action: FilledButton(
                    onPressed: pane.target == null
                        ? null
                        : () => c.navigate(
                            pane.target!,
                            second: widget.second,
                            remember: false,
                          ),
                    child: const Text('Try again'),
                  ),
                )
              : pane.section == null
              ? const SizedBox.shrink()
              : _content(context, version, pane.section!),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    BibleVersion version,
    BibleSection section,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final rtl =
        RegExp(r'[\u0590-\u08FF]').allMatches(section.text).length >
        section.text.runes.length / 4;
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0).abs() > 250) {
          c.step(details.primaryVelocity! < 0 ? 1 : -1, second: widget.second);
        }
      },
      child: SelectionArea(
        child: SingleChildScrollView(
          controller: widget.scroll,
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 400 ? 20 : 28,
            vertical: 18,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          section.start.chapter < 1
                              ? 'INTRODUCTION'
                              : 'READING · ${pane.index + 1} OF ${pane.content!.sections.length}',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy this section',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text:
                                  '${section.text}\n\n${section.start.label(version)} · ${version.abbreviation}',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Section copied')),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined, size: 18),
                      ),
                    ],
                  ),
                  if (!section.paragraphs.any((p) => p.heading))
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 24),
                      child: Text(
                        section.title,
                        style: TextStyle(
                          fontFamily: c.serif ? 'BibleSerif' : null,
                          fontSize: c.fontSize * 1.45,
                          height: 1.25,
                        ),
                      ),
                    ),
                  Directionality(
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: section.paragraphs.asMap().entries.map((entry) {
                        final p = entry.value;
                        final key = paragraphKeys.putIfAbsent(
                          entry.key,
                          GlobalKey.new,
                        );
                        return Padding(
                          key: key,
                          padding: EdgeInsetsDirectional.only(
                            start: p.poetry ? 20 : 0,
                            top: p.heading ? 16 : 0,
                            bottom: p.heading
                                ? 22
                                : p.poetry
                                ? 6
                                : 18,
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: p.runs
                                  .map(
                                    (run) => TextSpan(
                                      text: run.verse != null
                                          ? (c.showNumbers ? run.text : ' ')
                                          : run.text,
                                      style: TextStyle(
                                        fontSize: run.verse != null
                                            ? c.fontSize * .65
                                            : null,
                                        color: run.verse != null
                                            ? scheme.onSurfaceVariant
                                            : run.jesus && c.redLetters
                                            ? (scheme.brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFFFFB4A8)
                                                  : const Color(0xFF993E34))
                                            : null,
                                        fontStyle: run.italic
                                            ? FontStyle.italic
                                            : null,
                                        fontWeight:
                                            run.bold || run.verse != null
                                            ? FontWeight.w600
                                            : null,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            style: TextStyle(
                              fontFamily: c.serif ? 'BibleSerif' : null,
                              fontSize: p.heading
                                  ? c.fontSize * 1.4
                                  : c.fontSize,
                              height: p.heading ? 1.3 : 1.7,
                              fontWeight: p.heading
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (section.notes.isNotEmpty)
                    Card(
                      child: ExpansionTile(
                        title: Text(
                          'Notes & references (${section.notes.length})',
                        ),
                        leading: const Icon(Icons.notes_outlined),
                        children: section.notes.asMap().entries.map((entry) {
                          final note = entry.value;
                          return ListTile(
                            title: Text(
                              '[${entry.key + 1}] ${note.text}',
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                            subtitle: Text(note.reference.label(version)),
                            trailing: note.crossReference
                                ? const Icon(Icons.arrow_forward, size: 18)
                                : null,
                            onTap: note.crossReference
                                ? () {
                                    final parts = note.text
                                        .replaceFirst(
                                          RegExp(r'^\d+:\d+:?\s*'),
                                          '',
                                        )
                                        .split(';');
                                    final reference = parts
                                        .map(
                                          (p) => parseReference(
                                            p
                                                .replaceAll(RegExp(r'\.$'), '')
                                                .trim(),
                                            version,
                                          ),
                                        )
                                        .whereType<Passage>()
                                        .firstOrNull;
                                    if (reference != null) {
                                      c.navigate(
                                        reference,
                                        second: widget.second,
                                      );
                                    } else {
                                      showPassagePicker(
                                        context,
                                        c,
                                        second: widget.second,
                                      );
                                    }
                                  }
                                : null,
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 30),
                  Center(
                    child: Text(
                      '•   •   •',
                      style: TextStyle(color: scheme.outline, letterSpacing: 6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => c.step(1, second: widget.second),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Continue reading'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
