import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:provider/provider.dart';

import 'models/browser_settings.dart';
import 'screens/browser_screen.dart';
import 'theme/manga_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must init before runApp so background isolates can attach.
  try {
    await FlutterDownloader.initialize(
      debug: kDebugMode,
      ignoreSsl: true,
    );
  } catch (e) {
    debugPrint('FlutterDownloader.initialize failed: $e');
  }

  runApp(const PrivacyBrowserApp());
}

class PrivacyBrowserApp extends StatefulWidget {
  const PrivacyBrowserApp({super.key});

  @override
  State<PrivacyBrowserApp> createState() => _PrivacyBrowserAppState();
}

class _PrivacyBrowserAppState extends State<PrivacyBrowserApp> {
  final BrowserSettings _settings = BrowserSettings();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _settings.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MangaTheme.light,
        home: const Scaffold(
          backgroundColor: MangaTheme.paper,
          body: Center(
            child: CircularProgressIndicator(color: MangaTheme.crimson),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<BrowserSettings>.value(
      value: _settings,
      child: MaterialApp(
        title: 'Privacy Browser',
        debugShowCheckedModeBanner: false,
        theme: MangaTheme.light,
        home: const BrowserScreen(),
      ),
    );
  }
}
