import pytest
from app.extractor import detect_platform, format_filesize, extract_qualities, resolve_facebook_url, get_format_selector
from app.main import classify_error
from app.related_service import format_duration, format_view_count

def test_detect_platform():
    assert detect_platform("https://www.youtube.com/watch?v=dQw4w9WgXcQ")[0] == "youtube"
    assert detect_platform("https://youtu.be/dQw4w9WgXcQ")[0] == "youtube"
    assert detect_platform("https://www.instagram.com/reel/C123456789/")[0] == "instagram"
    assert detect_platform("https://www.facebook.com/watch/?v=123456")[0] == "facebook"
    assert detect_platform("https://www.facebook.com/reel/123456789/")[0] == "facebook"
    assert detect_platform("https://sharechat.com/video/abcdef")[0] == "sharechat"
    assert detect_platform("https://www.tiktok.com/@user/video/12345")[0] == "tiktok"
    assert detect_platform("https://x.com/user/status/12345")[0] == "twitter"
    assert detect_platform("https://example.com/video.mp4")[0] == "other"

def test_resolve_facebook_url():
    # Facebook Reels must preserve /reel/<id>
    assert resolve_facebook_url("https://www.facebook.com/reel/1234567890?mibextid=abc") == "https://www.facebook.com/reel/1234567890"
    # Facebook Watch / Videos / Posts canonicalize
    assert resolve_facebook_url("https://www.facebook.com/watch/?v=9876543210") == "https://www.facebook.com/watch/?v=9876543210"
    assert resolve_facebook_url("https://www.facebook.com/username/videos/1122334455/") == "https://www.facebook.com/watch/?v=1122334455"
    assert resolve_facebook_url("https://www.facebook.com/story.php?story_fbid=5566778899&id=100") == "https://www.facebook.com/watch/?v=5566778899"

def test_get_format_selector():
    mp3_sel = get_format_selector("mp3")
    assert "ba" in mp3_sel

    f720 = get_format_selector("720p")
    assert "720" in f720
    assert "bv*" in f720
    assert "best" in f720

    f1080 = get_format_selector("1080p")
    assert "1080" in f1080

def test_format_filesize():
    assert format_filesize(0) == "Instant"
    assert format_filesize(None) == "Instant"
    assert format_filesize(500) == "500 B"
    assert format_filesize(1024 * 500) == "500.0 KB"
    assert format_filesize(1024 * 1024 * 45) == "45.0 MB"
    assert format_filesize(1024 * 1024 * 1024 * 2) == "2.0 GB"

def test_format_duration():
    assert format_duration(0) == "00:00"
    assert format_duration(65) == "01:05"
    assert format_duration(3665) == "01:01:05"

def test_format_view_count():
    assert format_view_count(500) == "500 views"
    assert format_view_count(1500) == "1.5K views"
    assert format_view_count(2500000) == "2.5M views"

def test_extract_qualities_structure():
    mock_info = {
        "id": "test123",
        "title": "Test Title",
        "height": 720,
        "width": 1280,
    }
    qualities = extract_qualities(
        ydl=None,
        info=mock_info,
        duration=180,
        base_stream_endpoint="/api/stream",
        video_id="test123",
        original_url="https://youtube.com/watch?v=test123"
    )

    labels = [q.quality_label for q in qualities]
    assert "1080p Full HD" in labels
    assert "720p HD" in labels
    assert "480p SD" in labels
    assert "Audio MP3" in labels

def test_classify_error():
    assert classify_error(Exception("Video unavailable"))[0] == 404
    assert classify_error(Exception("This video is private"))[0] == 403
    assert classify_error(Exception("HTTP Error 403: Forbidden"))[0] == 403
    assert classify_error(Exception("Unsupported URL"))[0] == 400

