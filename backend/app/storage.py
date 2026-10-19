"""Image storage on local disk. Replace save_image and delete_image with S3 or Cloudinary calls for production;
the routes only depend on these two functions."""
import uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile

from .config import settings

# extension, and how to recognise the real file type from its first bytes
_TYPES = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}


def _real_type(head: bytes) -> str | None:
    if head.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "image/webp"
    return None


def upload_root() -> Path:
    root = Path(settings.upload_dir)
    root.mkdir(parents=True, exist_ok=True)
    return root


def save_image(file: UploadFile, folder: str) -> tuple[str, str]:
    """Validate and store one image. Returns (public_url, storage_key)."""
    limit = settings.max_upload_mb * 1024 * 1024
    data = file.file.read(limit + 1)
    if len(data) > limit:
        raise HTTPException(413, f"{file.filename or 'That photo'} is larger than {settings.max_upload_mb} MB")
    if not data:
        raise HTTPException(400, "That file is empty")
    # Trust the file's content, not the name or the type the browser claims.
    real = _real_type(data[:16])
    if real is None:
        raise HTTPException(400, f"{file.filename or 'That file'} isn't a JPG, PNG or WebP photo")

    key = f"{folder}/{uuid.uuid4().hex}.{_TYPES[real]}"
    path = upload_root() / key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return f"{settings.public_base_url.rstrip('/')}/uploads/{key}", key


def delete_image(key: str | None) -> None:
    """Remove a stored file. Missing files and external URLs (no key) are ignored."""
    if not key:
        return
    root = upload_root().resolve()
    path = (root / key).resolve()
    if root in path.parents and path.is_file():
        path.unlink()
