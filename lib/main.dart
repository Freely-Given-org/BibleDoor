import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_controller.dart';
import 'data/bible_repository.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Serif',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  try {
    const developmentPath = String.fromEnvironment('BIBLEDOOR_DATA_DIR');
    final directory = kDebugMode && developmentPath.isNotEmpty
        ? Directory(developmentPath)
        : Directory(
            '${(await getApplicationSupportDirectory()).path}/BibleDoor',
          );
    final controller = AppController(BibleRepository(directory));
    runApp(BibleDoorApp(controller: controller));
    await controller.initialize();
  } on Object {
    runApp(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Bible Door could not open its local storage. Free some space and restart the app.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BibleDoorApp extends StatelessWidget {
  const BibleDoorApp({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'Bible Door',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: controller.themeMode,
      home: controller.ready
          ? HomeScreen(controller: controller)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
  );
}
