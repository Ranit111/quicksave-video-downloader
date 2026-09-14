import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/app_error_formatter.dart';

void main() {
  group('AppErrorFormatter tests', () {
    test('Formats network connection failures', () {
      expect(
        AppErrorFormatter.format('SocketException: OS Error: Connection refused, errno = 111'),
        'Cannot connect to server. Check your network or Wi-Fi.',
      );
      expect(
        AppErrorFormatter.format('ClientException: Failed host lookup: example.com'),
        'Cannot connect to server. Check your network or Wi-Fi.',
      );
    });

    test('Formats timeout errors', () {
      expect(
        AppErrorFormatter.format('TimeoutException: Future timed out after 0:00:45.000000'),
        'Connection timed out. Please try again.',
      );
    });

    test('Formats Dio exceptions', () {
      final reqOptions = RequestOptions(path: '/stream');
      final dioTimeout = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.connectionTimeout,
      );
      expect(
        AppErrorFormatter.format(dioTimeout),
        'Connection timed out. Please try again.',
      );

      final dioBadResp = DioException(
        requestOptions: reqOptions,
        response: Response(requestOptions: reqOptions, statusCode: 404),
        type: DioExceptionType.badResponse,
      );
      expect(
        AppErrorFormatter.format(dioBadResp),
        'Video file was not found on server.',
      );
    });

    test('Formats permission and storage errors', () {
      expect(
        AppErrorFormatter.format('Exception: Storage permission is required to save media.'),
        'Storage permission is required to save to Gallery.',
      );
      expect(
        AppErrorFormatter.format('FileSystemException: Cannot copy file, OS Error: No space left on device, errno = 28'),
        'Device storage is full. Please free up space.',
      );
    });

    test('Formats video availability and restriction errors', () {
      expect(
        AppErrorFormatter.format('This video is private or restricted.'),
        'This video is private or restricted.',
      );
      expect(
        AppErrorFormatter.format('Video not found or has been removed.'),
        'Video not found or has been removed.',
      );
      expect(
        AppErrorFormatter.format('This video is age-restricted and requires sign-in.'),
        'This video is age-restricted and requires sign-in.',
      );
      expect(
        AppErrorFormatter.format('This video is not available in your region.'),
        'This video is not available in your region.',
      );
    });

    test('Fallback cleanses unknown messy technical errors', () {
      const technicalMess = 'Traceback (most recent call last):\n  File "foo.py", line 12\nSomeComplexInternalError';
      expect(
        AppErrorFormatter.format(technicalMess),
        'Could not process video. Check the link and try again.',
      );
    });
  });
}
