import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'library.dart';
import 'reader.dart';
import 'search.dart';
import 'settings.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selected = 0;
  AppController get c => widget.controller;
  void read() => setState(() => selected = 0);
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book),
        label: 'Read',
      ),
      const NavigationDestination(
        icon: Icon(Icons.local_library_outlined),
        selectedIcon: Icon(Icons.local_library),
        label: 'Library',
      ),
      const NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
      const NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
    ];
    final pages = [
      ReaderScreen(
        controller: c,
        onLibrary: () => setState(() => selected = 1),
      ),
      LibraryScreen(controller: c, onRead: read),
      SearchScreen(controller: c, onRead: read),
      SettingsScreen(controller: c),
    ];
    return PopScope(
      canPop: selected == 0 && !c.canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (selected != 0) {
          read();
        } else {
          c.back();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (c.error != null)
                MaterialBanner(
                  content: Text(c.error!),
                  leading: const Icon(Icons.info_outline),
                  actions: [
                    TextButton(
                      onPressed: c.clearError,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              if (c.busy)
                Column(
                  children: [
                    LinearProgressIndicator(value: c.progress),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.status ?? 'Working…',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (c.progress != null)
                            TextButton(
                              onPressed: c.cancelDownload,
                              child: const Text('Stop'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              Expanded(
                child: Row(
                  children: [
                    if (wide)
                      NavigationRail(
                        leading: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: DoorMark(),
                        ),
                        selectedIndex: selected,
                        onDestinationSelected: (value) =>
                            setState(() => selected = value),
                        labelType: NavigationRailLabelType.all,
                        minWidth: 100,
                        destinations: destinations
                            .map(
                              (d) => NavigationRailDestination(
                                icon: d.icon,
                                selectedIcon: d.selectedIcon,
                                label: Text(d.label),
                              ),
                            )
                            .toList(),
                      ),
                    if (wide) const VerticalDivider(width: 1),
                    Expanded(
                      child: IndexedStack(index: selected, children: pages),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (value) =>
                    setState(() => selected = value),
                destinations: destinations,
              ),
      ),
    );
  }
}
