import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class PlatformItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const PlatformItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class PlatformChips extends StatelessWidget {
  final String selectedPlatform;
  final ValueChanged<String> onSelect;

  const PlatformChips({
    super.key,
    required this.selectedPlatform,
    required this.onSelect,
  });

  static const List<PlatformItem> platforms = [
    PlatformItem(
      id: 'youtube',
      name: 'YouTube',
      icon: Icons.play_arrow_rounded,
      color: Color(0xFFFF0000),
    ),
    PlatformItem(
      id: 'instagram',
      name: 'Instagram',
      icon: Icons.camera_alt_outlined,
      color: Color(0xFFE1306C),
    ),
    PlatformItem(
      id: 'facebook',
      name: 'Facebook',
      icon: Icons.facebook,
      color: Color(0xFF1877F2),
    ),
    PlatformItem(
      id: 'sharechat',
      name: 'ShareChat',
      icon: Icons.share_rounded,
      color: Color(0xFF25D366),
    ),
    PlatformItem(
      id: 'tiktok',
      name: 'TikTok',
      icon: Icons.music_note_rounded,
      color: Color(0xFF00F2FE),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: platforms.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = platforms[index];
          final isSelected = selectedPlatform == item.id;

          return GestureDetector(
            onTap: () => onSelect(isSelected ? 'all' : item.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isSelected
                    ? item.color.withValues(alpha: 0.2)
                    : AppColors.glassSurface,
                border: Border.all(
                  color: isSelected
                      ? item.color
                      : AppColors.glassBorder,
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: item.color.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    color: isSelected ? item.color : AppColors.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
