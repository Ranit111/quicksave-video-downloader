import logging
import re
from typing import List, Optional
import yt_dlp
from app.models import RelatedVideo

logger = logging.getLogger(__name__)

def format_duration(seconds: Optional[int]) -> str:
    if not seconds:
        return "00:00"
    try:
        m, s = divmod(int(seconds), 60)
        h, m = divmod(m, 60)
        if h > 0:
            return f"{h:02d}:{m:02d}:{s:02d}"
        return f"{m:02d}:{s:02d}"
    except Exception:
        return "00:00"

def format_view_count(views: Optional[int]) -> str:
    if not views:
        return ""
    try:
        if views >= 1_000_000:
            return f"{views / 1_000_000:.1f}M views"
        elif views >= 1_000:
            return f"{views / 1_000:.1f}K views"
        return f"{views} views"
    except Exception:
        return ""

def fetch_related_videos(raw_info: dict, max_results: int = 4) -> List[RelatedVideo]:
    """
    Ultra-fast Zero-AI related videos fetcher:
    1. Checks if the extractor already extracted platform native recommendations.
    2. Otherwise uses ultra-fast flat search with 5s timeout.
    """
    related: List[RelatedVideo] = []
    video_id = str(raw_info.get("id", ""))

    # 1. Native platform recommendations if already in metadata
    if "recommendations" in raw_info and isinstance(raw_info["recommendations"], list):
        for item in raw_info["recommendations"][:max_results]:
            item_id = str(item.get("id") or item.get("url") or "")
            if not item_id or item_id == video_id:
                continue
            rec_thumb = item.get("thumbnail")
            if len(item_id) == 11 and re.match(r'^[a-zA-Z0-9_-]{11}$', item_id):
                rec_thumb = f"https://i.ytimg.com/vi/{item_id}/hqdefault.jpg"
            elif not rec_thumb and item.get("thumbnails"):
                rec_thumb = item["thumbnails"][-1].get("url")
            if rec_thumb and "vi_webp" in rec_thumb:
                rec_thumb = rec_thumb.replace("vi_webp", "vi").replace(".webp", ".jpg")

            related.append(RelatedVideo(
                id=item_id,
                title=item.get("title", "Related Video"),
                url=item.get("webpage_url") or item.get("url") or f"https://www.youtube.com/watch?v={item_id}",
                thumbnail=rec_thumb,
                uploader=item.get("uploader") or item.get("channel"),
                duration_formatted=format_duration(item.get("duration")),
                view_count_formatted=format_view_count(item.get("view_count"))
            ))

    if len(related) >= 3:
        return related[:max_results]

    # 2. Build clean search query candidates
    tags = raw_info.get("tags") or []
    uploader = raw_info.get("uploader") or raw_info.get("channel") or ""
    title = raw_info.get("title", "")

    cleaned_title = re.sub(r'[^\w\s]', ' ', title, flags=re.UNICODE)
    stop_words = {'day', 'the', 'and', 'for', 'with', 'this', 'that', 'from', 'these', 'those', 'video', 'shorts', 'short'}
    words = [w for w in cleaned_title.split() if len(w) > 1 and not w.isdigit() and w.lower() not in stop_words]
    meaningful = words[:3]
    clean_uploader = re.sub(r'[^\w\s]', ' ', uploader, flags=re.UNICODE).strip() if uploader else ''

    candidates = []
    if clean_uploader and meaningful:
        candidates.append(f"{clean_uploader} {' '.join(meaningful)}")
    if meaningful:
        candidates.append(' '.join(meaningful))
    if clean_uploader:
        candidates.append(clean_uploader)
    if tags:
        for t in tags[:2]:
            ct = re.sub(r'[^\w\s]', ' ', t, flags=re.UNICODE).strip()
            if ct and ct not in candidates:
                candidates.append(ct)
    if not candidates:
        candidates.append("trending videos")

    try:
        from app.extractor import get_cookies_file
        cookie_file = get_cookies_file()
    except Exception:
        cookie_file = None

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": True, # High speed flat extraction
        "skip_download": True,
        "socket_timeout": 6,
        "ignoreerrors": True,
        "extractor_args": {
            "youtube": {
                "player_client": ["visionos", "android", "web"]
            }
        }
    }
    if cookie_file:
        ydl_opts["cookiefile"] = cookie_file

    for query in candidates:
        if len(related) >= max_results:
            break
        try:
            search_query = f"ytsearch{max_results + 2}:{query}"
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                res = ydl.extract_info(search_query, download=False)
                entries = res.get("entries", []) if res else []
                for entry in entries:
                    if not entry:
                        continue
                    entry_id = str(entry.get("id", ""))
                    if entry_id == video_id or not entry_id:
                        continue
                    if any(r.id == entry_id for r in related):
                        continue

                    # Use clean, permanent high-resolution JPEG thumbnail for YouTube videos
                    if len(entry_id) == 11 and re.match(r'^[a-zA-Z0-9_-]{11}$', entry_id):
                        thumb = f"https://i.ytimg.com/vi/{entry_id}/hqdefault.jpg"
                    else:
                        thumb = entry.get("thumbnail")
                        if not thumb and entry.get("thumbnails"):
                            thumb = entry["thumbnails"][-1].get("url")
                    if thumb and "vi_webp" in thumb:
                        thumb = thumb.replace("vi_webp", "vi").replace(".webp", ".jpg")

                    entry_title = entry.get("title") or "Related Video"
                    entry_title = entry_title.strip()

                    related.append(RelatedVideo(
                        id=entry_id,
                        title=entry_title,
                        url=entry.get("url") or f"https://www.youtube.com/watch?v={entry_id}",
                        thumbnail=thumb,
                        uploader=entry.get("uploader") or entry.get("channel"),
                        duration_formatted=format_duration(entry.get("duration")),
                        view_count_formatted=format_view_count(entry.get("view_count"))
                    ))
                    if len(related) >= max_results:
                        break
        except Exception as e:
            logger.warning(f"Search query failed for '{query}': {e}")
            continue

    return related[:max_results]
