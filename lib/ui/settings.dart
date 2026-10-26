import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'about.dart';
import 'theme.dart';

const privacyText = '''Bible Door is made by Freely-Given.org. It contains no advertising, analytics, account system, or tracking SDKs.

Your downloaded Bible text, keys, reading locations, bookmarks, and preferences stay in this app’s local storage. The files are unencrypted. Android cloud backup is disabled for this app. Removing a Bible removes its local books and bookmarks; on Android, uninstalling the app removes all app data. On desktop, reading data is stored separately from the application files.

When you request a Bible or a book, Bible Door connects over HTTPS to Freely-Given.org. The request includes the Bible key and requested filename. Like any web server, that server can receive your IP address and connection information and may keep access logs. Bible Door does not send your bookmarks, search terms, or reading history to the server. Reading downloaded books does not require a connection.

Import reads only the ZIP file you select. Export uses the system share sheet or save dialog and is available only when the publisher permits sharing. Exported packages include downloaded Bible files and metadata, but not your key, bookmarks, history, or preferences. The destination you choose handles that copy under its own practices.

External website links open in your browser. Contact Freely-Given.org through its website for privacy enquiries.''';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const PageHeading(
              'Make yourself at home',
              'Room to read.',
              'A few thoughtful choices for a comfortable reading experience.',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: ThemeMode.values
                          .map(
                            (mode) => ChoiceChip(
                              label: Text(switch (mode) {
                                ThemeMode.system => 'Use device setting',
                                ThemeMode.light => 'Light',
                                ThemeMode.dark => 'Dark',
                              }),
                              selected: c.themeMode == mode,
                              onSelected: (_) {
                                c.themeMode = mode;
                                c.preferencesChanged();
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Text size · ${c.fontSize.round()}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: c.fontSize,
                      min: 14,
                      max: 32,
                      divisions: 18,
                      label: '${c.fontSize.round()}',
                      onChanged: (value) {
                        c.fontSize = value;
                        c.preferencesChanged();
                      },
                    ),
                    Wrap(
                      spacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Text('Serif'),
                          selected: c.serif,
                          onSelected: (_) {
                            c.serif = true;
                            c.preferencesChanged();
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Sans serif'),
                          selected: !c.serif,
                          onSelected: (_) {
                            c.serif = false;
                            c.preferencesChanged();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'A quiet place to read,\nand room to see the whole story.',
                        style: TextStyle(
                          fontFamily: c.serif ? 'BibleSerif' : null,
                          fontSize: c.fontSize,
                          height: 1.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                    title: const Text('Show verse numbers'),
                    subtitle: const Text(
                      'Small reference markers within the text',
                    ),
                    value: c.showNumbers,
                    onChanged: (value) {
                      c.showNumbers = value;
                      c.preferencesChanged();
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                    title: const Text('Words of Jesus in red'),
                    subtitle: const Text('When the translation marks them'),
                    value: c.redLetters,
                    onChanged: (value) {
                      c.redLetters = value;
                      c.preferencesChanged();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Card(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                    leading: const Icon(Icons.help_outline),
                    title: const Text('How Bible Door works'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('A key opens a Bible'),
                        content: const SingleChildScrollView(
                          child: Text(
                            '1. Open the Library and enter a key from a publisher, or import a Bible Door ZIP.\n\n2. Tap the reference above your reading to choose a book, chapter, or section. Swipe sideways to move between sections.\n\n3. Books are saved as you open them. Use “Download all books” in the Library menu before going offline. Search covers downloaded books only.\n\n4. Use Compare to open a second Bible or another passage. Unlink the panes to navigate independently. Linked panes use the same verse numbering; translations with different versifications may not align.\n\n5. Tap the bookmark icon to save a section. Find it again under Search. Expand “Notes & references” below the text for footnotes.\n\n6. Long press text to select and copy. The copy button copies the current section. Export downloaded books from the Library menu to share an allowed Bible package.',
                            style: TextStyle(height: 1.6),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About Bible Door'),
                    subtitle: const Text('App information and websites'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy'),
                    subtitle: const Text('No accounts, ads, or analytics'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Your reading stays yours'),
                        content: const SingleChildScrollView(
                          child: SelectableText(
                            privacyText,
                            style: TextStyle(height: 1.6),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Center(child: DoorMark(size: 40)),
            const SizedBox(height: 12),
            const Text(
              'Freely given. Freely read.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: olive),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
