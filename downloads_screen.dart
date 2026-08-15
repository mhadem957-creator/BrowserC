import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';

import '../services/download_service.dart';
import '../theme/manga_theme.dart';
import '../widgets/manga_container.dart';

/// File manager UI for active and completed downloads, styled in Manga aesthetic.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final DownloadService _service = DownloadService.instance;
  String _filter = 'All';

  static const _categories = ['All', 'Music', 'Apps', 'Documents', 'Videos', 'Other'];

  @override
  void initState() {
    super.initState();
    _service.initialize().then((_) => _service.refresh());
    _service.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  List<DownloadItem> get _filtered {
    final list = _service.items;
    if (_filter == 'All') return list;
    return list.where((e) => e.category == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MangaTheme.paper,
      appBar: AppBar(
        title: const Text(
          'DOWNLOADS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _service.refresh(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: MangaTheme.ink),
        ),
      ),
      body: Column(
        children: [
          // Category chips
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: _categories
                  .map(
                    (c) => MangaChip(
                      label: c,
                      selected: _filter == c,
                      onTap: () => setState(() => _filter = c),
                    ),
                  )
                  .toList(),
            ),
          ),
          Container(height: 2.5, color: MangaTheme.ink),
          Expanded(
            child: _filtered.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _filtered[index];
                      return _DownloadTile(
                        item: item,
                        onPause: () => _service.pause(item.taskId),
                        onResume: () => _service.resume(item.taskId),
                        onCancel: () => _service.cancel(item.taskId),
                        onRemove: () => _service.remove(item.taskId, deleteFile: true),
                        onOpen: () async {
                          final result = await _service.openFile(item);
                          if (context.mounted && result.type != ResultType.done) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: MangaContainer(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_outlined, size: 48, color: MangaTheme.ink.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text(
              'NO DOWNLOADS YET',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Detected media files will appear here.',
              style: TextStyle(color: MangaTheme.ink.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.item,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRemove,
    required this.onOpen,
  });

  final DownloadItem item;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isRunning = item.status == DownloadTaskStatus.running ||
        item.status == DownloadTaskStatus.enqueued;
    final isPaused = item.status == DownloadTaskStatus.paused;
    final isComplete = item.status == DownloadTaskStatus.complete;
    final isFailed = item.status == DownloadTaskStatus.failed ||
        item.status == DownloadTaskStatus.canceled;

    return MangaContainer(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _categoryIcon(item.category),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                item.category.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: MangaTheme.crimson,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar (manga style – thick, hard)
          if (!isComplete && !isFailed)
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: LinearProgressIndicator(
                    value: item.progress / 100,
                    minHeight: 8,
                    backgroundColor: MangaTheme.paperDark,
                    color: MangaTheme.crimson,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${item.progress}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          if (isComplete)
            const Text(
              'COMPLETED',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: MangaTheme.crimson,
                letterSpacing: 1,
              ),
            ),
          if (isFailed)
            Text(
              item.status == DownloadTaskStatus.canceled ? 'CANCELED' : 'FAILED',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: MangaTheme.ink,
                letterSpacing: 1,
              ),
            ),
          const SizedBox(height: 10),
          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isRunning)
                _actionBtn(Icons.pause, 'Pause', onPause),
              if (isPaused)
                _actionBtn(Icons.play_arrow, 'Resume', onResume),
              if (isRunning || isPaused)
                _actionBtn(Icons.close, 'Cancel', onCancel),
              if (isComplete) ...[
                _actionBtn(Icons.open_in_new, 'Open', onOpen),
                _actionBtn(Icons.delete_outline, 'Delete', onRemove),
              ],
              if (isFailed)
                _actionBtn(Icons.delete_outline, 'Remove', onRemove),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryIcon(String cat) {
    IconData icon;
    switch (cat) {
      case 'Music':
        icon = Icons.music_note;
        break;
      case 'Videos':
        icon = Icons.videocam;
        break;
      case 'Apps':
        icon = Icons.android;
        break;
      case 'Documents':
        icon = Icons.description;
        break;
      default:
        icon = Icons.insert_drive_file;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: MangaTheme.paperDark,
        border: Border.all(color: MangaTheme.ink, width: 2),
      ),
      child: Icon(icon, size: 20, color: MangaTheme.ink),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: MangaTheme.paper,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: MangaTheme.ink, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: MangaTheme.ink,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 4),
                Text(
                  tooltip.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
