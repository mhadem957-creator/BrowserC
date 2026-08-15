import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemNavigator;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../models/browser_settings.dart';
import '../models/browser_tab.dart';
import '../services/adblock_service.dart';
import '../services/download_service.dart';
import '../services/history_service.dart';
import '../services/search_service.dart';
import '../services/storage_service.dart';
import '../theme/manga_theme.dart';
import '../widgets/manga_bottom_bar.dart';
import '../widgets/manga_url_bar.dart';
import 'downloads_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'tabs_screen.dart';

const String _searxCloakJs = r"""
(function(){
  try {
    var h = location.hostname || '';
    if (h.indexOf('searx') === -1 && location.href.indexOf('/search') === -1) return;
    var css = 'body,html{background:#F6F5F0!important;color:#121212!important}'
      + '.title,.navbar-brand,#main-logo,.logo,footer,#footer,.footer,.powered-by,'
      + 'img[alt*="SearX"],img[src*="searx"],header .title,.instance-name'
      + '{display:none!important;height:0!important;overflow:hidden!important}'
      + 'nav.navbar,.searx-navbar,header{background:#F6F5F0!important;border-bottom:3px solid #121212!important;box-shadow:none!important}'
      + 'input[type=text],input[type=search],#q{border:3px solid #121212!important;border-radius:0!important;background:#fff!important;box-shadow:3px 3px 0 #121212!important}'
      + 'button,.btn,input[type=submit]{background:#E60012!important;color:#F6F5F0!important;border:3px solid #121212!important;border-radius:0!important;font-weight:800!important}'
      + '#urls article,.result{border:2px solid #121212!important;background:#fff!important;box-shadow:3px 3px 0 #121212!important;margin-bottom:10px!important;padding:10px!important}'
      + 'a{color:#E60012!important}h3,h4{color:#121212!important;font-weight:900!important}';
    var s=document.createElement('style'); s.textContent=css;
    (document.documentElement||document.head).appendChild(s);
  } catch(e) {}
})();
""";

const String _desktopUserAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

/// Main browser screen combining InAppWebView, AdBlock, DownloadService,
/// MangaUrlBar and MangaBottomBar.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final List<BrowserTab> _tabs = [];
  int _currentIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  bool _isLoading = false;
  double _progress = 0;

  BrowserTab get _currentTab => _tabs[_currentIndex];

  @override
  void initState() {
    super.initState();
    // Initialize download service early.
    DownloadService.instance.initialize();
    HistoryService.instance.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<BrowserSettings>();
      _openNewTab(url: settings.homePage);
    });
  }

  @override
  void dispose() {
    // Clear on exit if enabled
    try {
      final settings = context.read<BrowserSettings>();
      if (settings.clearDataOnExit) {
        StorageService.clearAllBrowsingData();
      }
    } catch (_) {}
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _openNewTab({String? url}) {
    final settings = context.read<BrowserSettings>();
    final tab = BrowserTab(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: url ?? settings.homePage,
    );
    setState(() {
      _tabs.add(tab);
      _currentIndex = _tabs.length - 1;
      _urlController.text = tab.url;
    });
  }

  void _closeTab(int index) {
    final settings = context.read<BrowserSettings>();
    if (_tabs.length == 1) {
      setState(() {
        _tabs[0] = BrowserTab(id: _tabs[0].id, url: settings.homePage);
        _currentIndex = 0;
        _urlController.text = _tabs[0].url;
      });
      return;
    }
    setState(() {
      _tabs.removeAt(index);
      if (_currentIndex >= _tabs.length) {
        _currentIndex = _tabs.length - 1;
      }
      _urlController.text = _currentTab.url;
    });
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
      _urlController.text = _tabs[index].url;
      _isLoading = false;
      _progress = 0;
    });
  }

  /// Loads the custom manga start page (hides SearXNG branding).
  Future<void> _loadInkHome(InAppWebViewController controller) async {
    final html = await rootBundle.loadString('assets/start/home.html');
    // Point search form at the user's configured SearXNG instance.
    final settings = context.read<BrowserSettings>();
    final action = settings.searxngUrl.contains('?')
        ? settings.searxngUrl.split('?').first
        : settings.searxngUrl.replaceAll(RegExp(r'/search.*'), '/search');
    final patched = html.replaceFirst(
      'action="https://searx.be/search"',
      'action="$action"',
    );
    await controller.loadData(
      data: patched,
      mimeType: 'text/html',
      encoding: 'utf-8',
      baseUrl: WebUri('https://ink.local/'),
    );
    setState(() {
      _currentTab.url = 'about:ink';
      _currentTab.title = 'Ink';
      _urlController.text = '';
      _isLoading = false;
    });
  }

  Future<void> _handleSubmitted(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty ||
        trimmed == 'about:ink' ||
        trimmed == 'about:home' ||
        trimmed == 'ink://home') {
      final controller = _currentTab.controller;
      if (controller != null) {
        await _loadInkHome(controller);
      } else {
        setState(() => _currentTab.url = 'about:ink');
      }
      _urlFocusNode.unfocus();
      return;
    }

    final settings = context.read<BrowserSettings>();
    final searchService = SearchService(settings.searxngUrl, safeSearch: settings.safeSearch);
    var resolved = searchService.resolveInput(trimmed);
    if (resolved.isEmpty) return;
    if (settings.forceHttps && resolved.startsWith('http://')) {
      resolved = 'https://${resolved.substring(7)}';
    }

    _urlFocusNode.unfocus();
    final controller = _currentTab.controller;
    if (controller != null) {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(resolved)));
    } else {
      setState(() => _currentTab.url = resolved);
    }
  }


  bool _isSearxUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final u = url.toLowerCase();
    return u.contains('searx') || (u.contains('/search?') && u.contains('q='));
  }

  /// Hide SearXNG branding and restyle results.
  Future<void> _cloakSearx(InAppWebViewController controller) async {
    const js = r"""
(function() {
  if (window.__inkCloak) return;
  window.__inkCloak = true;
  var css = `
    body, html { background: #F6F5F0 !important; color: #121212 !important; }
    .title, a.navbar-brand, .navbar-brand, #main-logo, .logo,
    footer, #footer, .footer, .powered-by,
    img[alt*="SearX"], img[src*="searx"],
    header .title, .instance-name {
      display: none !important;
      visibility: hidden !important;
      height: 0 !important;
      overflow: hidden !important;
    }
    nav.navbar, .searx-navbar, header {
      background: #F6F5F0 !important;
      border-bottom: 3px solid #121212 !important;
      box-shadow: none !important;
    }
    input[type="text"], input[type="search"], #q {
      border: 3px solid #121212 !important;
      border-radius: 0 !important;
      background: #fff !important;
      box-shadow: 3px 3px 0 #121212 !important;
      color: #121212 !important;
      font-weight: 600 !important;
    }
    button, .btn, input[type="submit"] {
      background: #E60012 !important;
      color: #F6F5F0 !important;
      border: 3px solid #121212 !important;
      border-radius: 0 !important;
      box-shadow: 3px 3px 0 #121212 !important;
      font-weight: 800 !important;
    }
    #urls article, .result, #urls .result {
      border: 2px solid #121212 !important;
      border-radius: 0 !important;
      background: #fff !important;
      box-shadow: 3px 3px 0 #121212 !important;
      margin-bottom: 12px !important;
      padding: 12px !important;
    }
    a { color: #E60012 !important; }
    h3, h4 { color: #121212 !important; font-weight: 900 !important; }
  `;
  var s = document.createElement('style');
  s.id = 'ink-cloak';
  s.textContent = css;
  (document.head || document.documentElement).appendChild(s);
  try {
    document.title = (document.title || '').replace(/SearXNG/gi, 'Ink').replace(/SearxNG/gi, 'Ink').replace(/Searx/gi, 'Ink');
  } catch (e) {}
})();
""";
    try {
      await controller.evaluateJavascript(source: js);
    } catch (_) {}
  }

  String _displayUrl(String url) {
    if (url == 'about:ink' ||
        url == 'about:home' ||
        url.startsWith('https://ink.local')) {
      return '';
    }
    if (_isSearxUrl(url)) {
      try {
        final q = Uri.parse(url).queryParameters['q'];
        if (q != null && q.isNotEmpty) return q;
      } catch (_) {}
      return 'Search';
    }
    return url;
  }


  Future<void> _injectForceDark(InAppWebViewController controller) async {
    const js = r"""
(function(){
  if (window.__inkDark) return; window.__inkDark = true;
  var s=document.createElement('style');
  s.textContent='html,body{background:#121212!important;color:#E8E6DF!important}a{color:#E60012!important}img,video{opacity:.92}';
  (document.head||document.documentElement).appendChild(s);
})();
""";
    try { await controller.evaluateJavascript(source: js); } catch (_) {}
  }

  Future<void> _applyContentBlockers(InAppWebViewController controller) async {
    final settings = context.read<BrowserSettings>();
    final blockers = await AdBlockService.instance.buildContentBlockers(
      blockAds: settings.adBlockEnabled,
      blockTrackers: settings.trackerBlockEnabled,
    );
    await controller.setSettings(
      settings: InAppWebViewSettings(contentBlockers: blockers),
    );
  }

  /// Intercept navigation / resource loads that look like direct file downloads.
  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final url = action.request.url?.toString() ?? '';
    if (url.isEmpty) return NavigationActionPolicy.ALLOW;

    final downloadService = DownloadService.instance;
    if (downloadService.isDownloadableUrl(url)) {
      // Ask user before starting the download.
      final confirmed = await _showDownloadConfirmDialog(url);
      if (confirmed == true) {
        final taskId = await downloadService.enqueue(url: url);
        if (mounted && taskId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download started: ${Uri.parse(url).pathSegments.last}'),
              action: SnackBarAction(
                label: 'VIEW',
                textColor: MangaTheme.crimson,
                onPressed: _showDownloadsScreen,
              ),
            ),
          );
        }
      }
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<bool?> _showDownloadConfirmDialog(String url) {
    final name = Uri.parse(url).pathSegments.isNotEmpty
        ? Uri.parse(url).pathSegments.last
        : url;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MangaTheme.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: const BorderSide(color: MangaTheme.ink, width: 4),
        ),
        title: const Text(
          'DOWNLOAD?',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        content: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DOWNLOAD'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) {
      return const Scaffold(
        backgroundColor: MangaTheme.paper,
        body: Center(child: CircularProgressIndicator(color: MangaTheme.crimson)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _onSystemBack();
      },
      child: Scaffold(
        backgroundColor: MangaTheme.paper,
        appBar: AppBar(
          titleSpacing: 8,
          title: MangaUrlBar(
            controller: _urlController,
            focusNode: _urlFocusNode,
            isSecure: _currentTab.url.startsWith('https://'),
            onSubmitted: _handleSubmitted,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New tab',
              onPressed: () => _openNewTab(),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: _showSettingsScreen,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(_isLoading ? 6 : 3),
            child: Column(
              children: [
                if (_isLoading)
                  LinearProgressIndicator(
                    value: _progress <= 0 ? null : _progress,
                    minHeight: 4,
                    backgroundColor: MangaTheme.paperDark,
                    color: MangaTheme.crimson,
                  ),
                Container(height: 3, color: MangaTheme.ink),
              ],
            ),
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            for (int i = 0; i < _tabs.length; i++) _buildWebViewForTab(i),
          ],
        ),
        bottomNavigationBar: MangaBottomBar(
          onBack: _goBack,
          onForward: _goForward,
          onReload: _reloadOrStop,
          onHome: _goHome,
          isLoading: _isLoading,
          tabCount: _tabs.length,
          onTabsPressed: _showTabsScreen,
          onHistoryPressed: _showHistoryScreen,
          onDownloadsPressed: _showDownloadsScreen,
        ),
      ),
    );
  }

  Widget _buildWebViewForTab(int index) {
    final tab = _tabs[index];
    final settings = context.read<BrowserSettings>();

    return KeyedSubtree(
      key: ValueKey(tab.id),
      child: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
            tab.url == 'about:ink' || tab.url == 'about:home'
                ? 'about:blank'
                : tab.url,
          ),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: settings.javascriptEnabled,
          cacheEnabled: true,
          supportZoom: true,
          transparentBackground: true,
          mediaPlaybackRequiresUserGesture: settings.mediaRequiresGesture,
          userAgent: settings.desktopMode ? _desktopUserAgent : null,
          useShouldOverrideUrlLoading: true,
          supportMultipleWindows: !settings.blockPopups,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
          // Speed
          useOnLoadResource: false,
          verticalScrollBarEnabled: true,
          preferredContentMode: UserPreferredContentMode.MOBILE,
          allowsInlineMediaPlayback: true,
          // Early cloak of SearXNG (runs before paint when possible)
          userScripts: [
            UserScript(
              source: _searxCloakJs,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
          ],
        ),
        onWebViewCreated: (controller) async {
          tab.controller = controller;
          await _applyContentBlockers(controller);
          if (tab.url == 'about:ink' || tab.url == 'about:home') {
            await _loadInkHome(controller);
          }
        },
        shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
        onLoadStart: (controller, url) {
          tab.url = url?.toString() ?? tab.url;
          if (index != _currentIndex) return;
          setState(() {
            _isLoading = true;
            _urlController.text = _displayUrl(tab.url);
          });
        },
        onLoadStop: (controller, url) async {
          tab.url = url?.toString() ?? tab.url;
          tab.title = await controller.getTitle() ?? tab.url;
          final settings = context.read<BrowserSettings>();
          if (_isSearxUrl(tab.url) && settings.cloakSearchBranding) {
            await _cloakSearx(controller);
            tab.title = 'Ink Search';
          }
          if (settings.forceDarkPages) {
            await _injectForceDark(controller);
          }
          if (!settings.loadImages) {
            try {
              await controller.evaluateJavascript(source: r"""
                (function(){var s=document.createElement('style');s.textContent='img,picture,video{display:none!important}';(document.head||document.documentElement).appendChild(s);})();
              """);
            } catch (_) {}
          }
          // Record history (skipped when incognito / disabled)
          await HistoryService.instance.add(
            url: tab.url,
            title: tab.title,
            incognito: settings.incognitoMode || !settings.saveHistory,
          );
          if (!mounted || index != _currentIndex) return;
          setState(() {
            _isLoading = false;
            _urlController.text = _displayUrl(tab.url);
          });
        },
        onProgressChanged: (controller, progress) {
          if (index != _currentIndex) return;
          setState(() => _progress = progress / 100);
        },
        onReceivedError: (controller, request, error) {
          if (index != _currentIndex) return;
          setState(() => _isLoading = false);
        },
        onTitleChanged: (controller, title) {
          if (title != null) tab.title = title;
        },
        // Capture downloadable content from <a download> or blob responses when possible.
        onDownloadStartRequest: (controller, request) async {
          final url = request.url.toString();
          final confirmed = await _showDownloadConfirmDialog(url);
          if (confirmed == true) {
            await DownloadService.instance.enqueue(
              url: url,
              fileName: request.suggestedFilename,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Download started: ${request.suggestedFilename ?? 'file'}'),
                  action: SnackBarAction(
                    label: 'VIEW',
                    textColor: MangaTheme.crimson,
                    onPressed: _showDownloadsScreen,
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _goBack() async {
    final controller = _currentTab.controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    }
  }

  /// Phone system back button / gesture:
  /// 1) WebView history back if possible
  /// 2) Otherwise leave the app
  Future<void> _onSystemBack() async {
    final controller = _currentTab.controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    // No more pages in this tab → exit app
    SystemNavigator.pop();
  }

  Future<void> _goForward() async {
    final controller = _currentTab.controller;
    if (controller != null && await controller.canGoForward()) {
      await controller.goForward();
    }
  }

  Future<void> _reloadOrStop() async {
    final controller = _currentTab.controller;
    if (controller == null) return;
    if (_isLoading) {
      await controller.stopLoading();
    } else {
      await controller.reload();
    }
  }

  Future<void> _goHome() async {
    final settings = context.read<BrowserSettings>();
    await _handleSubmitted(settings.homePage);
  }

  void _showTabsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TabsScreen(
          tabs: _tabs,
          currentIndex: _currentIndex,
          onSelect: (i) {
            Navigator.pop(context);
            _switchTab(i);
          },
          onClose: _closeTab,
          onNewTab: () {
            Navigator.pop(context);
            _openNewTab();
          },
        ),
      ),
    );
  }

  void _showSettingsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _showHistoryScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          onOpenUrl: (url) {
            _handleSubmitted(url);
          },
        ),
      ),
    );
  }

  void _showDownloadsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DownloadsScreen()),
    );
  }
}
