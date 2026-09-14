import 'package:dio/dio.dart';

class AppErrorFormatter {
  /// Transforms any runtime exception, network error, or backend error
  /// into a clean, concise, 1-line user-friendly explanation.
  static String format(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';

    // Extract raw string message
    String raw = error.toString().trim();

    // Strip common prefixes
    raw = raw.replaceFirst(RegExp(r'^(Exception|Error|ClientException|DioException):\s*', caseSensitive: false), '');
    raw = raw.replaceFirst(RegExp(r'^\[.*?\]\s*'), '');

    // Handle Dio specific errors (during download streaming)
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timed out. Please try again.';
        case DioExceptionType.connectionError:
          return 'Cannot connect to server. Check your network or Wi-Fi.';
        case DioExceptionType.cancel:
          return 'Download cancelled.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 404) return 'Video file was not found on server.';
          if (statusCode == 403) return 'This video is private or restricted.';
          if (statusCode == 500) return 'Server failed to process download. Please try again.';
          return 'Download failed (Server error $statusCode).';
        default:
          break;
      }
    }

    final lower = raw.toLowerCase();

    // 1. Connectivity / Network issues
    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection reset') ||
        lower.contains('broken pipe') ||
        lower.contains('clientexception') ||
        lower.contains('errno = 111') ||
        lower.contains('errno = 110') ||
        lower.contains('failed to connect') ||
        lower.contains('cannot connect to server')) {
      return 'Cannot connect to server. Check your network or Wi-Fi.';
    }

    // 2. Timeout issues
    if (lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return 'Connection timed out. Please try again.';
    }

    // 3. Storage and Permissions
    if (lower.contains('permission') || lower.contains('denied')) {
      return 'Storage permission is required to save to Gallery.';
    }
    if (lower.contains('enospc') || lower.contains('no space') || lower.contains('disk full')) {
      return 'Device storage is full. Please free up space.';
    }

    // 4. Input URL validation
    if (lower.contains('enter or paste') || lower.contains('url cannot be empty')) {
      return 'Please enter or paste a video link first.';
    }
    if (lower.contains('start with http') || lower.contains('valid link')) {
      return 'Please enter a valid link starting with http:// or https://';
    }
    if (lower.contains('not supported') || lower.contains('unsupported')) {
      return 'This video link or website is not supported.';
    }

    // 5. Video Availability / Restrictions
    if (lower.contains('age-restricted') || lower.contains('confirm your age') || lower.contains('sign in to confirm')) {
      return 'This video is age-restricted and requires sign-in.';
    }
    if (lower.contains('region') || lower.contains('country') || lower.contains('geo-restricted')) {
      return 'This video is not available in your region.';
    }
    if (lower.contains('private')) {
      return 'This video is private or restricted.';
    }
    if (lower.contains('not found') || lower.contains('removed') || lower.contains('deleted') || lower.contains('unavailable')) {
      return 'Video not found or has been removed.';
    }
    if (lower.contains('restricted')) {
      return 'This video is private or restricted.';
    }
    if (lower.contains('live stream')) {
      return 'Live streams cannot be downloaded until finished.';
    }
    if (lower.contains('drm')) {
      return 'This video is DRM protected and cannot be downloaded.';
    }
    if (lower.contains('no video found') || lower.contains('no downloadable video')) {
      return 'No downloadable video found in this link.';
    }

    // 6. Clean direct messages (if the message is already short and human-readable, <= 70 chars)
    if (!raw.contains('\n') && !raw.contains('{') && !raw.contains('<') && !raw.contains('Instance of') && raw.length <= 70) {
      return raw;
    }

    // Fallback default
    return 'Could not process video. Check the link and try again.';
  }
}
