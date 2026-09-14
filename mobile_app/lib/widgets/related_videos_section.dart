import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/video_info.dart';
import '../providers/downloader_provider.dart';

class RelatedVideosSection extends StatelessWidget {
  final List<RelatedVideo> relatedVideos;
  final ValueChanged<String> onVideoSelect;

  const RelatedVideosSection({
    super.key,
    required this.relatedVideos,
    required this.onVideoSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (relatedVideos.isEmpty) {
      return const SizedBox.shrink();
    }

    final reloadKey = context.watch<DownloaderProvider>().thumbnailReloadKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.cyanAccent,
              ),
              const SizedBox(width: 6),
              const Text(
                'RELATED VIDEOS YOU MAY LIKE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 185,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: relatedVideos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final video = relatedVideos[index];

              return GestureDetector(
                onTap: () => onVideoSelect(video.url),
                child: Container(
                  width: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.glassSurface,
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail with duration overlay
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _buildThumbnail(context, video, reloadKey),
                            ),
                          ),
                          if (video.durationFormatted != null && video.durationFormatted!.isNotEmpty)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  video.durationFormatted!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (video.uploader != null && video.uploader!.isNotEmpty)
                              Text(
                                video.uploader!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            if (video.viewCountFormatted != null && video.viewCountFormatted!.isNotEmpty)
                              Text(
                                video.viewCountFormatted!,
                                style: const TextStyle(
                                  color: AppColors.cyanAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(BuildContext context, RelatedVideo video, int reloadKey) {
    var rawUrl = (video.thumbnail != null && video.thumbnail!.isNotEmpty)
        ? video.thumbnail!
        : (video.id.isNotEmpty ? 'https://i.ytimg.com/vi/${video.id}/hqdefault.jpg' : '');
    if (rawUrl.contains('vi_webp')) {
      rawUrl = rawUrl.replaceAll('vi_webp', 'vi').replaceAll('.webp', '.jpg');
    }
    final primaryUrl = rawUrl;

    if (primaryUrl.isEmpty) {
      return Container(
        color: AppColors.backgroundSecondary,
        child: const Icon(Icons.movie_outlined, color: AppColors.textMuted),
      );
    }

    return Image.network(
      primaryUrl,
      key: ValueKey('${primaryUrl}_$reloadKey'),
      cacheWidth: 360,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: AppColors.backgroundSecondary,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.purpleAccent,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        final fallbackUrl = 'https://i.ytimg.com/vi/${video.id}/hqdefault.jpg';
        if (video.id.isNotEmpty && primaryUrl != fallbackUrl) {
          return Image.network(
            fallbackUrl,
            key: ValueKey('${fallbackUrl}_$reloadKey'),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: AppColors.backgroundSecondary,
              child: const Icon(Icons.movie_outlined, color: AppColors.textMuted),
            ),
          );
        }
        return Container(
          color: AppColors.backgroundSecondary,
          child: const Icon(Icons.movie_outlined, color: AppColors.textMuted),
        );
      },
    );
  }
}

