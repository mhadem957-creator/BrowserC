import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Background downloads via [flutter_downloader].
class DownloadService extends ChangeNotifier {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  final List<DownloadItem> _items = [];
  bool _initialized = false;

  List<DownloadItem> get items => List.unmodifiable(_items);
  List<DownloadItem> get active => _items
      .where((e) =>
          e.status == DownloadTaskStatus.running ||
          e.status == DownloadTaskStatus.enqueued ||
          e.status == DownloadTaskStatus.paused)
      .toList();
  List<DownloadItem> get completed =>
      _items.where((e) => e.status == DownloadTaskStatus.complete).toList();

  static const Set<String> downloadableExtensions = {
    'apk', 'mp3', 'mp4', 'm4a', 'ogg', 'wav', 'flac',
    'zip', 'rar', '7z', 'tar', 'gz',
    'pdf', 'epub', 'mobi',
    'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg',
    'txt', 'csv', 'json',
  };

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await FlutterDownloader.initialize(
        debug: kDebugMode,
        ignoreSsl: true,
      );
      FlutterDownloader.registerCallback(downloadCallback);
      await _loadExistingTasks();
    } catch (e, st) {
      debugPrint('DownloadService init error: $e\n$st');
    }
    _initialized = true;
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    // Background isolate — UI refreshed via [refresh].
  }

  Future<void> _loadExistingTasks() async {
    try {
      final tasks = await FlutterDownloader.loadTasks();
      if (tasks == null) return;
      _items
        ..clear()
        ..addAll(tasks.map(DownloadItem.fromTask));
      notifyListeners();
    } catch (e) {
      debugPrint('loadTasks error: $e');
    }
  }

  bool isDownloadableUrl(String url) {
    try {
      final path = Uri.parse(url).path.toLowerCase();
      final ext = path.contains('.') ? path.split('.').last.split('?').first : '';
      return downloadableExtensions.contains(ext);
    } catch (_) {
      return false;
    }
  }

  static String categoryFor(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : '';
    if (const {'mp3', 'm4a', 'ogg', 'wav', 'flac'}.contains(ext)) return 'Music';
    if (const {'mp4', 'webm', 'mkv', 'avi'}.contains(ext)) return 'Videos';
    if (ext == 'apk') return 'Apps';
    if (const {'pdf', 'epub', 'mobi', 'doc', 'docx', 'txt'}.contains(ext)) {
      return 'Documents';
    }
    return 'Other';
  }

  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;

    // Notifications (Android 13+)
    final notif = await Permission.notification.status;
    if (!notif.isGranted) {
      await Permission.notification.request();
    }

    // Storage — request what makes sense for the OS version.
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    // Android 11+ manage external (optional)
    if (await Permission.manageExternalStorage.isDenied) {
      // Don't block on this — we fall back to app-private dir.
    }
  }

  /// Always-writable app directory (avoids scoped-storage cancellations).
  Future<String> _downloadDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/Downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  String _safeFileName(String raw) {
    var name = raw.split('?').first.split('#').first;
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (name.isEmpty || name == '.' || name == '..') {
      name = 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
    // Avoid extremely long names
    if (name.length > 120) {
      final ext = name.contains('.') ? '.${name.split('.').last}' : '';
      name = '${name.substring(0, 120 - ext.length)}$ext';
    }
    return name;
  }

  Future<String?> enqueue({
    required String url,
    String? fileName,
    bool showNotification = true,
  }) async {
    await initialize();
    await _ensurePermissions();

    final savedDir = await _downloadDir();
    final name = _safeFileName(
      fileName ??
          Uri.parse(url).pathSegments.lastWhere(
                (s) => s.isNotEmpty,
                orElse: () =>
                    'download_${DateTime.now().millisecondsSinceEpoch}',
              ),
    );

    debugPrint('Enqueue download: $url -> $savedDir/$name');

    try {
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: savedDir,
        fileName: name,
        showNotification: showNotification,
        openFileFromNotification: true,
        // CRITICAL: false avoids many instant-cancel cases on Android 10+
        saveInPublicStorage: false,
        allowCellular: true,
        requiresStorageNotLow: false,
      );

      if (taskId != null) {
        _items.insert(
          0,
          DownloadItem(
            taskId: taskId,
            url: url,
            fileName: name,
            savedDir: savedDir,
            progress: 0,
            status: DownloadTaskStatus.enqueued,
          ),
        );
        notifyListeners();

        // Refresh status after a short delay (plugin updates async).
        Future.delayed(const Duration(seconds: 2), refresh);
        Future.delayed(const Duration(seconds: 5), refresh);
      } else {
        debugPrint('FlutterDownloader.enqueue returned null');
      }
      return taskId;
    } catch (e, st) {
      debugPrint('enqueue error: $e\n$st');
      return null;
    }
  }

  Future<void> pause(String taskId) async {
    await FlutterDownloader.pause(taskId: taskId);
    await refresh();
  }

  Future<void> resume(String taskId) async {
    await FlutterDownloader.resume(taskId: taskId);
    await refresh();
  }

  Future<void> cancel(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
    await refresh();
  }

  Future<void> remove(String taskId, {bool deleteFile = false}) async {
    await FlutterDownloader.remove(
      taskId: taskId,
      shouldDeleteContent: deleteFile,
    );
    _items.removeWhere((e) => e.taskId == taskId);
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadExistingTasks();
  }

  Future<OpenResult> openFile(DownloadItem item) async {
    final path = item.filePath;
    if (path == null || !File(path).existsSync()) {
      return OpenResult(type: ResultType.error, message: 'File not found');
    }
    if (item.fileName.toLowerCase().endsWith('.apk') && Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        return OpenResult(
          type: ResultType.permissionDenied,
          message: 'Install packages permission denied',
        );
      }
    }
    return OpenFilex.open(path);
  }
}

class DownloadItem {
  DownloadItem({
    required this.taskId,
    required this.url,
    required this.fileName,
    required this.savedDir,
    required this.progress,
    required this.status,
  });

  final String taskId;
  final String url;
  final String fileName;
  final String savedDir;
  int progress;
  DownloadTaskStatus status;

  String? get filePath =>
      savedDir.isNotEmpty ? '$savedDir/$fileName' : null;

  String get category => DownloadService.categoryFor(fileName);

  factory DownloadItem.fromTask(DownloadTask t) {
    return DownloadItem(
      taskId: t.taskId,
      url: t.url,
      fileName: t.filename ?? 'unknown',
      savedDir: t.savedDir,
      progress: t.progress,
      status: t.status,
    );
  }
}
