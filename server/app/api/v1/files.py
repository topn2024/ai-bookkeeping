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

    # Read file content
    content = await file.read()

    # Validate file size (max 20MB for images, 10MB for audio)
    max_size = 20 * 1024 * 1024 if file_type == "image" else 10 * 1024 * 1024
    if len(content) > max_size:
        size_mb = max_size // (1024 * 1024)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Max size: {size_mb}MB",
        )

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

    # Verify user owns the file (check user_id in path)
    user_id_str = str(current_user.id)
    if user_id_str not in object_name:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied to this file",
        )

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
    # Verify user owns the file
    user_id_str = str(current_user.id)
    if user_id_str not in object_name:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied to this file",
        )

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
