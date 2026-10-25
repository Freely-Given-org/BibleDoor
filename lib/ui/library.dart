import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../models/bible.dart';
import 'bible_details.dart';
import 'theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.controller,
    required this.onRead,
  });
  final AppController controller;
  final VoidCallback onRead;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final keyField = TextEditingController();
  final formKey = GlobalKey<FormState>();
  AppController get c => widget.controller;
  @override
  void dispose() {
    keyField.dispose();
    super.dispose();
  }

  Future<void> add([String? key]) async {
    if (key == null && !formKey.currentState!.validate()) return;
    if (await c.add(key ?? keyField.text)) {
      keyField.clear();
      widget.onRead();
    }
  }

  Future<void> findFreeBibles() async {
    const address = 'https://freely-given.org/Software/BibleDropBox/Demos/';
    try {
      if (await launchUrl(
        Uri.parse(address),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } on Object {
      // Report a missing browser without disrupting the Library.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the browser. Visit $address'),
        ),
      );
    }
  }

  Future<void> import() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Bible Door ZIP package',
            extensions: ['zip'],
            mimeTypes: ['application/zip', 'application/x-zip-compressed'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > 32 * 1024 * 1024) {
        throw const BibleException('Choose a ZIP smaller than 32 MB.');
      }
      if (await c.import(await file.readAsBytes())) widget.onRead();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is BibleException
                  ? e.message
                  : 'Could not open that file. Please choose a Bible Door ZIP.',
            ),
          ),
        );
      }
    }
  }

  Future<void> export(BibleVersion version) async {
    await c.operation(() async {
      final bytes = await c.repository.exportPackage(version);
      final name =
          '${version.abbreviation.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}-Bible Door.zip';
      if (Platform.isAndroid || Platform.isIOS) {
        final folder = await getTemporaryDirectory();
        final file = File('${folder.path}/$name');
        await file.writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/zip')],
            title: 'Share ${version.name}',
            sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        );
      } else {
        final location = await getSaveLocation(
          suggestedName: name,
          acceptedTypeGroups: [
            const XTypeGroup(label: 'ZIP', extensions: ['zip']),
          ],
        );
        if (location != null) {
          await XFile.fromData(
            bytes,
            name: name,
            mimeType: 'application/zip',
          ).saveTo(location.path);
        }
      }
    });
  }

  void about(BibleVersion version) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(version.name),
      content: SingleChildScrollView(
        child: BibleDetails(
          version: version,
          offlineBooks: c.cached[version.key]?.length ?? 0,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const PageHeading(
            'Your bookshelf',
            'A door to every word.',
            'Bring your translation with you. Read anywhere, even offline.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.key_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Open a Bible with a key',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Enter the key shared by your translator or Bible publisher.',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: keyField,
                      enabled: !c.busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.go,
                      decoration: const InputDecoration(
                        labelText: 'Bible key',
                        hintText: 'word-123-456',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                      validator: (value) =>
                          isValidKey(normalizeKey(value ?? ''))
                          ? null
                          : 'Use a key such as webbe-123-456.',
                      onFieldSubmitted: (_) => add(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: c.busy ? null : () => add(),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Open Bible'),
                        ),
                        OutlinedButton.icon(
                          onPressed: c.busy ? null : import,
                          icon: const Icon(Icons.file_open_outlined),
                          label: const Text('Import a ZIP'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextButton.icon(
                      onPressed: findFreeBibles,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Find free Bibles'),
                    ),
                    const Text(
                      'Browse the Bible Drop Box demos at Freely-Given.org. '
                      'The Bible Door key is near the bottom of each individual Bible’s page.',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Bibles',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${c.versions.length}',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (c.versions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Your bookshelf is ready. Add a key above, import a Bible Door package, or try a freely available Bible below.',
                style: TextStyle(height: 1.6),
              ),
            ),
          ...c.versions.map(
            (version) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _versionCard(version),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Start exploring',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Public keys from Freely-Given.org. Internet needed for the first download.',
          ),
          const SizedBox(height: 16),
          _publicBible(
            'World English Bible',
            'British edition · Modern English',
            'webbe-123-456',
          ),
          const SizedBox(height: 10),
          _publicBible(
            'American Standard Version',
            '1901 edition · Traditional English',
            'asv-123-456',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final ok = await launchUrl(
                    Uri.parse(
                      'https://Freely-Given.org/Software/BibleDropBox/',
                    ),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open the browser.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 17),
                label: const Text('About Bible Drop Box'),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    ),
  );

  Widget _publicBible(String title, String subtitle, String key) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: const Icon(Icons.auto_stories_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_downward),
      onTap: c.busy ? null : () => add(key),
    ),
  );
  Widget _versionCard(BibleVersion version) {
    final count = c.cached[version.key]?.length ?? 0;
    return Card(
      key: ValueKey('library-bible-${version.key}'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: forest,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.menu_book, color: Color(0xFFF3EAC4)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        version.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${version.abbreviation} · $count / ${version.books.length} books offline',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled:
                      !c.busy && !c.primary.loading && !c.secondary.loading,
                  tooltip: 'Bible options',
                  onSelected: (value) {
                    switch (value) {
                      case 'download':
                        c.downloadAll(version);
                      case 'update':
                        c.refresh(version);
                      case 'share':
                        export(version);
                      case 'about':
                        about(version);
                      case 'remove':
                        confirmRemoveBible(context, c, version);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!version.key.startsWith('local-'))
                      const PopupMenuItem(
                        value: 'download',
                        child: Text('Download all books'),
                      ),
                    if (!version.key.startsWith('local-'))
                      const PopupMenuItem(
                        value: 'update',
                        child: Text('Update downloaded books'),
                      ),
                    if (version.shareable)
                      const PopupMenuItem(
                        value: 'share',
                        child: Text('Export downloaded books'),
                      ),
                    const PopupMenuItem(
                      value: 'about',
                      child: Text('About this Bible'),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove from device'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    c.openVersion(version);
                    widget.onRead();
                  },
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Read'),
                ),
                TextButton.icon(
                  onPressed: c.primary.version == null
                      ? null
                      : () {
                          c.setCompare(version);
                          widget.onRead();
                        },
                  icon: const Icon(Icons.vertical_split_outlined, size: 18),
                  label: const Text('Compare'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
