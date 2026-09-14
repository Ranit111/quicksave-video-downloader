import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/downloader_provider.dart';
import '../widgets/app_logo_widget.dart';
import '../widgets/glass_container.dart';
import '../widgets/platform_chips.dart';
import '../widgets/video_preview_card.dart';
import '../widgets/quality_grid.dart';
import '../widgets/related_videos_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloaderProvider>().checkClipboardAuto();
      _initConnectivity();
    });
  }

  void _initConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (isOffline) {
        _wasOffline = true;
      } else if (_wasOffline) {
        // Internet was OFF and is now back ON -> Auto-reload thumbnails!
        _wasOffline = false;
        if (mounted) {
          context.read<DownloaderProvider>().onNetworkRestored();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.wifi_rounded, color: AppColors.cyanAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Internet restored — thumbnails reloaded',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E213D),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<DownloaderProvider>().checkClipboardAuto();
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloaderProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          gradient: LinearGradient(
            colors: [
              Color(0xFF13152C),
              Color(0xFF0D0E1C),
              Color(0xFF090A14),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top App Header
                _buildHeader(provider),
                const SizedBox(height: 20),

                // Search / Paste Link Input
                _buildUrlInput(provider),
                const SizedBox(height: 16),

                // Platform Filter Chips
                PlatformChips(
                  selectedPlatform: provider.selectedPlatformFilter,
                  onSelect: provider.setPlatformFilter,
                ),
                const SizedBox(height: 20),

                // Error Banner
                if (provider.state == AppState.error) ...[
                  _buildErrorBanner(provider),
                  const SizedBox(height: 16),
                ],

                // Extracting Loader
                if (provider.state == AppState.extracting) ...[
                  _buildExtractingLoader(),
                  const SizedBox(height: 20),
                ],

                // Video Info Preview
                if (provider.videoInfo != null) ...[
                  VideoPreviewCard(videoInfo: provider.videoInfo!),
                  const SizedBox(height: 18),

                  // 2x2 Quality Selector Grid
                  QualityGrid(
                    qualities: provider.videoInfo!.qualities,
                    selectedQuality: provider.selectedQuality,
                    onSelect: provider.selectQuality,
                  ),
                  const SizedBox(height: 20),

                  // Download CTA / Progress Tracker
                  _buildDownloadAction(provider),
                  const SizedBox(height: 20),

                  // Success Toast / Banner
                  if (provider.state == AppState.completed) ...[
                    _buildSuccessBanner(provider),
                    const SizedBox(height: 20),
                  ],

                  // Zero-AI Related Videos Section
                  if (provider.videoInfo!.relatedVideos.isNotEmpty) ...[
                    RelatedVideosSection(
                      relatedVideos: provider.videoInfo!.relatedVideos,
                      onVideoSelect: (url) {
                        provider.fetchVideoInfo(url);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServerSettingsDialog(BuildContext context, DownloaderProvider provider) {
    final textController = TextEditingController(text: provider.serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16192E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Backend Server URL',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the API address (e.g. for emulator use 10.0.2.2:8000, for device use your PC LAN IP):',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'http://10.0.2.2:8000',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                provider.updateServerUrl(textController.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purpleAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(DownloaderProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const AppLogoWidget(
              size: 38,
              borderRadius: 12,
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QuickSave',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Instant Media Downloader',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.glassSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 14, color: AppColors.cyanAccent),
              SizedBox(width: 4),
              Text(
                'Direct to Gallery',
                style: TextStyle(
                  color: AppColors.cyanAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUrlInput(DownloaderProvider provider) {
    final platformHint = provider.selectedPlatformFilter != 'all'
        ? '${provider.selectedPlatformFilter[0].toUpperCase()}${provider.selectedPlatformFilter.substring(1)} '
        : '';

    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, color: AppColors.cyanAccent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: provider.urlController,
                  enabled: provider.state != AppState.extracting,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Paste ${platformHint}link here...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: provider.state == AppState.extracting ? null : (_) => provider.fetchVideoInfo(),
                ),
              ),
              if (provider.urlController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  onPressed: provider.reset,
                  splashRadius: 18,
                ),
            ],
          ),
          const Divider(color: AppColors.glassBorder, height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: provider.state == AppState.extracting ? null : provider.pasteFromClipboard,
                icon: const Icon(Icons.content_paste_rounded, size: 16, color: AppColors.purpleAccent),
                label: const Text(
                  'PASTE FROM CLIPBOARD',
                  style: TextStyle(
                    color: AppColors.purpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              ElevatedButton(
                onPressed: provider.state == AppState.extracting ? null : () => provider.fetchVideoInfo(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'Fetch',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtractingLoader() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.purpleAccent,
            ),
          ),
          SizedBox(width: 14),
          Text(
            'Analyzing video & resolutions...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(DownloaderProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1622),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.redError.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.redError, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              provider.errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => provider.clearError(),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadAction(DownloaderProvider provider) {
    if (provider.state == AppState.downloading) {
      final percentStr = (provider.downloadProgress * 100).toStringAsFixed(0);

      return GlassContainer(
        borderRadius: 18,
        padding: const EdgeInsets.all(16),
        isActive: true,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.cyanAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Downloading ($percentStr%)...',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (provider.downloadSpeed.isNotEmpty)
                  Text(
                    provider.downloadSpeed,
                    style: const TextStyle(
                      color: AppColors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: provider.downloadProgress > 0 ? provider.downloadProgress : null,
                minHeight: 8,
                backgroundColor: AppColors.backgroundSecondary,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purpleAccent),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: provider.cancelDownload,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.redError, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AppColors.buttonGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleAccent.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: provider.startDownload,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.file_download_outlined, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              'Instant Download (${provider.selectedQuality?.qualityLabel ?? "HD"})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBanner(DownloaderProvider provider) {
    final locationText = kIsWeb
        ? 'File downloaded to your Downloads folder!'
        : (provider.downloadedFilePath.isNotEmpty
            ? 'Saved to: ${provider.downloadedFilePath}'
            : 'Saved in Downloads folder with zero app storage used.');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSuccess.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.greenSuccess.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.greenSuccess, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Download Complete!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  locationText,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
