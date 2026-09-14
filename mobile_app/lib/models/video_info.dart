class QualityOption {
  final String formatId;
  final String qualityLabel;
  final String? resolution;
  final String ext;
  final int? filesizeApprox;
  final String filesizeFormatted;
  final bool isAudioOnly;
  final String? downloadUrl;

  QualityOption({
    required this.formatId,
    required this.qualityLabel,
    this.resolution,
    required this.ext,
    this.filesizeApprox,
    required this.filesizeFormatted,
    this.isAudioOnly = false,
    this.downloadUrl,
  });

  factory QualityOption.fromJson(Map<String, dynamic> json) {
    return QualityOption(
      formatId: json['format_id'] as String? ?? 'best',
      qualityLabel: json['quality_label'] as String? ?? 'HD',
      resolution: json['resolution'] as String?,
      ext: json['ext'] as String? ?? 'mp4',
      filesizeApprox: json['filesize_approx'] as int?,
      filesizeFormatted: json['filesize_formatted'] as String? ?? 'Instant',
      isAudioOnly: json['is_audio_only'] as bool? ?? false,
      downloadUrl: json['download_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'format_id': formatId,
    'quality_label': qualityLabel,
    'resolution': resolution,
    'ext': ext,
    'filesize_approx': filesizeApprox,
    'filesize_formatted': filesizeFormatted,
    'is_audio_only': isAudioOnly,
    'download_url': downloadUrl,
  };
}

class RelatedVideo {
  final String id;
  final String title;
  final String url;
  final String? thumbnail;
  final String? uploader;
  final String? durationFormatted;
  final String? viewCountFormatted;

  RelatedVideo({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnail,
    this.uploader,
    this.durationFormatted,
    this.viewCountFormatted,
  });

  factory RelatedVideo.fromJson(Map<String, dynamic> json) {
    return RelatedVideo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Suggested Video',
      url: json['url'] as String? ?? '',
      thumbnail: json['thumbnail'] as String?,
      uploader: json['uploader'] as String?,
      durationFormatted: json['duration_formatted'] as String?,
      viewCountFormatted: json['view_count_formatted'] as String?,
    );
  }
}

class VideoInfo {
  final String id;
  final String title;
  final String originalUrl;
  final String? thumbnail;
  final String? uploader;
  final String? uploaderUrl;
  final int? duration;
  final String durationFormatted;
  final String platform;
  final String platformName;
  final List<QualityOption> qualities;
  final List<RelatedVideo> relatedVideos;

  VideoInfo({
    required this.id,
    required this.title,
    required this.originalUrl,
    this.thumbnail,
    this.uploader,
    this.uploaderUrl,
    this.duration,
    required this.durationFormatted,
    required this.platform,
    required this.platformName,
    required this.qualities,
    this.relatedVideos = const [],
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    final qualitiesList = (json['qualities'] as List<dynamic>?)
            ?.map((q) => QualityOption.fromJson(q as Map<String, dynamic>))
            .toList() ??
        [];

    final relatedList = (json['related_videos'] as List<dynamic>?)
            ?.map((r) => RelatedVideo.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];

    return VideoInfo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Video',
      originalUrl: json['original_url'] as String? ?? '',
      thumbnail: json['thumbnail'] as String?,
      uploader: json['uploader'] as String?,
      uploaderUrl: json['uploader_url'] as String?,
      duration: json['duration'] as int?,
      durationFormatted: json['duration_formatted'] as String? ?? '00:00',
      platform: json['platform'] as String? ?? 'other',
      platformName: json['platform_name'] as String? ?? 'Web Video',
      qualities: qualitiesList,
      relatedVideos: relatedList,
    );
  }
}
