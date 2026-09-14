import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_info.dart';

class CustomYoutubeHttpClient extends YoutubeHttpClient {
  final String? cookieHeader;

  CustomYoutubeHttpClient({this.cookieHeader, http.Client? client})
      : super(client);

  @override
  Map<String, String> get headers => {
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'accept-language': 'en-US,en;q=0.9',
        'sec-ch-ua':
            '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'none',
        'sec-fetch-user': '?1',
        'upgrade-insecure-requests': '1',
        if (cookieHeader != null && cookieHeader!.isNotEmpty)
          'cookie': cookieHeader!,
      };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Override outdated hardcoded Chrome/96 headers in WatchPage.get
    request.headers['user-agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
    request.headers.remove('User-Agent');

    if (cookieHeader != null && cookieHeader!.isNotEmpty) {
      final existing = request.headers['cookie'] ?? request.headers['Cookie'];
      if (existing == null || existing.isEmpty) {
        request.headers['cookie'] = cookieHeader!;
      } else if (!existing.contains(cookieHeader!)) {
        request.headers['cookie'] = '$existing; $cookieHeader';
      }
      request.headers.remove('Cookie');
    }

    return super.send(request);
  }
}

class YoutubeLocalExtractorService {
  static const String defaultFallbackCookies =
      'PREF=f6=40000000&f7=100&hl=en&tz=UTC&f4=4000000&f5=30000; VISITOR_INFO1_LIVE=sbEqtNq-UVA; VISITOR_PRIVACY_METADATA=CgJJThIEGgAgDw%3D%3D; GPS=1; SOCS=CAI; YSC=msZz_r0hdCs; __Secure-3PSID=g.a000CgnO_-3Qza76-LJ2R7MXYCQFIRdXqOdgguC9fhMHbtsCXtT7oxXQp3OEDCyG4k1kVwY5qAACgYKAQASARUSFQHGX2Mibb2CqWOL6x5iqgpuWk6B-BoVAUF8yKqwBLPjCRbkiB_2pAbgL-Pj0076; __Secure-3PAPISID=S9yN-QW-c8Wc9bdI/AvSmWGhOVEjyjSukB; __Secure-1PSIDTS=sidts-CjUBXMw41Zg9g2C3asjg2LgSDr-bEoyzpDBaC6Zwp6a42vRmDX_Xb6uUJKI8jUjHWafUgqdJPhAA; __Secure-3PSIDTS=sidts-CjUBXMw41Zg9g2C3asjg2LgSDr-bEoyzpDBaC6Zwp6a42vRmDX_Xb6uUJKI8jUjHWafUgqdJPhAA; __Secure-3PSIDCC=AKEyXzU1E5xlbaPO0eosFYHd_7FlqNMzLNEbyMEVmjRtyWqKRs9eY_hkGdhcIJmUd_m4SoeZ1ew';

  final String? _customCookies;

  YoutubeLocalExtractorService({String? customCookies})
      : _customCookies = customCookies ?? defaultFallbackCookies;

  /// Checks if the provided URL is a valid YouTube URL
  static bool isYouTubeUrl(String url) {
    final lower = url.toLowerCase().trim();
    return lower.contains('youtube.com/') ||
        lower.contains('youtu.be/') ||
        lower.contains('m.youtube.com/');
  }

  /// Reliably extracts the 11-character YouTube video ID from any format:
  /// - https://youtube.com/shorts/9iOtm7xajGQ?si=tGFMDYsNSbcZbCy8
  /// - https://www.youtube.com/watch?v=aqz-KE-bpKQ
  /// - https://youtu.be/aqz-KE-bpKQ
  /// - https://m.youtube.com/watch?v=aqz-KE-bpKQ&feature=share
  /// - raw 11-char ID
  static String? extractVideoId(String url) {
    final clean = url.trim();
    if (RegExp(r'^[0-9a-zA-Z_\-]{11}$').hasMatch(clean)) {
      return clean;
    }
    final match = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?|shorts|live)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    ).firstMatch(clean);
    return match?.group(1);
  }

  /// Parses a Netscape cookies.txt string into standard HTTP Cookie header format
  static String? parseNetscapeCookies(String rawContent) {
    final cookies = <String>[];
    for (final line in rawContent.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split('\t');
      if (parts.length >= 7) {
        final name = parts[5].trim();
        final value = parts[6].trim();
        if (name.isNotEmpty) {
          cookies.add('$name=$value');
        }
      }
    }
    return cookies.isNotEmpty ? cookies.join('; ') : null;
  }

  /// Extracts video metadata, muxed streams, audio streams, and related videos client-side
  Future<VideoInfo> extract(String rawUrl) async {
    final videoIdStr = extractVideoId(rawUrl);
    if (videoIdStr == null) {
      throw ArgumentError('Could not extract a valid YouTube video ID from: $rawUrl');
    }

    final videoId = VideoId(videoIdStr);
    final httpClient = CustomYoutubeHttpClient(cookieHeader: _customCookies);
    final yt = YoutubeExplode(httpClient: httpClient);

    try {
      final video = await yt.videos.get(videoId);
      final manifest = await yt.videos.streamsClient.getManifest(videoId);

      final qualities = <QualityOption>[];
      final seenResolutions = <int>{};

      // Collect all video streams (muxed + videoOnly)
      final allVideoStreams = <VideoStreamInfo>[
        ...manifest.muxed,
        ...manifest.videoOnly,
      ];

      // Sort by resolution descending, prefer muxed (video+audio), then mp4 container, then highest bitrate
      allVideoStreams.sort((a, b) {
        final heightA = a.videoResolution.height;
        final heightB = b.videoResolution.height;
        if (heightA != heightB) {
          return heightB.compareTo(heightA);
        }
        final isMuxedA = a is MuxedStreamInfo ? 1 : 0;
        final isMuxedB = b is MuxedStreamInfo ? 1 : 0;
        if (isMuxedA != isMuxedB) {
          return isMuxedB.compareTo(isMuxedA);
        }
        final isMp4A = a.container.name.toLowerCase() == 'mp4' ? 1 : 0;
        final isMp4B = b.container.name.toLowerCase() == 'mp4' ? 1 : 0;
        if (isMp4A != isMp4B) {
          return isMp4B.compareTo(isMp4A);
        }
        return b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond);
      });

      for (final stream in allVideoStreams) {
        final height = stream.videoResolution.height;
        if (seenResolutions.contains(height)) continue;
        seenResolutions.add(height);

        final sizeBytes = stream.size.totalBytes;
        final sizeFormatted = _formatBytes(sizeBytes);
        final label = _getResolutionLabel(height);

        qualities.add(
          QualityOption(
            formatId: 'yt_${stream.tag}',
            qualityLabel: label,
            resolution: '${stream.videoResolution.width}x$height',
            ext: stream.container.name,
            filesizeApprox: sizeBytes,
            filesizeFormatted: sizeFormatted,
            isAudioOnly: false,
            downloadUrl: stream.url.toString(),
          ),
        );
      }

      // Audio-only streams grouped by quality tier (High, Medium, Low)
      final seenAudioTiers = <String>{};
      final sortedAudio = manifest.audioOnly.sortByBitrate().reversed.toList();

      for (final audio in sortedAudio) {
        final kbps = (audio.bitrate.bitsPerSecond / 1000).round();
        final String tier;
        final String tierLabel;
        if (kbps >= 160) {
          tier = 'high';
          tierLabel = 'Audio High (~$kbps kbps)';
        } else if (kbps >= 96) {
          tier = 'standard';
          tierLabel = 'Audio MP3 / M4A ($kbps kbps)';
        } else {
          tier = 'low';
          tierLabel = 'Audio Fast ($kbps kbps)';
        }

        if (seenAudioTiers.contains(tier)) continue;
        seenAudioTiers.add(tier);

        final audioBytes = audio.size.totalBytes;
        qualities.add(
          QualityOption(
            formatId: 'audio_${audio.tag}',
            qualityLabel: tierLabel,
            resolution: null,
            ext: audio.container.name,
            filesizeApprox: audioBytes,
            filesizeFormatted: _formatBytes(audioBytes),
            isAudioOnly: true,
            downloadUrl: audio.url.toString(),
          ),
        );
      }

      // Fallback if no streams matched
      if (qualities.isEmpty && manifest.streams.isNotEmpty) {
        final bestStream = manifest.streams.first;
        qualities.add(
          QualityOption(
            formatId: 'stream_${bestStream.tag}',
            qualityLabel: 'Standard Quality',
            resolution: null,
            ext: bestStream.container.name,
            filesizeApprox: bestStream.size.totalBytes,
            filesizeFormatted: _formatBytes(bestStream.size.totalBytes),
            isAudioOnly: bestStream is AudioOnlyStreamInfo,
            downloadUrl: bestStream.url.toString(),
          ),
        );
      }

      // Format duration
      final duration = video.duration;
      final durationSec = duration?.inSeconds;
      final durationFormatted =
          duration != null ? _formatDuration(duration) : '00:00';

      // Fast non-blocking related video fetch with short timeout
      final relatedVideos = <RelatedVideo>[];
      try {
        final relatedList = await yt.videos
            .getRelatedVideos(video)
            .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
        if (relatedList != null) {
          for (final rel in relatedList.take(6)) {
            final relDuration = rel.duration;
            relatedVideos.add(
              RelatedVideo(
                id: rel.id.value,
                title: rel.title,
                url: 'https://www.youtube.com/watch?v=${rel.id.value}',
                thumbnail: rel.thumbnails.highResUrl,
                uploader: rel.author,
                durationFormatted:
                    relDuration != null ? _formatDuration(relDuration) : null,
              ),
            );
          }
        }
      } catch (_) {
        // Related video fetching is non-critical
      }

      return VideoInfo(
        id: video.id.value,
        title: video.title,
        originalUrl: rawUrl,
        thumbnail: video.thumbnails.maxResUrl.isNotEmpty
            ? video.thumbnails.maxResUrl
            : video.thumbnails.highResUrl,
        uploader: video.author,
        uploaderUrl: video.channelId.value.isNotEmpty
            ? 'https://www.youtube.com/channel/${video.channelId.value}'
            : null,
        duration: durationSec,
        durationFormatted: durationFormatted,
        platform: 'youtube',
        platformName: 'YouTube',
        qualities: qualities,
        relatedVideos: relatedVideos,
      );
    } finally {
      yt.close();
    }
  }

  static String _getResolutionLabel(int height) {
    if (height >= 2160) return '4K (2160p)';
    if (height >= 1440) return '2K (1440p)';
    if (height >= 1080) return 'Full HD (1080p)';
    if (height >= 720) return 'HD (720p)';
    if (height >= 480) return 'SD (480p)';
    if (height >= 360) return 'SD (360p)';
    return '${height}p';
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Instant';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(1)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
