import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/video_info.dart';
import '../providers/downloader_provider.dart';
import 'glass_container.dart';

class VideoPreviewCard extends StatelessWidget {
  final VideoInfo videoInfo;

  const VideoPreviewCard({
    super.key,
    required this.videoInfo,
  });

  @override
  Widget build(BuildContext context) {
    final reloadKey = context.watch<DownloaderProvider>().thumbnailReloadKey;

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with duration overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildThumbnail(context, reloadKey),
                ),
              ),
              // Duration Pill
              if (videoInfo.durationFormatted.isNotEmpty)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      videoInfo.durationFormatted,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              // Platform tag pill
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPlatformIcon(videoInfo.platform),
                        size: 14,
                        color: AppColors.cyanAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        videoInfo.platformName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            videoInfo.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),

          // Author / Channel
          if (videoInfo.uploader != null && videoInfo.uploader!.isNotEmpty)
            Row(
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    videoInfo.uploader!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return Icons.play_arrow_rounded;
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'facebook':
        return Icons.facebook;
      case 'sharechat':
        return Icons.share_rounded;
      case 'tiktok':
        return Icons.music_note_rounded;
      default:
        return Icons.public;
    }
  }

  Widget _buildThumbnail(BuildContext context, int reloadKey) {
    var rawUrl = videoInfo.thumbnail ?? '';
    if (rawUrl.contains('vi_webp')) {
      rawUrl = rawUrl.replaceAll('vi_webp', 'vi').replaceAll('.webp', '.jpg');
    }
    final primaryUrl = rawUrl.isNotEmpty
        ? rawUrl
        : (videoInfo.id.isNotEmpty && videoInfo.platform == 'youtube'
            ? 'https://i.ytimg.com/vi/${videoInfo.id}/hqdefault.jpg'
            : '');

    if (primaryUrl.isEmpty) {
      return Container(
        color: AppColors.backgroundSecondary,
        child: const Icon(Icons.movie_outlined, size: 48, color: AppColors.textMuted),
      );
    }

    return Image.network(
      primaryUrl,
      key: ValueKey('${primaryUrl}_$reloadKey'),
      cacheWidth: 720,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: AppColors.backgroundSecondary,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.purpleAccent,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        final isYouTube = videoInfo.platform.toLowerCase() == 'youtube';
        final fallbackUrl = 'https://i.ytimg.com/vi/${videoInfo.id}/hqdefault.jpg';
        if (isYouTube && videoInfo.id.isNotEmpty && primaryUrl != fallbackUrl) {
          return Image.network(
            fallbackUrl,
            key: ValueKey('${fallbackUrl}_$reloadKey'),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: AppColors.backgroundSecondary,
              child: const Icon(Icons.movie_outlined, size: 48, color: AppColors.textMuted),
            ),
          );
        }
        return Container(
          color: AppColors.backgroundSecondary,
          child: const Icon(Icons.movie_outlined, size: 48, color: AppColors.textMuted),
        );
      },
    );
  }
}

