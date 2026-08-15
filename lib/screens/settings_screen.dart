import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/browser_settings.dart';
import '../services/history_service.dart';
import '../services/storage_service.dart';
import '../services/system_settings_service.dart';
import '../theme/manga_theme.dart';
import '../utils/constants.dart';
import '../widgets/manga_container.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _searxController;
  late final TextEditingController _homeController;
  late final BrowserSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<BrowserSettings>();
    _searxController = TextEditingController(text: _settings.searxngUrl);
    _homeController = TextEditingController(text: _settings.homePage);
  }

  @override
  void dispose() {
    final searx = _searxController.text.trim();
    final home = _homeController.text.trim();
    if (searx.isNotEmpty && searx != _settings.searxngUrl) {
      _settings.updateSearxngUrl(searx);
    }
    if (home.isNotEmpty && home != _settings.homePage) {
      _settings.updateHomePage(home);
    }
    _searxController.dispose();
    _homeController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _saveToggle(
    Future<void> Function(bool) fn,
    bool value,
    String label,
  ) async {
    await fn(value);
    _snack('Saved · $label');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<BrowserSettings>();

    return Scaffold(
      backgroundColor: MangaTheme.paper,
      appBar: AppBar(
        title: const Text(
          'SETTINGS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: MangaTheme.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
        children: [
          // ── Privacy score card ─────────────────────────────────────
          MangaContainer(
            padding: const EdgeInsets.all(16),
            color: MangaTheme.paperDark,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MangaTheme.crimson,
                    border: Border.all(color: MangaTheme.ink, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: MangaTheme.ink,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    _privacyScore(s).toString(),
                    style: const TextStyle(
                      color: MangaTheme.paper,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRIVACY SCORE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _privacyLabel(s),
                        style: TextStyle(
                          color: MangaTheme.ink.withOpacity(0.65),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const _SectionHeader('SEARCH & HOME'),
          MangaContainer(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldLabel('Search engine preset'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _presetValue(s.searxngUrl),
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final p in AppConstants.searchPresets)
                      if (p['url']!.isNotEmpty)
                        DropdownMenuItem(
                          value: p['url'],
                          child: Text(p['name']!),
                        ),
                    const DropdownMenuItem(
                      value: '__custom__',
                      child: Text('Custom URL…'),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v == null || v == '__custom__') return;
                    _searxController.text = v;
                    await s.updateSearxngUrl(v);
                    _snack('Search engine updated');
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searxController,
                  decoration: const InputDecoration(
                    labelText: 'Search endpoint (…/search?q=)',
                    helperText: 'Must end with q= for queries',
                  ),
                  onSubmitted: (v) async {
                    await s.updateSearxngUrl(v);
                    _snack('Saved · Search URL');
                  },
                  onEditingComplete: () async {
                    await s.updateSearxngUrl(_searxController.text);
                    _snack('Saved · Search URL');
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _homeController,
                  decoration: const InputDecoration(
                    labelText: 'Home page',
                    helperText: 'about:ink = manga start page',
                  ),
                  onSubmitted: (v) async {
                    await s.updateHomePage(v);
                    _snack('Saved · Home page');
                  },
                  onEditingComplete: () async {
                    await s.updateHomePage(_homeController.text);
                    _snack('Saved · Home page');
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _miniChip('INK HOME', () {
                      _homeController.text = 'about:ink';
                      s.updateHomePage('about:ink');
                    }),
                    _miniChip('BLANK', () {
                      _homeController.text = 'about:blank';
                      s.updateHomePage('about:blank');
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                const _FieldLabel('SafeSearch'),
                const SizedBox(height: 6),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('OFF')),
                    ButtonSegment(value: 1, label: Text('MOD')),
                    ButtonSegment(value: 2, label: Text('STRICT')),
                  ],
                  selected: {s.safeSearch},
                  onSelectionChanged: (set) async {
                    await s.updateSafeSearch(set.first);
                    _snack('Saved · SafeSearch');
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hide search engine branding'),
                  subtitle: const Text('Cloak SearXNG UI → Ink style'),
                  value: s.cloakSearchBranding,
                  onChanged: (v) => _saveToggle(s.toggleCloakSearch, v, 'Hide branding'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const _SectionHeader('SHIELD · PRIVACY'),
          MangaContainer(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Block ads'),
                  subtitle: const Text('Stop ad domains before load'),
                  value: s.adBlockEnabled,
                  onChanged: (v) => _saveToggle(s.toggleAdBlock, v, 'Block ads'),
                ),
                SwitchListTile(
                  title: const Text('Block trackers'),
                  subtitle: const Text('Cut analytics & fingerprint hosts'),
                  value: s.trackerBlockEnabled,
                  onChanged: (v) => _saveToggle(s.toggleTrackerBlock, v, 'Block trackers'),
                ),
                SwitchListTile(
                  title: const Text('Force HTTPS'),
                  subtitle: const Text('Upgrade http:// → https://'),
                  value: s.forceHttps,
                  onChanged: (v) => _saveToggle(s.toggleForceHttps, v, 'Force HTTPS'),
                ),
                SwitchListTile(
                  title: const Text('Incognito mode'),
                  subtitle: const Text('No history · lighter footprint'),
                  value: s.incognitoMode,
                  onChanged: (v) => _saveToggle(s.toggleIncognito, v, 'Incognito'),
                ),
                SwitchListTile(
                  title: const Text('Save browsing history'),
                  value: s.saveHistory,
                  onChanged: s.incognitoMode ? null : (v) => _saveToggle(s.toggleSaveHistory, v, 'History'),
                ),
                SwitchListTile(
                  title: const Text('Clear data when app exits'),
                  subtitle: const Text('Cookies + cache on close'),
                  value: s.clearDataOnExit,
                  onChanged: (v) => _saveToggle(s.toggleClearOnExit, v, 'Clear on exit'),
                ),
                SwitchListTile(
                  title: const Text('Biometric app lock'),
                  subtitle: const Text('Fingerprint / face on open'),
                  value: s.biometricLock,
                  onChanged: (v) => _saveToggle(s.toggleBiometricLock, v, 'Biometric lock'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const _SectionHeader('SECURE DNS'),
          MangaContainer(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('DNS-over-HTTPS lookups'),
                  subtitle: const Text('For address-bar host checks'),
                  value: s.dohEnabled,
                  onChanged: (v) => _saveToggle(s.toggleDoh, v, 'DoH'),
                ),
                DropdownButtonFormField<String>(
                  value: s.dohProviderUrl,
                  decoration: const InputDecoration(labelText: 'DoH provider'),
                  items: AppConstants.dohProviders
                      .map(
                        (p) => DropdownMenuItem(
                          value: p['url'],
                          child: Text(p['name']!),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v != null) {
                      await s.updateDohProvider(v);
                      _snack('Saved · DNS provider');
                    }
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.dns_outlined),
                    label: const Text('System Private DNS'),
                    onPressed: SystemSettingsService.openPrivateDnsSettings,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'WebView uses system DNS. Enable Android Private DNS '
                  'for full-network protection.',
                  style: TextStyle(
                    fontSize: 12,
                    color: MangaTheme.ink.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const _SectionHeader('SITE CONTROLS'),
          MangaContainer(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('JavaScript'),
                  subtitle: const Text('Off = maximum lockdown'),
                  value: s.javascriptEnabled,
                  onChanged: (v) => _saveToggle(s.toggleJavascript, v, 'JavaScript'),
                ),
                SwitchListTile(
                  title: const Text('Desktop site'),
                  subtitle: const Text('Request desktop user-agent'),
                  value: s.desktopMode,
                  onChanged: (v) => _saveToggle(s.toggleDesktopMode, v, 'Desktop site'),
                ),
                SwitchListTile(
                  title: const Text('Block pop-ups'),
                  value: s.blockPopups,
                  onChanged: (v) => _saveToggle(s.toggleBlockPopups, v, 'Block pop-ups'),
                ),
                SwitchListTile(
                  title: const Text('Media needs tap to play'),
                  value: s.mediaRequiresGesture,
                  onChanged: (v) => _saveToggle(s.toggleMediaGesture, v, 'Media gesture'),
                ),
                SwitchListTile(
                  title: const Text('Load images'),
                  subtitle: const Text('Off saves data'),
                  value: s.loadImages,
                  onChanged: (v) => _saveToggle(s.toggleLoadImages, v, 'Load images'),
                ),
                SwitchListTile(
                  title: const Text('Force dark pages'),
                  subtitle: const Text('Inject dark CSS on sites'),
                  value: s.forceDarkPages,
                  onChanged: (v) => _saveToggle(s.toggleForceDarkPages, v, 'Force dark'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const _SectionHeader('DATA'),
          MangaContainer(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.cookie_outlined),
                  label: const Text('Clear cookies, cache & site data'),
                  onPressed: () async {
                    await StorageService.clearAllBrowsingData();
                    _snack('Browsing data cleared');
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Clear browsing history'),
                  onPressed: () async {
                    await HistoryService.instance.clear();
                    _snack('History cleared');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const _SectionHeader('ABOUT'),
          MangaContainer(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INK BROWSER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Privacy-first · Manga UI · No Google account · '
                  'SearXNG search · Local ad/tracker lists · DoH helpers.',
                  style: TextStyle(
                    color: MangaTheme.ink.withOpacity(0.65),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'v1.1 · Built for people, not advertisers.',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _presetValue(String url) {
    for (final p in AppConstants.searchPresets) {
      if (p['url'] == url) return url;
    }
    return '__custom__';
  }

  int _privacyScore(BrowserSettings s) {
    var score = 40;
    if (s.adBlockEnabled) score += 12;
    if (s.trackerBlockEnabled) score += 12;
    if (s.forceHttps) score += 8;
    if (s.incognitoMode) score += 6;
    if (!s.saveHistory || s.incognitoMode) score += 4;
    if (s.blockPopups) score += 4;
    if (s.dohEnabled) score += 4;
    if (!s.javascriptEnabled) score += 6;
    if (s.clearDataOnExit) score += 4;
    return score.clamp(0, 100);
  }

  String _privacyLabel(BrowserSettings s) {
    final n = _privacyScore(s);
    if (n >= 90) return 'Maximum shield — excellent';
    if (n >= 75) return 'Strong — better than mainstream browsers';
    if (n >= 60) return 'Good — tighten a few toggles';
    return 'Basic — enable ad & tracker block';
  }

  Widget _miniChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: MangaTheme.ink, width: 2),
          boxShadow: const [
            BoxShadow(color: MangaTheme.ink, offset: Offset(2, 2), blurRadius: 0),
          ],
          color: MangaTheme.paper,
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.6,
          color: MangaTheme.crimson,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
    );
  }
}
