import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/video_info.dart';

class ApiService {
  // Default Base URL - Production backend on Render
  static String defaultBaseUrl = 'https://quicksave-video-downloader.onrender.com';

  static String _resolveDefaultUrl() {
    return 'https://quicksave-video-downloader.onrender.com';
  }

  String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client();

  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl.trim().replaceAll(RegExp(r'/+$'), '');
    defaultBaseUrl = baseUrl;
  }

  /// Extract video info, available resolutions and zero-AI related videos
  Future<VideoInfo> extractVideo(String url) async {
    final candidateUrls = <String>[baseUrl];
    if (!kIsWeb && io.Platform.isAndroid) {
      for (final fallback in ['http://10.0.2.2:8000', 'http://192.168.31.76:8000', 'http://127.0.0.1:8000']) {
        if (!candidateUrls.contains(fallback)) {
          candidateUrls.add(fallback);
        }
      }
    }

    dynamic lastError;

    for (final testBaseUrl in candidateUrls) {
      final endpoint = Uri.parse('$testBaseUrl/api/extract');
      try {
        final response = await _client.post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': url.trim()}),
        ).timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          if (testBaseUrl != baseUrl) {
            updateBaseUrl(testBaseUrl);
          }
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return VideoInfo.fromJson(data);
        } else {
          String detailMessage = 'Server error (${response.statusCode})';
          try {
            final errorBody = jsonDecode(response.body);
            if (errorBody is Map && errorBody.containsKey('detail')) {
              detailMessage = errorBody['detail'].toString();
            }
          } catch (_) {}
          throw Exception(detailMessage);
        }
      } catch (e) {
        lastError = e;
        final errStr = e.toString();
        // If it's an explicit server error detail, rethrow immediately
        if (errStr.contains('Exception: ') &&
            !errStr.contains('SocketException') &&
            !errStr.contains('ClientException') &&
            !errStr.contains('Connection') &&
            !errStr.contains('Timeout')) {
          rethrow;
        }
      }
    }

    if (lastError != null) {
      if (lastError is Exception) throw lastError;
      throw Exception(lastError.toString());
    }
    throw Exception('Cannot connect to server. Check your network or Wi-Fi.');
  }

  /// Construct direct download/streaming URL
  String getStreamUrl({
    required String originalUrl,
    required String formatId,
    required String ext,
    bool isAudioOnly = false,
  }) {
    final encodedUrl = Uri.encodeComponent(originalUrl);
    final encodedFormat = Uri.encodeComponent(formatId);
    return '$baseUrl/api/stream?url=$encodedUrl&format_id=$encodedFormat&ext=$ext&audio_only=$isAudioOnly';
  }
}
