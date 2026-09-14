import 'dart:io' as io;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'download_trigger_stub.dart' if (dart.library.js_interop) 'download_trigger_web.dart';

typedef DownloadProgressCallback = void Function(int received, int total, double percent, String speedFormatted);

class GalleryDownloaderService {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  /// Request storage / media permissions based on Android API level
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    
    if (io.Platform.isAndroid) {
      final videoStatus = await Permission.videos.status;
      final audioStatus = await Permission.audio.status;
      final storageStatus = await Permission.storage.status;

      if (!videoStatus.isGranted || !audioStatus.isGranted || !storageStatus.isGranted) {
        final statuses = await [
          Permission.videos,
          Permission.audio,
          Permission.storage,
        ].request();

        return statuses[Permission.videos]?.isGranted == true ||
            statuses[Permission.storage]?.isGranted == true ||
            statuses[Permission.audio]?.isGranted == true;
      }
      return true;
    }
    return true;
  }

  /// Get the local public gallery destination path (DCIM/Camera / Music / Movies)
  Future<io.Directory> _getPublicGalleryDirectory({required bool isAudio}) async {
    if (kIsWeb) {
      throw UnsupportedError('Filesystem directories are not used on Web');
    }

    if (io.Platform.isAndroid) {
      // Universal Public Download directory accessible across Android 10 - 15 without permission blocks
      final downloadDir = io.Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) return downloadDir;

      try {
        await downloadDir.create(recursive: true);
        return downloadDir;
      } catch (_) {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) return extDir;
        return await getApplicationDocumentsDirectory();
      }
    } else if (io.Platform.isWindows) {
      final downloadsDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final target = io.Directory('${downloadsDir.path}/QuickSave');
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      return target;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      final target = io.Directory('${docs.path}/QuickSave');
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      return target;
    }
  }

  /// Sanitize file name
  String sanitizeFileName(String title, String ext) {
    final clean = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    final shortened = clean.length > 50 ? clean.substring(0, 50) : clean;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${shortened.isEmpty ? "video" : shortened}_$timestamp.$ext';
  }

  /// Downloads media stream directly into device Gallery/Public Storage
  Future<String> downloadToGallery({
    required String downloadUrl,
    required String title,
    required String ext,
    required bool isAudioOnly,
    required DownloadProgressCallback onProgress,
  }) async {
    final fileName = sanitizeFileName(title, ext);

    if (kIsWeb) {
      // In Web Browser: Trigger native browser download directly into PC's Downloads folder
      onProgress(100, 100, 1.0, 'Saving to Downloads...');
      triggerWebDownload(downloadUrl, fileName);
      return 'Downloaded to Downloads folder';
    }

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      throw Exception('Storage permission is required to save media.');
    }

    final targetDir = await _getPublicGalleryDirectory(isAudio: isAudioOnly);
    final filePath = '${targetDir.path}/$fileName';

    _cancelToken = CancelToken();

    int lastBytes = 0;
    int lastTime = DateTime.now().millisecondsSinceEpoch;
    double smoothedSpeed = 0;

    try {
      await _dio.download(
        downloadUrl,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final timeDelta = (now - lastTime) / 1000.0;

          if (timeDelta >= 0.5 && received > lastBytes) {
            final bytesDelta = received - lastBytes;
            final currentSpeed = bytesDelta / timeDelta;
            smoothedSpeed = (smoothedSpeed == 0)
                ? currentSpeed
                : (smoothedSpeed * 0.7 + currentSpeed * 0.3);

            lastBytes = received;
            lastTime = now;
          }

          final percent = total > 0 ? (received / total) : 0.0;
          final speedFormatted = _formatSpeed(smoothedSpeed);

          onProgress(received, total, percent, speedFormatted);
        },
      );

      // Scan file to trigger Android MediaStore index (so it shows instantly in Phone Gallery)
      await _scanMediaFile(filePath);

      return filePath;
    } catch (e) {
      // Clean up incomplete/partial file upon cancel or error to prevent storage leaks
      try {
        final f = io.File(filePath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
      rethrow;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('Download cancelled by user.');
  }

  /// Formats speed in KB/s or MB/s
  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '';
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }

  /// Android MediaScanner trigger
  Future<void> _scanMediaFile(String filePath) async {
    if (!kIsWeb && io.Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.snapsave.downloader/media_scanner');
        await platform.invokeMethod('scanFile', {'path': filePath});
      } catch (_) {
        // Fallback or silent catch if platform channel is not wired
      }
    }
  }
}
