import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/video_info.dart';
import 'glass_container.dart';

class QualityGrid extends StatelessWidget {
  final List<QualityOption> qualities;
  final QualityOption? selectedQuality;
  final ValueChanged<QualityOption> onSelect;

  const QualityGrid({
    super.key,
    required this.qualities,
    required this.selectedQuality,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (qualities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'SELECT QUALITY',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: qualities.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.1,
          ),
          itemBuilder: (context, index) {
            final item = qualities[index];
            final isSelected = selectedQuality?.formatId == item.formatId;

            return GlassContainer(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isActive: isSelected,
              onTap: () => onSelect(item),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.purpleAccent.withValues(alpha: 0.3)
                          : AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.purpleAccent
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Icon(
                      item.isAudioOnly
                          ? Icons.music_note_rounded
                          : Icons.high_quality_rounded,
                      color: isSelected ? Colors.white : AppColors.cyanAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.qualityLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Size: ${item.filesizeFormatted}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.cyanAccent
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
