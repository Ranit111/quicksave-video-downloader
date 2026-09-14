import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/video_info.dart';
import '../services/api_service.dart';
import '../services/gallery_downloader_service.dart';
import '../services/youtube_local_extractor_service.dart';
import '../utils/app_error_formatter.dart';

enum AppState { idle, extracting, ready, downloading, completed, error }

class DownloaderProvider extends ChangeNotifier {
  final ApiService _apiService;
  final GalleryDownloaderService _downloaderService;
  final YoutubeLocalExtractorService _youtubeLocalExtractorService;

  DownloaderProvider({
    ApiService? apiService,
    GalleryDownloaderService? downloaderService,
    YoutubeLocalExtractorService? youtubeLocalExtractorService,
  })  : _apiService = apiService ?? ApiService(),
        _downloaderService = downloaderService ?? GalleryDownloaderService(),
        _youtubeLocalExtractorService =
            youtubeLocalExtractorService ?? YoutubeLocalExtractorService();

  final TextEditingController urlController = TextEditingController();
  AppState _state = AppState.idle;
  VideoInfo? _videoInfo;
  QualityOption? _selectedQuality;
  String _errorMessage = '';
  
  // Download metrics
  double _downloadProgress = 0.0;
  String _downloadSpeed = '';
  int _bytesReceived = 0;
  int _bytesTotal = 0;
  String _downloadedFilePath = '';
  String _selectedPlatformFilter = 'all';
  int _thumbnailReloadKey = 0;

  // Getters
  AppState get state => _state;
  VideoInfo? get videoInfo => _videoInfo;
  QualityOption? get selectedQuality => _selectedQuality;
  String get errorMessage => _errorMessage;
  double get downloadProgress => _downloadProgress;
  String get downloadSpeed => _downloadSpeed;
  int get bytesReceived => _bytesReceived;
  int get bytesTotal => _bytesTotal;
  String get downloadedFilePath => _downloadedFilePath;
  String get selectedPlatformFilter => _selectedPlatformFilter;
  int get thumbnailReloadKey => _thumbnailReloadKey;
  String get serverUrl => _apiService.baseUrl;

  void onNetworkRestored() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _thumbnailReloadKey++;
    notifyListeners();

    // If previous attempt failed with an error and user has entered a URL, auto-retry fetching
    if (_state == AppState.error && urlController.text.trim().isNotEmpty) {
      clearError();
      fetchVideoInfo();
    }
  }

  void updateServerUrl(String newUrl) {
    _apiService.updateBaseUrl(newUrl);
    notifyListeners();
  }

  void setPlatformFilter(String platform) {
    _selectedPlatformFilter = platform;
    notifyListeners();
  }

  void selectQuality(QualityOption quality) {
    _selectedQuality = quality;
    notifyListeners();
  }

  bool _isValidVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('instagram.com') ||
        lower.contains('facebook.com') ||
        lower.contains('fb.watch') ||
        lower.contains('sharechat.com') ||
        lower.contains('tiktok.com') ||
        lower.contains('twitter.com') ||
        lower.contains('x.com') ||
        lower.contains('reddit.com');
  }

  void clearError() {
    _errorMessage = '';
    if (_state == AppState.error) {
      _state = _videoInfo != null ? AppState.ready : AppState.idle;
    }
    notifyListeners();
  }

  /// Paste link from device clipboard
  Future<void> pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.trim().isNotEmpty) {
        final text = data.text!.trim();
        urlController.text = text;
        notifyListeners();
        if (text.startsWith('http://') || text.startsWith('https://')) {
          await fetchVideoInfo();
        } else {
          _errorMessage = 'Pasted text is not a valid web link.';
          _state = AppState.error;
          notifyListeners();
        }
      } else {
        _errorMessage = 'Clipboard is empty. Copy a video link first.';
        _state = AppState.error;
        notifyListeners();
      }
    } catch (_) {
      // Gracefully handle browser/device permission restrictions
    }
  }

  int _fetchSequence = 0;

  /// Automatically check and paste on app resume if valid URL found
  Future<void> checkClipboardAuto() async {
    // Browsers forbid unprompted clipboard reading without a user gesture
    if (kIsWeb) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (_isValidVideoUrl(text)) {
        if (urlController.text.trim().isEmpty && _state == AppState.idle) {
          urlController.text = text;
          notifyListeners();
        }
      }
    } catch (_) {
      // Ignored for platform permission security
    }
  }

  /// Fetch video metadata, resolutions, and related videos
  Future<void> fetchVideoInfo([String? customUrl]) async {
    if (_state == AppState.extracting && customUrl == null) return;

    final targetUrl = customUrl ?? urlController.text.trim();
    if (targetUrl.isEmpty) {
      _errorMessage = 'Please enter or paste a video link.';
      _state = AppState.error;
      notifyListeners();
      return;
    }

    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      _errorMessage = 'Please enter a valid link starting with http:// or https://';
      _state = AppState.error;
      notifyListeners();
      return;
    }

    if (customUrl != null) {
      urlController.text = customUrl;
    }

    final currentSeq = ++_fetchSequence;
    _state = AppState.extracting;
    _errorMessage = '';
    notifyListeners();

    try {
      VideoInfo res;
      if (YoutubeLocalExtractorService.isYouTubeUrl(targetUrl)) {
        try {
          res = await _youtubeLocalExtractorService.extract(targetUrl);
        } catch (ytErr) {
          // If client-side extraction failed, try fallback to backend API
          try {
            res = await _apiService.extractVideo(targetUrl);
          } catch (_) {
            rethrow;
          }
        }
      } else {
        res = await _apiService.extractVideo(targetUrl);
      }

      if (currentSeq != _fetchSequence) return;
      _videoInfo = res;
      if (_videoInfo != null && _videoInfo!.qualities.isNotEmpty) {
        _selectedQuality = _videoInfo!.qualities.first;
      }
      _state = AppState.ready;
    } catch (e) {
      if (currentSeq != _fetchSequence) return;
      _errorMessage = AppErrorFormatter.format(e);
      _state = AppState.error;
    }
    notifyListeners();
  }

  /// Start streaming & downloading file directly into phone Gallery
  Future<void> startDownload() async {
    if (_videoInfo == null || _selectedQuality == null) return;

    _state = AppState.downloading;
    _downloadProgress = 0.0;
    _downloadSpeed = '';
    _bytesReceived = 0;
    _bytesTotal = 0;
    _errorMessage = '';
    notifyListeners();

    try {
      final streamUrl = _selectedQuality!.downloadUrl ??
          _apiService.getStreamUrl(
            originalUrl: _videoInfo!.originalUrl,
            formatId: _selectedQuality!.formatId,
            ext: _selectedQuality!.ext,
            isAudioOnly: _selectedQuality!.isAudioOnly,
          );

      int lastUiUpdate = 0;

      final savedPath = await _downloaderService.downloadToGallery(
        downloadUrl: streamUrl,
        title: _videoInfo!.title,
        ext: _selectedQuality!.ext,
        isAudioOnly: _selectedQuality!.isAudioOnly,
        onProgress: (received, total, percent, speed) {
          _bytesReceived = received;
          _bytesTotal = total;
          _downloadProgress = percent;
          _downloadSpeed = speed;

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUiUpdate >= 80 || (total > 0 && received >= total)) {
            lastUiUpdate = now;
            notifyListeners();
          }
        },
      );

      _downloadedFilePath = savedPath;
      _state = AppState.completed;
      notifyListeners();
    } catch (e) {
      final formatted = AppErrorFormatter.format(e);
      if (formatted.toLowerCase().contains('cancel')) {
        _state = AppState.ready;
      } else {
        _errorMessage = formatted;
        _state = AppState.error;
      }
      notifyListeners();
    }
  }

  void cancelDownload() {
    _downloaderService.cancelDownload();
    _state = AppState.ready;
    _downloadProgress = 0.0;
    notifyListeners();
  }

  void reset() {
    urlController.clear();
    _videoInfo = null;
    _selectedQuality = null;
    _state = AppState.idle;
    _errorMessage = '';
    _downloadProgress = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }
}
