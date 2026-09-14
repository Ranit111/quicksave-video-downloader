import glob
import os
import re
import subprocess
import tempfile
import urllib.parse
import urllib.request
from typing import Optional
from fastapi import FastAPI, HTTPException, Request, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response, JSONResponse
import yt_dlp

from app.models import ExtractRequest, VideoInfoResponse, ErrorResponse
from app.extractor import extract_info, detect_platform, get_format_selector, resolve_facebook_url

app = FastAPI(
    title="QuickSave Video Downloader API",
    description="Universal video and audio extraction engine supporting YouTube, Instagram, Facebook, ShareChat, TikTok, and more.",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "*",
            "Access-Control-Allow-Headers": "*",
        }
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    status_code, detail = classify_error(exc)
    return JSONResponse(
        status_code=status_code,
        content={"detail": detail},
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "*",
            "Access-Control-Allow-Headers": "*",
        }
    )

def cleanup_file(path: str):
    try:
        if os.path.exists(path):
            os.remove(path)
    except Exception:
        pass

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "QuickSave Downloader API"}

@app.get("/api/platforms")
def get_supported_platforms():
    return {
        "platforms": [
            {"id": "youtube", "name": "YouTube", "icon": "youtube", "color": "#FF0000"},
            {"id": "instagram", "name": "Instagram", "icon": "instagram", "color": "#E1306C"},
            {"id": "facebook", "name": "Facebook", "icon": "facebook", "color": "#1877F2"},
            {"id": "sharechat", "name": "ShareChat", "icon": "sharechat", "color": "#25D366"},
            {"id": "tiktok", "name": "TikTok", "icon": "tiktok", "color": "#00F2FE"},
            {"id": "twitter", "name": "X (Twitter)", "icon": "twitter", "color": "#1DA1F2"},
        ]
    }

ALLOWED_THUMBNAIL_DOMAINS = {
    "ytimg.com", "youtube.com", "fbcdn.net", "facebook.com",
    "cdninstagram.com", "instagram.com", "tiktokcdn.com", "tiktok.com",
    "twimg.com", "twitter.com", "x.com", "reddit.com", "redditmedia.com",
    "unsplash.com", "sharechat.com"
}

def is_safe_thumbnail_url(url: str) -> bool:
    try:
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme not in ("http", "https"):
            return False
        hostname = (parsed.hostname or "").lower()
        if not hostname:
            return False
        # Block private and loopback IPs
        if (
            hostname == "localhost"
            or hostname.startswith("127.")
            or hostname.startswith("10.")
            or hostname.startswith("192.168.")
            or hostname.startswith("169.254.")
            or hostname.endswith(".local")
            or hostname.endswith(".internal")
        ):
            return False
        return any(hostname == domain or hostname.endswith("." + domain) for domain in ALLOWED_THUMBNAIL_DOMAINS)
    except Exception:
        return False

@app.get("/api/proxy-thumbnail")
def proxy_thumbnail(url: str = Query(..., description="Target image URL to proxy")):
    clean_url = url.strip()
    if not is_safe_thumbnail_url(clean_url):
        raise HTTPException(status_code=400, detail="Invalid or untrusted image URL domain.")
    try:
        req = urllib.request.Request(
            clean_url,
            headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            }
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            content_type = resp.headers.get("Content-Type", "image/jpeg")
            if not content_type.startswith("image/"):
                raise HTTPException(status_code=400, detail="Target URL is not an image.")
            # Bound payload to maximum 5 MB to prevent OOM
            data = resp.read(5 * 1024 * 1024)
            return Response(content=data, media_type=content_type, headers={"Cache-Control": "public, max-age=86400"})
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=404, detail="Could not proxy image.")

def classify_error(error: Exception) -> tuple[int, str]:
    msg = str(error).strip()
    msg_lower = msg.lower()
    
    if "unsupported url" in msg_lower or "is not a valid url" in msg_lower or "no suitable info extractor" in msg_lower:
        return 400, "This video link or website is not supported."
    if "private video" in msg_lower or "this video is private" in msg_lower:
        return 403, "This video is private or restricted."
    if "video unavailable" in msg_lower or "has been removed" in msg_lower or "does not exist" in msg_lower or "not found" in msg_lower or "404" in msg_lower:
        return 404, "Video not found or has been removed."
    if "confirm your age" in msg_lower or "sign in to confirm" in msg_lower or "age-gated" in msg_lower or "inappropriate" in msg_lower:
        return 403, "This video is age-restricted and requires sign-in."
    if "not available in your country" in msg_lower or "geo-restricted" in msg_lower or "geographic" in msg_lower or "blocked in your country" in msg_lower:
        return 403, "This video is not available in your region."
    if "is a live stream" in msg_lower or "live event" in msg_lower or "stream is live" in msg_lower:
        return 400, "Live streams cannot be downloaded until finished."
    if "this post contains no video" in msg_lower or "no video entries found" in msg_lower or "no video formats found" in msg_lower:
        return 404, "No downloadable video found in this link."
    if "unable to obtain file audio codec" in msg_lower or "audio conversion failed" in msg_lower:
        return 400, "This video does not have an audio track to download as MP3."
    if "requested format is not available" in msg_lower:
        return 400, "Requested quality format is not available. Please try another quality."
    if "http error 403" in msg_lower or "forbidden" in msg_lower:
        return 403, "Access to this video stream was restricted. Please try another quality or link."
    if "http error 429" in msg_lower or "too many requests" in msg_lower:
        return 429, "Server rate limit reached. Please wait a moment and try again."
    if "login required" in msg_lower or "members-only" in msg_lower or "subscriber-only" in msg_lower:
        return 403, "This video requires account sign-in."
    if "drm" in msg_lower:
        return 400, "This video is DRM protected and cannot be downloaded."
    if "timed out" in msg_lower or "timeout" in msg_lower:
        return 504, "Website took too long to respond. Please try again."
    if "getaddrinfo failed" in msg_lower or "name or service not known" in msg_lower or "nodename nor servname" in msg_lower or "failed to establish a new connection" in msg_lower:
        return 502, "Could not reach website host. Check the domain or link."
    
    return 500, "Could not process video. Check the link and try again."

@app.post("/api/extract", response_model=VideoInfoResponse, responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}})
async def extract_video(req: ExtractRequest, request: Request):
    url = req.url.strip()
    if not url:
        raise HTTPException(status_code=400, detail="Please enter or paste a video link.")
    if not (url.startswith("http://") or url.startswith("https://")):
        raise HTTPException(status_code=400, detail="Please enter a valid link starting with http:// or https://")

    base_url = str(request.base_url).rstrip("/")
    try:
        info = extract_info(url=url, base_url=base_url)
        return info
    except HTTPException:
        raise
    except Exception as e:
        status_code, detail = classify_error(e)
        raise HTTPException(status_code=status_code, detail=detail)

@app.get("/api/stream")
def stream_media(
    background_tasks: BackgroundTasks,
    url: str = Query(..., description="Target video URL"),
    format_id: str = Query("720p", description="Target quality: 1080p, 720p, 480p, 360p, or mp3"),
    ext: str = Query("mp4", description="Output extension: mp4 or mp3"),
    audio_only: bool = Query(False, description="Whether to extract audio only")
):
    if not url:
        raise HTTPException(status_code=400, detail="Missing video URL.")

    # Clean URL (FastAPI query parser already decodes URL parameters)
    target_url = url.strip()
    platform_key, _ = detect_platform(target_url)
    if platform_key == "facebook":
        target_url = resolve_facebook_url(target_url)

    candidate_urls = [target_url]
    if platform_key == "facebook":
        if "www.facebook.com" in target_url:
            candidate_urls.append(target_url.replace("www.facebook.com", "m.facebook.com"))
        elif "facebook.com" in target_url and "m.facebook.com" not in target_url:
            candidate_urls.append(re.sub(r'https?://(?:www\.)?facebook\.com', 'https://m.facebook.com', target_url))

    # 1. Fetch metadata for clean title and orientation
    is_vertical = False
    safe_title = "video"
    for cand_url in candidate_urls:
        try:
            ydl_opts_meta = {"quiet": True, "no_warnings": True, "skip_download": True, "socket_timeout": 8, "nocheckcertificate": True}
            with yt_dlp.YoutubeDL(ydl_opts_meta) as ydl:
                meta = ydl.extract_info(cand_url, download=False)
                if meta:
                    if "entries" in meta and meta["entries"]:
                        meta = meta["entries"][0]
                    duration = meta.get("duration")
                    if duration and isinstance(duration, (int, float)) and duration > 10800:
                        raise HTTPException(
                            status_code=400,
                            detail="Video exceeds maximum allowed duration of 3 hours for download."
                        )
                    raw_title = meta.get("title") or "video"
                    clean = re.sub(r'[\\/*?:"<>|]', "", raw_title).strip()[:60]
                    if clean:
                        safe_title = clean
                    is_vertical = (meta.get("height") or 0) > (meta.get("width") or 0)
                    break
        except HTTPException:
            raise
        except Exception:
            continue

    if not safe_title or not safe_title.strip():
        safe_title = f"{platform_key}_video" if platform_key != "other" else "video"

    is_audio = audio_only or ext == "mp3" or format_id in ["mp3", "ba/b", "ba", "bestaudio", "bestaudio/best"]
    out_ext = "mp3" if is_audio else "mp4"
    filename = f"{safe_title}.{out_ext}"
    ascii_title = "".join(c for c in safe_title if c.isalnum() or c in (" ", "-", "_")).strip()
    if not ascii_title:
        ascii_title = f"{platform_key}_download" if platform_key != "other" else "video_download"
    ascii_filename = f"{ascii_title}.{out_ext}"
    encoded_filename = urllib.parse.quote(filename)

    # 2. Setup unique temp output path
    temp_dir = tempfile.gettempdir()
    temp_prefix = f"quicksave_{os.getpid()}_{abs(hash(target_url + format_id))}_{os.urandom(4).hex()}"
    temp_out_template = os.path.join(temp_dir, f"{temp_prefix}.%(ext)s")

    clean_format_id = format_id.replace(" ", "+")
    last_err = None

    if is_audio:
        media_type = "audio/mpeg"
        audio_downloaded = False
        # Audio Tier 1: yt-dlp with extract audio
        for cand_url in candidate_urls:
            if audio_downloaded:
                break
            try:
                ydl_opts = {
                    "format": get_format_selector("mp3"),
                    "outtmpl": temp_out_template,
                    "quiet": True,
                    "no_warnings": True,
                    "merge_output_format": "mp3",
                    "postprocessors": [{
                        'key': 'FFmpegExtractAudio',
                        'preferredcodec': 'mp3',
                        'preferredquality': '192',
                    }],
                    "socket_timeout": 25,
                    "nocheckcertificate": True,
                }
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    ydl.download([cand_url])

                valid_files = [
                    f for f in glob.glob(os.path.join(temp_dir, f"{temp_prefix}.*"))
                    if not f.endswith(('.part', '.ytdl', '.tmp', '.temp')) and os.path.isfile(f) and os.path.getsize(f) > 0
                ]
                if valid_files:
                    audio_downloaded = True
                    break
            except Exception as e:
                last_err = e
                continue

        # Audio Tier 2: Download raw media and extract via ffmpeg directly
        if not audio_downloaded:
            for cand_url in candidate_urls:
                try:
                    ydl_opts_raw = {
                        "format": "ba/b/best",
                        "outtmpl": temp_out_template,
                        "quiet": True,
                        "no_warnings": True,
                        "socket_timeout": 25,
                        "nocheckcertificate": True,
                    }
                    with yt_dlp.YoutubeDL(ydl_opts_raw) as ydl:
                        ydl.download([cand_url])

                    raw_files = [
                        f for f in glob.glob(os.path.join(temp_dir, f"{temp_prefix}.*"))
                        if not f.endswith(('.part', '.ytdl', '.tmp', '.temp')) and os.path.isfile(f) and os.path.getsize(f) > 0
                    ]
                    if raw_files:
                        src_file = raw_files[0]
                        mp3_out = os.path.join(temp_dir, f"{temp_prefix}.mp3")
                        if src_file != mp3_out:
                            cmd = [
                                "ffmpeg", "-y", "-i", src_file,
                                "-vn", "-acodec", "libmp3lame", "-ab", "192k",
                                mp3_out
                            ]
                            res = subprocess.run(cmd, capture_output=True)
                            if res.returncode == 0 and os.path.exists(mp3_out) and os.path.getsize(mp3_out) > 0:
                                cleanup_file(src_file)
                                audio_downloaded = True
                                break
                            else:
                                # If video had no audio, generate silent MP3
                                cmd_silent = [
                                    "ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo",
                                    "-t", "5", "-acodec", "libmp3lame", "-ab", "192k",
                                    mp3_out
                                ]
                                subprocess.run(cmd_silent, capture_output=True)
                                cleanup_file(src_file)
                                if os.path.exists(mp3_out):
                                    audio_downloaded = True
                                    break
                except Exception as e:
                    last_err = e
                    continue
    else:
        media_type = "video/mp4"
        video_downloaded = False

        format_selectors = [
            get_format_selector(clean_format_id, is_vertical=is_vertical),
            "bv*+ba/b/best",
            "hd/sd/bestvideo+bestaudio/best",
            "best/b/ba",
        ]

        for cand_url in candidate_urls:
            if video_downloaded:
                break
            for fmt_sel in format_selectors:
                try:
                    ydl_opts = {
                        "format": fmt_sel,
                        "outtmpl": temp_out_template,
                        "quiet": True,
                        "no_warnings": True,
                        "merge_output_format": "mp4",
                        "socket_timeout": 30,
                        "nocheckcertificate": True,
                        "geo_bypass": True,
                    }
                    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                        ydl.download([cand_url])

                    valid_files = [
                        f for f in glob.glob(os.path.join(temp_dir, f"{temp_prefix}.*"))
                        if not f.endswith(('.part', '.ytdl', '.tmp', '.temp')) and os.path.isfile(f) and os.path.getsize(f) > 0
                    ]
                    if valid_files:
                        video_downloaded = True
                        break
                except Exception as e:
                    last_err = e
                    continue

    valid_files = [
        f for f in glob.glob(os.path.join(temp_dir, f"{temp_prefix}.*"))
        if not f.endswith(('.part', '.ytdl', '.tmp', '.temp')) and os.path.isfile(f) and os.path.getsize(f) > 0
    ]

    # Cleanup any leftover partial files
    for part_file in glob.glob(os.path.join(temp_dir, f"{temp_prefix}*")):
        if part_file not in valid_files:
            cleanup_file(part_file)

    if not valid_files:
        if last_err:
            status_code, detail = classify_error(last_err)
            raise HTTPException(status_code=status_code, detail=detail)
        raise HTTPException(status_code=400, detail="Could not download media. The video may be private, restricted, or unavailable.")

    final_filepath = max(valid_files, key=lambda p: os.path.getsize(p))
    background_tasks.add_task(cleanup_file, final_filepath)

    return FileResponse(
        path=final_filepath,
        media_type=media_type,
        filename=ascii_filename,
        headers={
            "Access-Control-Expose-Headers": "Content-Disposition, Content-Length",
        }
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
