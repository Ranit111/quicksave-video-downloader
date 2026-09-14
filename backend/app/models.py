from typing import List, Optional, Union
from pydantic import BaseModel, HttpUrl

class ExtractRequest(BaseModel):
    url: str

class QualityOption(BaseModel):
    format_id: str
    quality_label: str       # e.g., "1080p Full HD", "720p HD", "480p SD", "Audio MP3"
    resolution: Optional[str] = None  # e.g., "1920x1080", "1280x720", "Audio"
    ext: str                 # "mp4" or "mp3"
    filesize_approx: Optional[Union[int, float]] = None # in bytes
    filesize_formatted: str  # e.g., "142 MB", "68 MB", "12 MB"
    is_audio_only: bool = False
    download_url: Optional[str] = None # direct or proxied stream URL

class RelatedVideo(BaseModel):
    id: str
    title: str
    url: str
    thumbnail: Optional[str] = None
    uploader: Optional[str] = None
    duration_formatted: Optional[str] = None
    view_count_formatted: Optional[str] = None

class VideoInfoResponse(BaseModel):
    id: str
    title: str
    original_url: str
    thumbnail: Optional[str] = None
    uploader: Optional[str] = None
    uploader_url: Optional[str] = None
    duration: Optional[Union[int, float]] = None       # in seconds
    duration_formatted: str             # e.g. "03:45"
    platform: str                       # "youtube", "instagram", "facebook", "sharechat", "tiktok", "other"
    platform_name: str                  # "YouTube", "Instagram", "Facebook", "ShareChat", "TikTok", "Generic"
    qualities: List[QualityOption]
    related_videos: List[RelatedVideo] = []

class ErrorResponse(BaseModel):
    detail: str
    code: str
