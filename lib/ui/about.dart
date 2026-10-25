import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<PackageInfo> packageInfo = PackageInfo.fromPlatform();

  Future<void> openWebsite(String address) async {
    try {
      if (await launchUrl(
        Uri.parse(address),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } on Object {
      // A missing browser should leave the About page usable.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the browser. Visit $address')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About Bible Door')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            key: const PageStorageKey('about-scroll'),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const DoorMark(size: 60),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bible Door',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                FutureBuilder<PackageInfo>(
                                  future: packageInfo,
                                  builder: (context, snapshot) {
                                    final info = snapshot.data;
                                    return Text(
                                      info == null || info.version.isEmpty
                                          ? (snapshot.connectionState ==
                                                    ConnectionState.done
                                                ? 'Version unavailable'
                                                : 'Loading version…')
                                          : 'Version ${info.version}${info.buildNumber.isEmpty ? '' : ' (build ${info.buildNumber})'}',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Freely given. Freely read.',
                        style: TextStyle(
                          fontFamily: 'BibleSerif',
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'A Bible reader from Freely-Given.org for finished translations and works in progress. Read in context, compare translations, search downloaded books, and bookmark passages to return to.\n\n'
                        'Downloaded books stay available offline. No accounts, advertising, or analytics.',
                        style: TextStyle(height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _website(
                title: 'Freely-Given.org',
                description: 'Freely shared Bible resources, translations, and software. The home of Bible Door.',
                address: 'https://Freely-Given.org/',
                icon: Icons.public,
              ),
              const SizedBox(height: 12),
              _website(
                title: 'OET.Bible',
                description: 'Discover the Open English Translation: a radical, new, open-licensed, modern-English Bible translation.',
                address: 'https://OET.Bible/',
                icon: Icons.auto_stories_outlined,
              ),
              const SizedBox(height: 32),
              const Text(
                'Project founder and specification: Robert J. Hunt (Freely-Given.org).\n'
                'Flutter implementation assistance: OpenAI Codex.\n\n'
                '© 2026 Freely-Given.org. Bible Door is open-source software under the MIT licence. Bible translations retain their own licences and notices.',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'Bible Door',
                  ),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Open-source licences'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _website({
    required String title,
    required String description,
    required String address,
    required IconData icon,
  }) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(description, style: const TextStyle(height: 1.5)),
      ),
      trailing: const Icon(Icons.open_in_new, size: 20),
      onTap: () => openWebsite(address),
    ),
  );
}
