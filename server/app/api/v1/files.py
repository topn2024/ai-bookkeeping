"""File upload and management endpoints.

Handles source file storage for images and audio from AI recognition.
"""
import base64
from datetime import datetime
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.transaction import Transaction
from app.api.deps import get_current_user, get_db
from app.services.file_storage_service import file_storage_service


router = APIRouter(prefix="/files", tags=["Files"])


# ==================== Magic Bytes Validation ====================

IMAGE_MAGIC = {
    b'\xff\xd8\xff': 'image/jpeg',
    b'\x89PNG\r\n\x1a\n': 'image/png',
    b'\x00\x00\x00': 'image/heic',  # ftyp box (HEIC/HEIF)
}
AUDIO_MAGIC = {
    b'ID3': 'audio/mpeg',        # MP3 with ID3 tag
    b'\xff\xfb': 'audio/mpeg',   # MP3 without ID3
    b'\xff\xf3': 'audio/mpeg',   # MP3 without ID3
    b'RIFF': 'audio/wav',
    b'fLaC': 'audio/flac',
}


def _validate_file_magic(content: bytes, file_type: str):
    """Validate file content matches expected type via magic bytes."""
    magic_map = IMAGE_MAGIC if file_type == "image" else AUDIO_MAGIC
    for magic, _ in magic_map.items():
        if content[:len(magic)] == magic:
            return  # Valid
    # For M4A/AAC/HEIC: check for 'ftyp' box at offset 4
    if len(content) >= 8 and content[4:8] == b'ftyp':
        return  # Valid container format (M4A, HEIC, etc.)
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=f"File content does not match expected {file_type} format",
    )


def _verify_file_ownership(user_id_str: str, object_name: str):
    """Verify that the file belongs to the user using exact path prefix matching."""
    # Reject path traversal attempts
    if '..' in object_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid file path",
        )
    valid_prefixes = [f"source-images/{user_id_str}/", f"source-audio/{user_id_str}/"]
    if not any(object_name.startswith(p) for p in valid_prefixes):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied to this file",
        )


class FileUploadResponse(BaseModel):
    """Response for file upload."""
    url: str
    content_type: str
    size: int
    object_name: str


class FileUrlResponse(BaseModel):
    """Response for file URL request."""
    url: str
    expires_in: int  # Seconds until expiration


class TransactionSourceFileUpdate(BaseModel):
    """Schema for updating transaction source file."""
    source_file_url: str
    source_file_type: str
    source_file_size: int


@router.post("/upload", response_model=FileUploadResponse)
async def upload_file(
    file: UploadFile = File(..., description="File to upload (image or audio)"),
    file_type: str = Form("image", description="Type: 'image' or 'audio'"),
    current_user: User = Depends(get_current_user),
):
    """Upload a source file (image or audio) to storage.

    Use this to sync local files to the server when on WiFi.
    Returns the permanent URL for the file.
    """
    # Validate file type parameter
    if file_type not in ["image", "audio"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="file_type must be 'image' or 'audio'",
        )

    # Validate content type
    content_type = file.content_type or ""
    if file_type == "image" and not content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be an image",
        )
    if file_type == "audio" and not content_type.startswith("audio/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be audio",
        )

    # Read file content in chunks to prevent DoS from large uploads
    max_size = 20 * 1024 * 1024 if file_type == "image" else 10 * 1024 * 1024
    content = bytearray()
    while chunk := await file.read(8192):
        content.extend(chunk)
        if len(content) > max_size:
            size_mb = max_size // (1024 * 1024)
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File too large. Max size: {size_mb}MB",
            )
    content = bytes(content)

    # Validate file content via magic bytes
    _validate_file_magic(content, file_type)

    # Upload to MinIO
    url, content_type, file_size = await file_storage_service.upload_file(
        user_id=str(current_user.id),
        file_data=content,
        filename=file.filename or "unknown",
        file_type=file_type,
    )

    if url is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to upload file",
        )

    # Extract object name from URL
    object_name = file_storage_service.extract_object_name_from_url(url) or ""

    return FileUploadResponse(
        url=url,
        content_type=content_type,
        size=file_size,
        object_name=object_name,
    )


@router.post("/upload-base64", response_model=FileUploadResponse)
async def upload_file_base64(
    data: str = Form(..., description="Base64 encoded file data"),
    filename: str = Form(..., description="Original filename with extension"),
    file_type: str = Form("image", description="Type: 'image' or 'audio'"),
    current_user: User = Depends(get_current_user),
):
    """Upload a base64-encoded file to storage.

    Alternative upload method for clients that prefer base64 encoding.
    """
    # Validate file type
    if file_type not in ["image", "audio"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="file_type must be 'image' or 'audio'",
        )

    # Decode base64
    try:
        content = base64.b64decode(data)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid base64 encoding",
        )

    # Validate file size
    max_size = 20 * 1024 * 1024 if file_type == "image" else 10 * 1024 * 1024
    if len(content) > max_size:
        size_mb = max_size // (1024 * 1024)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Max size: {size_mb}MB",
        )

    # Validate file content via magic bytes
    _validate_file_magic(content, file_type)

    # Upload to MinIO
    url, content_type, file_size = await file_storage_service.upload_file(
        user_id=str(current_user.id),
        file_data=content,
        filename=filename,
        file_type=file_type,
    )

    if url is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to upload file",
        )

    object_name = file_storage_service.extract_object_name_from_url(url) or ""

    return FileUploadResponse(
        url=url,
        content_type=content_type,
        size=file_size,
        object_name=object_name,
    )


@router.get("/presigned/{object_name:path}", response_model=FileUrlResponse)
async def get_presigned_url(
    object_name: str,
    expires: int = 3600,
    current_user: User = Depends(get_current_user),
):
    """Get a presigned URL for temporary file access.

    Args:
        object_name: The object name/path in storage
        expires: URL expiration time in seconds (default 1 hour, max 24 hours)
    """
    # Validate expiration time
    if expires < 60 or expires > 86400:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="expires must be between 60 and 86400 seconds",
        )

    # Verify user owns the file using exact path prefix matching
    _verify_file_ownership(str(current_user.id), object_name)

    url = await file_storage_service.get_presigned_url(object_name, expires)

    if url is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File not found",
        )

    return FileUrlResponse(url=url, expires_in=expires)


@router.delete("/{object_name:path}")
async def delete_file(
    object_name: str,
    current_user: User = Depends(get_current_user),
):
    """Delete a file from storage.

    Args:
        object_name: The object name/path in storage
    """
    # Verify user owns the file using exact path prefix matching
    _verify_file_ownership(str(current_user.id), object_name)

    success = await file_storage_service.delete_file(object_name)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete file",
        )

    return {"status": "deleted"}


@router.post("/transactions/{transaction_id}/source-file")
async def update_transaction_source_file(
    transaction_id: UUID,
    data: TransactionSourceFileUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update transaction with uploaded source file URL.

    Call this after uploading a file to link it to a transaction.
    """
    # Get transaction
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == transaction_id,
            Transaction.user_id == current_user.id,
        )
    )
    transaction = result.scalar_one_or_none()

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    # Update source file fields
    transaction.source_file_url = data.source_file_url
    transaction.source_file_type = data.source_file_type
    transaction.source_file_size = data.source_file_size

    await db.commit()

    return {"status": "updated"}


class CleanupResult(BaseModel):
    """Result of cleanup operation."""
    deleted_count: int


@router.post("/cleanup-expired", response_model=CleanupResult)
async def cleanup_expired_files(
    before_date: datetime,
    current_user: User = Depends(get_current_user),
):
    """Clean up expired files for the current user.

    This is called by the mobile app's cleanup scheduler.
    """
    deleted_count = await file_storage_service.delete_expired_files(
        user_id=str(current_user.id),
        before_date=before_date,
    )

    return CleanupResult(deleted_count=deleted_count)
