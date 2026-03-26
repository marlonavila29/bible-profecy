import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services.dart';
import 'home_shell.dart';
import 'app_theme.dart';
import 'app_locale.dart';
import 'bible_version_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e, stack) {
    print('[MAIN] Firebase Init Error: $e\n$stack');
  }

  // Initialize locale BEFORE data service (locale determines which collections to load)
  await AppLocale().init();
  await BibleVersionService().init();

  try {
    await DataService().init();
  } catch (e, stack) {
    print('[MAIN] DataService Init Error: $e\n$stack');
  }

  await AppTheme().init();

  runApp(const BibleApp());
}

class BibleApp extends StatefulWidget {
  const BibleApp({super.key});

  @override
  State<BibleApp> createState() => _BibleAppState();
}

class _BibleAppState extends State<BibleApp> {
  @override
  void initState() {
    super.initState();
    AppTheme().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppTheme().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bíblia | Daniel & Apocalipse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme().themeData,
      home: const HomeShell(),
    );
  }
}
