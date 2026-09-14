import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/youtube_local_extractor_service.dart';
import 'package:dio/dio.dart';

void main() {
  test('extractVideoId handles all YouTube URL formats', () {
    expect(
      YoutubeLocalExtractorService.extractVideoId(
          'https://youtube.com/shorts/9iOtm7xajGQ?si=tGFMDYsNSbcZbCy8'),
      equals('9iOtm7xajGQ'),
    );
    expect(
      YoutubeLocalExtractorService.extractVideoId(
          'https://www.youtube.com/watch?v=aqz-KE-bpKQ'),
      equals('aqz-KE-bpKQ'),
    );
    expect(
      YoutubeLocalExtractorService.extractVideoId(
          'https://youtu.be/aqz-KE-bpKQ'),
      equals('aqz-KE-bpKQ'),
    );
    expect(
      YoutubeLocalExtractorService.extractVideoId('9iOtm7xajGQ'),
      equals('9iOtm7xajGQ'),
    );
  });

  test('YoutubeLocalExtractorService extracts multiple video & audio qualities with actual sizes', () async {
    final service = YoutubeLocalExtractorService();
    const testUrl = 'https://www.youtube.com/watch?v=aqz-KE-bpKQ';

    final info = await service.extract(testUrl);
    expect(info.title.isNotEmpty, isTrue);
    expect(info.qualities.length, greaterThanOrEqualTo(4));

    // Verify all qualities have actual size formatted (not 'Instant' or '0')
    for (final q in info.qualities) {
      expect(q.filesizeFormatted, isNot('Instant'));
      expect(q.filesizeFormatted, contains('MB'));
      expect(q.downloadUrl, isNotNull);
      expect(q.downloadUrl, startsWith('http'));
    }

    // Verify presence of multiple distinct resolutions
    final videoQualities = info.qualities.where((q) => !q.isAudioOnly).toList();
    expect(videoQualities.length, greaterThanOrEqualTo(3));

    // Verify presence of audio options
    final audioQualities = info.qualities.where((q) => q.isAudioOnly).toList();
    expect(audioQualities.isNotEmpty, isTrue);

    // Test high-speed CDN byte range retrieval
    final downloadUrl = info.qualities.first.downloadUrl!;
    final dio = Dio();
    final response = await dio.get(
      downloadUrl,
      options: Options(
        headers: {
          'Range': 'bytes=0-1048575', // 1 MB chunk test
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        },
        responseType: ResponseType.bytes,
      ),
    );
    expect(response.statusCode, inInclusiveRange(200, 206));
    expect((response.data as List<int>).length, greaterThan(0));
  });

  test('YoutubeLocalExtractorService extracts YouTube Shorts with multiple qualities', () async {
    final service = YoutubeLocalExtractorService();
    const shortsUrl =
        'https://youtube.com/shorts/9iOtm7xajGQ?si=tGFMDYsNSbcZbCy8';

    final info = await service.extract(shortsUrl);
    expect(info.title.isNotEmpty, isTrue);
    expect(info.qualities.isNotEmpty, isTrue);

    for (final q in info.qualities) {
      expect(q.downloadUrl, isNotNull);
      expect(q.filesizeFormatted, isNotEmpty);
    }
  });
}
