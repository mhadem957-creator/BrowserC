import 'package:flutter/material.dart';

import '../models/browser_tab.dart';
import '../theme/manga_theme.dart';
import '../widgets/manga_container.dart';

/// Tab manager with Manga / Neubrutalism styling.
class TabsScreen extends StatelessWidget {
  const TabsScreen({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
    required this.onClose,
    required this.onNewTab,
  });

  final List<BrowserTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final VoidCallback onNewTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MangaTheme.paper,
      appBar: AppBar(
        title: Text(
          '${tabs.length} ${tabs.length == 1 ? 'TAB' : 'TABS'}',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New tab',
            onPressed: onNewTab,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: MangaTheme.ink),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isCurrent = index == currentIndex;
          return MangaContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: isCurrent ? MangaTheme.paperDark : MangaTheme.paper,
            borderWidth: isCurrent ? 4 : 3,
            onTap: () => onSelect(index),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCurrent ? MangaTheme.crimson : MangaTheme.paperDark,
                    border: Border.all(color: MangaTheme.ink, width: 2),
                  ),
                  child: Icon(
                    Icons.public,
                    size: 18,
                    color: isCurrent ? MangaTheme.paper : MangaTheme.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tab.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: MangaTheme.ink.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close tab',
                  onPressed: () => onClose(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
