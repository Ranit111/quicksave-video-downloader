import http.client
import logging
import os
import re
import tempfile
import urllib.parse
from typing import List, Optional, Tuple
import yt_dlp
from app.models import QualityOption, VideoInfoResponse
from app.related_service import fetch_related_videos, format_duration

logger = logging.getLogger(__name__)

def get_cookies_file() -> Optional[str]:
    """
    Finds or generates a valid cookies.txt path from environment variables,
    backend/cookies.txt, root cookies.txt, or working directory.
    """
    # 1. Direct environment variable path
    env_path = os.environ.get("COOKIES_FILE") or os.environ.get("YTDLP_COOKIES_FILE")
    if env_path and os.path.isfile(env_path) and os.path.getsize(env_path) > 0:
        return os.path.abspath(env_path)

    # 2. Raw cookies content passed in environment variable (useful on Render/Cloud hosts)
    cookies_content = (
        os.environ.get("COOKIES_CONTENT")
        or os.environ.get("YTDLP_COOKIES")
        or os.environ.get("YOUTUBE_COOKIES")
        or os.environ.get("COOKIE_CONTENT")
    )
    if cookies_content and len(cookies_content.strip()) > 20:
        try:
            normalized_cookies = cookies_content.strip()
            # Handle escaped newlines / tabs from single-line dashboard input fields
            if "\\n" in normalized_cookies:
                normalized_cookies = (
                    normalized_cookies.replace("\\r\\n", "\n")
                    .replace("\\n", "\n")
                    .replace("\\t", "\t")
                )

            # Ensure Netscape header format if raw cookie records were provided
            if not normalized_cookies.startswith("#"):
                normalized_cookies = "# Netscape HTTP Cookie File\n" + normalized_cookies

            temp_cookie_path = os.path.join(tempfile.gettempdir(), "quicksave_env_cookies.txt")
            with open(temp_cookie_path, "w", encoding="utf-8") as f:
                f.write(normalized_cookies + "\n")
            return temp_cookie_path
        except Exception as e:
            logger.warning(f"Error writing env cookies: {e}")

    # 3. Candidate file paths on disk
    base_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(base_dir, "..", "cookies.txt"),           # backend/cookies.txt
        os.path.join(base_dir, "..", "..", "cookies.txt"),      # root/cookies.txt
        os.path.join(os.getcwd(), "cookies.txt"),              # ./cookies.txt
        os.path.join(os.getcwd(), "backend", "cookies.txt"),   # ./backend/cookies.txt
        "/app/cookies.txt",                                    # Docker /app/cookies.txt
        "/app/backend/cookies.txt",                            # Docker /app/backend/cookies.txt
        "/opt/render/project/src/cookies.txt",                 # Render /opt/render/project/src/cookies.txt
        "/opt/render/project/src/backend/cookies.txt",         # Render /opt/render/project/src/backend/cookies.txt
    ]

    for cand in candidates:
        norm_path = os.path.normpath(cand)
        if os.path.isfile(norm_path) and os.path.getsize(norm_path) > 0:
            return norm_path

    return None


def detect_platform(url: str) -> Tuple[str, str]:
    url_lower = url.lower()
    if "youtube.com" in url_lower or "youtu.be" in url_lower:
        return "youtube", "YouTube"
    elif "instagram.com" in url_lower or "instagr.am" in url_lower:
        return "instagram", "Instagram"
    elif "facebook.com" in url_lower or "fb.watch" in url_lower or "fb.com" in url_lower:
        return "facebook", "Facebook"
    elif "sharechat.com" in url_lower:
        return "sharechat", "ShareChat"
    elif "tiktok.com" in url_lower:
        return "tiktok", "TikTok"
    elif "twitter.com" in url_lower or "x.com" in url_lower:
        return "twitter", "X (Twitter)"
    elif "reddit.com" in url_lower:
        return "reddit", "Reddit"
    return "other", "Web Video"

def resolve_facebook_url(url: str, max_redirects: int = 5) -> str:
    """
    Resolves Facebook share links (/share/v/, /share/r/, /share/p/, fb.watch, fb.me)
    and canonicalizes Facebook video and Reel URLs for yt-dlp compatibility.
    """
    current_url = url.strip()
    if not current_url:
        return current_url

    # Clean tracking query parameters but preserve video query parameters like 'v', 'story_fbid', 'id'
    parsed = urllib.parse.urlparse(current_url)
    if "facebook.com" in parsed.netloc.lower() or "fb.watch" in parsed.netloc.lower() or "fb.me" in parsed.netloc.lower():
        # Check direct reel format: /reel/<id>
        reel_match = re.search(r'facebook\.com/reel/(\d+)', current_url, re.IGNORECASE)
        if reel_match:
            reel_id = reel_match.group(1)
            return f"https://www.facebook.com/reel/{reel_id}"

        # Check direct watch format: /watch/?v=<id>
        watch_match = re.search(r'facebook\.com/watch/?\?(?:.*&)?v=(\d+)', current_url, re.IGNORECASE)
        if watch_match:
            return f"https://www.facebook.com/watch/?v={watch_match.group(1)}"

        # Check /videos/<id> format
        video_match = re.search(r'facebook\.com/(?:[^/]+/)?videos/(?:[^/]+/)?(\d+)', current_url, re.IGNORECASE)
        if video_match:
            return f"https://www.facebook.com/watch/?v={video_match.group(1)}"

        # Check /posts/<id> format
        post_match = re.search(r'facebook\.com/(?:[^/]+/)?posts/(?:[^/]+/)?(\d+)', current_url, re.IGNORECASE)
        if post_match:
            return f"https://www.facebook.com/watch/?v={post_match.group(1)}"

        # Check story_fbid or fbid format
        story_match = re.search(r'(?:story_fbid|fbid)=(\d+)', current_url, re.IGNORECASE)
        if story_match:
            return f"https://www.facebook.com/watch/?v={story_match.group(1)}"

    # Follow redirects for share links (share/r, share/v, share/p, fb.watch, fb.me)
    is_share = any(s in current_url.lower() for s in ["/share/", "fb.watch", "fb.me"])
    if not is_share:
        return current_url

    mobile_ua = (
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
    )

    cookies = {}

    for _ in range(max_redirects):
        try:
            parsed = urllib.parse.urlparse(current_url)
            if not parsed.netloc:
                break

            conn_cls = http.client.HTTPSConnection if parsed.scheme == "https" else http.client.HTTPConnection
            conn = conn_cls(parsed.netloc, timeout=6)
            path = parsed.path or "/"
            if parsed.query:
                path += "?" + parsed.query

            headers = {
                "Host": parsed.netloc,
                "User-Agent": mobile_ua,
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.9",
                "Referer": "https://www.facebook.com/",
            }
            if cookies:
                headers["Cookie"] = "; ".join(f"{k}={v}" for k, v in cookies.items())

            conn.request("GET", path, headers=headers)
            resp = conn.getresponse()

            # Track session cookies
            raw_cookies = resp.getheader('Set-Cookie')
            if raw_cookies:
                for part in raw_cookies.split(','):
                    c_part = part.split(';')[0].strip()
                    if '=' in c_part:
                        k, v = c_part.split('=', 1)
                        cookies[k.strip()] = v.strip()

            loc = resp.getheader("Location")
            if loc:
                next_url = urllib.parse.urljoin(current_url, loc)
                current_url = next_url
                rm = re.search(r'facebook\.com/reel/(\d+)', current_url, re.IGNORECASE)
                if rm:
                    return f"https://www.facebook.com/reel/{rm.group(1)}"
                wm = re.search(r'facebook\.com/watch/?\?(?:.*&)?v=(\d+)', current_url, re.IGNORECASE)
                if wm:
                    return f"https://www.facebook.com/watch/?v={wm.group(1)}"
                vm = re.search(r'facebook\.com/(?:[^/]+/)?videos/(?:[^/]+/)?(\d+)', current_url, re.IGNORECASE)
                if vm:
                    return f"https://www.facebook.com/watch/?v={vm.group(1)}"
                pm = re.search(r'facebook\.com/(?:[^/]+/)?posts/(?:[^/]+/)?(\d+)', current_url, re.IGNORECASE)
                if pm:
                    return f"https://www.facebook.com/watch/?v={pm.group(1)}"
                continue

            chunk = resp.read(65536).decode("utf-8", errors="ignore")
            reel_match = re.search(r'/reel/(\d+)', chunk) or re.search(r'["\']reel_id["\']\s*:\s*["\'](\d+)["\']', chunk)
            if reel_match:
                return f"https://www.facebook.com/reel/{reel_match.group(1)}"

            vid_match = re.search(r'["\']video_id["\']\s*:\s*["\'](\d+)["\']', chunk) or \
                        re.search(r'video_id=(\d+)', chunk) or \
                        re.search(r'/watch/\?v=(\d+)', chunk) or \
                        re.search(r'/videos/(\d+)', chunk)
            if vid_match:
                return f"https://www.facebook.com/watch/?v={vid_match.group(1)}"

            og_match = re.search(r'property=["\']og:url["\']\s+content=["\']([^"\']+)["\']', chunk, re.I) or \
                       re.search(r'content=["\']([^"\']+)["\']\s+property=["\']og:url["\']', chunk, re.I)
            if og_match:
                og_url = og_match.group(1)
                og_reel = re.search(r'facebook\.com/reel/(\d+)', og_url, re.I)
                if og_reel:
                    return f"https://www.facebook.com/reel/{og_reel.group(1)}"
                og_v = re.search(r'[?&]v=(\d+)', og_url, re.I)
                if og_v:
                    return f"https://www.facebook.com/watch/?v={og_v.group(1)}"
                og_vid = re.search(r'/videos/(\d+)', og_url, re.I)
                if og_vid:
                    return f"https://www.facebook.com/watch/?v={og_vid.group(1)}"

            break
        except Exception:
            break

    return current_url

def format_filesize(bytes_val: Optional[int]) -> str:
    if not bytes_val or bytes_val <= 0:
        return "Instant"
    if bytes_val >= 1024 * 1024 * 1024:
        return f"{bytes_val / (1024 * 1024 * 1024):.1f} GB"
    elif bytes_val >= 1024 * 1024:
        return f"{bytes_val / (1024 * 1024):.1f} MB"
    elif bytes_val >= 1024:
        return f"{bytes_val / 1024:.1f} KB"
    return f"{bytes_val} B"

def get_format_selector(quality_tag: str, is_vertical: bool = False) -> str:
    if quality_tag == "mp3":
        return "ba[ext=m4a]/ba/b/bestaudio/best"
    res_map = {
        "2160p": 2160,
        "1440p": 1440,
        "1080p": 1080,
        "720p": 720,
        "480p": 480,
        "360p": 360,
        "240p": 240,
    }
    target_res = res_map.get(quality_tag)
    if not target_res:
        return quality_tag
    dim = "width" if is_vertical else "height"
    return (
        f"bv*[vcodec^=avc1][{dim}<={target_res}]+ba[ext=m4a]/"
        f"bv*[{dim}<={target_res}]+ba[ext=m4a]/"
        f"bv*[{dim}<={target_res}]+ba/"
        f"b[{dim}<={target_res}]/"
        f"best[{dim}<={target_res}]/"
        f"bv*[{dim}<={target_res}]/"
        f"bv*+ba/best/b"
    )

TARGET_QUALITY_TIERS = [
    (2160, "4K Ultra HD", "2160p"),
    (1440, "2K Quad HD", "1440p"),
    (1080, "1080p Full HD", "1080p"),
    (720, "720p HD", "720p"),
    (480, "480p SD", "480p"),
    (360, "360p", "360p"),
]

def extract_qualities(
    ydl: Optional[yt_dlp.YoutubeDL],
    info: dict,
    duration: Optional[int],
    base_stream_endpoint: str,
    video_id: str,
    original_url: str
) -> List[QualityOption]:
    options: List[QualityOption] = []
    encoded_url = urllib.parse.quote(original_url, safe='')

    is_vertical = (info.get("height") or 0) > (info.get("width") or 0)
    dim = "width" if is_vertical else "height"
    formats = info.get("formats", [])
    dur = duration or info.get("duration")

    # Find best audio stream and its size
    audio_formats = [
        f for f in formats
        if f.get("vcodec") == "none" and f.get("acodec") and f.get("acodec") != "none"
    ]
    best_a = max(audio_formats, key=lambda f: f.get("abr") or f.get("tbr") or 0) if audio_formats else None
    a_size = 0
    if best_a:
        a_size = best_a.get("filesize") or best_a.get("filesize_approx") or 0
        if not a_size and best_a.get("abr") and dur:
            a_size = int((best_a["abr"] * 1000 / 8) * dur)
        elif not a_size and best_a.get("tbr") and dur:
            a_size = int((best_a["tbr"] * 1000 / 8) * dur)

    # Filter video formats
    v_formats = [f for f in formats if f.get("vcodec") != "none" and (f.get(dim) or 0) > 0]
    if not v_formats:
        v_formats = [f for f in formats if (f.get(dim) or 0) > 0]
    if not v_formats and formats:
        v_formats = formats
    if not v_formats and (info.get(dim) or 0) > 0:
        v_formats = [info]

    max_dim = max((f.get(dim) or 0) for f in v_formats) if v_formats else (info.get(dim) or 720)
    if max_dim <= 0:
        max_dim = 720

    # Determine max resolution stream size for scaling fallback
    max_res_fmt = max(v_formats, key=lambda f: (f.get(dim) or 0, f.get('tbr') or 0)) if v_formats else {}
    max_res_size = max_res_fmt.get('filesize') or max_res_fmt.get('filesize_approx') or 0
    if not max_res_size and (max_res_fmt.get('tbr') or max_res_fmt.get('vbr')) and dur:
        bitrate = max_res_fmt.get('tbr') or max_res_fmt.get('vbr')
        max_res_size = int((bitrate * 1000 / 8) * dur)
    if not max_res_size:
        default_bitrate = {2160: 16000, 1440: 8000, 1080: 3500, 720: 1800, 480: 900, 360: 500}.get(max_dim, 2000)
        max_res_size = int((default_bitrate * 1000 / 8) * (dur or 60))

    seen_resolutions = set()

    for target_res, label, quality_tag in TARGET_QUALITY_TIERS:
        # Don't add tiers higher than what the video actually provides (avoids fake 4K/2K on 1080p videos)
        if max_dim < target_res * 0.85:
            continue

        # Look for formats whose dimension matches this tier bracket
        candidates = [f for f in v_formats if target_res * 0.85 <= (f.get(dim) or 0) <= target_res * 1.15]

        if candidates:
            def rank_fmt(f):
                is_mp4 = 1 if f.get("ext") == "mp4" else 0
                is_avc = 1 if (f.get("vcodec") or "").startswith("avc1") else 0
                sz = f.get("filesize") or f.get("filesize_approx") or 0
                tbr = f.get("tbr") or f.get("vbr") or 0
                return (is_avc, is_mp4, sz > 0, tbr)

            best_v = max(candidates, key=rank_fmt)
            matched_res = best_v.get(dim) or target_res

            # Prevent duplicate options with identical stream resolution
            if matched_res in seen_resolutions:
                continue
            seen_resolutions.add(matched_res)

            v_size = best_v.get("filesize") or best_v.get("filesize_approx") or 0
            if not v_size and (best_v.get("tbr") or best_v.get("vbr")) and dur:
                bitrate = best_v.get("tbr") or best_v.get("vbr")
                v_size = int((bitrate * 1000 / 8) * dur)

            # Total downloaded size (sum video + audio if separate streams)
            total_bytes = v_size + (a_size if best_v.get("acodec") == "none" else 0)
        else:
            # Scaled size fallback for lower tier
            matched_res = target_res
            if matched_res in seen_resolutions:
                continue
            seen_resolutions.add(matched_res)
            scale = (target_res / max_dim) ** 1.45
            total_bytes = max(int(max_res_size * scale), 1024 * 300)

        if total_bytes <= 0:
            bitrate_est = {2160: 12000, 1440: 6000, 1080: 3000, 720: 1500, 480: 800, 360: 450}.get(matched_res, 1000)
            d = dur if dur and dur > 0 else 60
            total_bytes = int((bitrate_est * 1000 / 8) * d)

        stream_url = f"{base_stream_endpoint}?url={encoded_url}&format_id={quality_tag}&ext=mp4"

        options.append(QualityOption(
            format_id=quality_tag,
            quality_label=label,
            resolution=f"{matched_res}p",
            ext="mp4",
            filesize_approx=total_bytes,
            filesize_formatted=format_filesize(total_bytes),
            is_audio_only=False,
            download_url=stream_url
        ))

    # Fallback if no standard tier matched (e.g. single format with unusual resolution)
    if not options and v_formats:
        best_v = max(v_formats, key=lambda f: f.get(dim) or 0)
        matched_res = best_v.get(dim) or 720
        v_size = best_v.get("filesize") or best_v.get("filesize_approx") or 0
        if not v_size and (best_v.get("tbr") or best_v.get("vbr")) and dur:
            bitrate = best_v.get("tbr") or best_v.get("vbr")
            v_size = int((bitrate * 1000 / 8) * dur)
        total_bytes = v_size + (a_size if best_v.get("acodec") == "none" else 0)
        stream_url = f"{base_stream_endpoint}?url={encoded_url}&format_id=720p&ext=mp4"

        options.append(QualityOption(
            format_id="720p",
            quality_label=f"{matched_res}p HD" if matched_res >= 720 else f"{matched_res}p",
            resolution=f"{matched_res}p",
            ext="mp4",
            filesize_approx=total_bytes,
            filesize_formatted=format_filesize(total_bytes),
            is_audio_only=False,
            download_url=stream_url
        ))

    # Audio MP3
    audio_bytes = a_size if a_size > 0 else int((192 * 1000 / 8) * (dur or 60))
    audio_stream_url = f"{base_stream_endpoint}?url={encoded_url}&format_id=mp3&ext=mp3&audio_only=true"

    options.append(QualityOption(
        format_id="mp3",
        quality_label="Audio MP3",
        resolution="Audio 320k",
        ext="mp3",
        filesize_approx=audio_bytes,
        filesize_formatted=format_filesize(audio_bytes),
        is_audio_only=True,
        download_url=audio_stream_url
    ))

    return options

def extract_info(url: str, base_url: str = "") -> VideoInfoResponse:
    target_url = url.strip()
    platform_key, platform_name = detect_platform(target_url)

    # Resolve Facebook specific share links and reels
    if platform_key == "facebook":
        target_url = resolve_facebook_url(target_url)

    candidates = [target_url]
    if platform_key == "facebook":
        if "www.facebook.com" in target_url:
            candidates.append(target_url.replace("www.facebook.com", "m.facebook.com"))
        elif "facebook.com" in target_url and "m.facebook.com" not in target_url:
            candidates.append(re.sub(r'https?://(?:www\.)?facebook\.com', 'https://m.facebook.com', target_url))

    cookie_file = get_cookies_file()

    po_token = os.environ.get("PO_TOKEN") or os.environ.get("YOUTUBE_PO_TOKEN")
    visitor_data = os.environ.get("VISITOR_DATA") or os.environ.get("YOUTUBE_VISITOR_DATA")

    yt_extra_args = {}
    if po_token:
        yt_extra_args["po_token"] = [f"web+{po_token}" if not po_token.startswith("web+") else po_token]
    if visitor_data:
        yt_extra_args["visitor_data"] = [visitor_data]

    # Build fallback option sets for maximum resilience across cloud/datacenter IPs
    option_sets = []

    # 1. TOP PRIORITY: Authenticated Session Cookies with VisionOS + Web (gives all 4K, 2K, 1080p, 720p, 480p, 360p)
    if cookie_file:
        logger.info(f"Using authenticated cookies from: {cookie_file}")
        option_sets.append({
            "cookiefile": cookie_file,
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "socket_timeout": 15,
            "extract_flat": False,
            "no_color": True,
            "nocheckcertificate": True,
            "extractor_args": {
                "youtube": {
                    "player_client": ["visionos", "web"],
                    **yt_extra_args,
                }
            }
        })
        option_sets.append({
            "cookiefile": cookie_file,
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "socket_timeout": 15,
            "extract_flat": False,
            "no_color": True,
            "nocheckcertificate": True,
            "extractor_args": {
                "youtube": {
                    "player_client": ["visionos"],
                    **yt_extra_args,
                }
            }
        })

    # 2. VisionOS pure native engine (bypasses bot challenges and provides all 4K, 2K, 1080p, 720p, 480p, 360p)
    option_sets.append({
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "socket_timeout": 15,
        "extract_flat": False,
        "no_color": True,
        "nocheckcertificate": True,
        "extractor_args": {
            "youtube": {
                "player_client": ["visionos", "web"],
                **yt_extra_args,
            }
        }
    })

    # 3. VisionOS pure native HLS client
    option_sets.append({
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "socket_timeout": 15,
        "extract_flat": False,
        "no_color": True,
        "nocheckcertificate": True,
        "extractor_args": {
            "youtube": {
                "player_client": ["visionos"],
                **yt_extra_args,
            }
        }
    })

    # 4. Android + Web fallback
    option_sets.append({
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "socket_timeout": 15,
        "extract_flat": False,
        "no_color": True,
        "nocheckcertificate": True,
        "extractor_args": {
            "youtube": {
                "player_client": ["android", "web"],
                **yt_extra_args,
            }
        }
    })

    # 5. Standard default
    option_sets.append({
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "socket_timeout": 15,
        "extract_flat": False,
        "no_color": True,
        "nocheckcertificate": True,
    })

    info = None
    last_err = None
    successful_url = target_url

    for opts in option_sets:
        if info:
            break
        for cand_url in candidates:
            try:
                with yt_dlp.YoutubeDL(opts) as ydl:
                    extracted = ydl.extract_info(cand_url, download=False)
                    if extracted:
                        info = extracted
                        successful_url = cand_url
                        break
            except Exception as e:
                last_err = e
                continue

    if not info:
        if last_err:
            raise last_err
        raise ValueError("Could not extract video details from URL.")

    if "entries" in info:
        entries = [e for e in info["entries"] if e]
        if not entries:
            raise ValueError("No video entries found in URL.")
        info = entries[0]

    video_id = str(info.get("id", "video"))
    title = info.get("title") or "Video Download"
    title = re.sub(r'[\\/*?:"<>|]', "", title).strip()

    raw_duration = info.get("duration")
    duration = int(round(raw_duration)) if (raw_duration is not None and isinstance(raw_duration, (int, float))) else None
    duration_fmt = format_duration(duration)

    thumbnail = info.get("thumbnail")
    if not thumbnail and info.get("thumbnails"):
        thumbnail = info["thumbnails"][-1].get("url")

    # Guarantee high-res CORS-enabled JPEG for YouTube videos
    if platform_key == "youtube" and video_id and re.match(r'^[a-zA-Z0-9_-]{11}$', video_id):
        thumbnail = f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"
    elif thumbnail and "vi_webp" in thumbnail:
        thumbnail = thumbnail.replace("vi_webp", "vi").replace(".webp", ".jpg")
    elif platform_key == "facebook" and not thumbnail:
        thumbnail = "https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=600&auto=format&fit=crop&q=60"

    uploader = info.get("uploader") or info.get("channel") or info.get("creator") or platform_name
    uploader_url = info.get("uploader_url") or info.get("channel_url")

    formats = info.get("formats") or []
    base_stream_endpoint = f"{base_url}/api/stream" if base_url else "/api/stream"

    qualities = extract_qualities(
        ydl=None,
        info=info,
        duration=duration,
        base_stream_endpoint=base_stream_endpoint,
        video_id=video_id,
        original_url=target_url
    )

    try:
        related_videos = fetch_related_videos(info, max_results=4)
    except Exception:
        related_videos = []

    return VideoInfoResponse(
        id=video_id,
        title=title,
        original_url=url,
        thumbnail=thumbnail,
        uploader=uploader,
        uploader_url=uploader_url,
        duration=duration,
        duration_formatted=duration_fmt,
        platform=platform_key,
        platform_name=platform_name,
        qualities=qualities,
        related_videos=related_videos
    )
