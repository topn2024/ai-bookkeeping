"""File storage service using MinIO.

Handles file upload, download, and management for source files
(images from receipt scanning, audio from voice recognition).
"""
import io
import uuid
from datetime import datetime, timedelta
from typing import Optional, Tuple
import logging

from minio import Minio
from minio.error import S3Error

from app.core.config import settings


logger = logging.getLogger(__name__)


class FileStorageService:
    """MinIO-based file storage service for source files."""

    # Supported file types and their MIME types
    SUPPORTED_IMAGE_TYPES = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "heic": "image/heic",
        "heif": "image/heif",
    }

    SUPPORTED_AUDIO_TYPES = {
        "m4a": "audio/mp4",
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "aac": "audio/aac",
    }

    # Bucket subdirectories
    IMAGE_PREFIX = "source-images/"
    AUDIO_PREFIX = "source-audio/"

    def __init__(self):
        """Initialize MinIO client."""
        self._client: Optional[Minio] = None
        self._bucket_ensured = False

    @property
    def client(self) -> Minio:
        """Get or create MinIO client."""
        if self._client is None:
            self._client = Minio(
                settings.MINIO_ENDPOINT,
                access_key=settings.MINIO_ACCESS_KEY,
                secret_key=settings.MINIO_SECRET_KEY,
                secure=settings.MINIO_SECURE,
            )
        return self._client

    async def ensure_bucket(self) -> bool:
        """Ensure the bucket exists, create if not."""
        if self._bucket_ensured:
            return True

        try:
            if not self.client.bucket_exists(settings.MINIO_BUCKET):
                self.client.make_bucket(settings.MINIO_BUCKET)
                logger.info(f"Created bucket: {settings.MINIO_BUCKET}")
            self._bucket_ensured = True
            return True
        except S3Error as e:
            logger.error(f"Failed to ensure bucket: {e}")
            return False

    def _get_file_extension(self, filename: str) -> str:
        """Extract file extension from filename."""
        if "." in filename:
            return filename.rsplit(".", 1)[-1].lower()
        return ""

    def _get_content_type(self, extension: str) -> Optional[str]:
        """Get MIME type for file extension."""
        if extension in self.SUPPORTED_IMAGE_TYPES:
            return self.SUPPORTED_IMAGE_TYPES[extension]
        if extension in self.SUPPORTED_AUDIO_TYPES:
            return self.SUPPORTED_AUDIO_TYPES[extension]
        return None

    def _generate_object_name(
        self, user_id: str, file_type: str, extension: str
    ) -> str:
        """Generate unique object name for storage.

        Format: {prefix}{user_id}/{date}/{uuid}.{ext}
        Example: source-images/abc123/2024-01-15/uuid.jpg
        """
        prefix = (
            self.IMAGE_PREFIX
            if file_type == "image"
            else self.AUDIO_PREFIX
        )
        date_str = datetime.utcnow().strftime("%Y-%m-%d")
        unique_id = uuid.uuid4().hex[:12]
        return f"{prefix}{user_id}/{date_str}/{unique_id}.{extension}"

    async def upload_file(
        self,
        user_id: str,
        file_data: bytes,
        filename: str,
        file_type: str = "image",
    ) -> Tuple[Optional[str], Optional[str], Optional[int]]:
        """Upload a file to MinIO.

        Args:
            user_id: User ID for organizing files
            file_data: Raw file bytes
            filename: Original filename (for extension detection)
            file_type: Either "image" or "audio"

        Returns:
            Tuple of (object_url, content_type, file_size) or (None, None, None) on failure
        """
        await self.ensure_bucket()

        extension = self._get_file_extension(filename)
        content_type = self._get_content_type(extension)

        if content_type is None:
            logger.warning(f"Unsupported file extension: {extension}")
            return None, None, None

        object_name = self._generate_object_name(user_id, file_type, extension)
        file_size = len(file_data)

        try:
            self.client.put_object(
                settings.MINIO_BUCKET,
                object_name,
                io.BytesIO(file_data),
                length=file_size,
                content_type=content_type,
            )

            # Construct the URL
            url = self._get_object_url(object_name)
            logger.info(f"Uploaded file: {object_name} ({file_size} bytes)")
            return url, content_type, file_size

        except S3Error as e:
            logger.error(f"Failed to upload file: {e}")
            return None, None, None

    def _get_object_url(self, object_name: str) -> str:
        """Construct URL for stored object."""
        if settings.MINIO_PUBLIC_URL:
            return f"{settings.MINIO_PUBLIC_URL}/{settings.MINIO_BUCKET}/{object_name}"
        protocol = "https" if settings.MINIO_SECURE else "http"
        return f"{protocol}://{settings.MINIO_ENDPOINT}/{settings.MINIO_BUCKET}/{object_name}"

    async def get_presigned_url(
        self, object_name: str, expires: int = 3600
    ) -> Optional[str]:
        """Get a presigned URL for temporary file access.

        Args:
            object_name: The object name in the bucket
            expires: URL expiration time in seconds (default 1 hour)

        Returns:
            Presigned URL or None on failure
        """
        try:
            url = self.client.presigned_get_object(
                settings.MINIO_BUCKET,
                object_name,
                expires=timedelta(seconds=expires),
            )
            return url
        except S3Error as e:
            logger.error(f"Failed to get presigned URL: {e}")
            return None

    async def download_file(self, object_name: str) -> Optional[bytes]:
        """Download a file from MinIO.

        Args:
            object_name: The object name in the bucket

        Returns:
            File bytes or None on failure
        """
        try:
            response = self.client.get_object(settings.MINIO_BUCKET, object_name)
            data = response.read()
            response.close()
            response.release_conn()
            return data
        except S3Error as e:
            logger.error(f"Failed to download file: {e}")
            return None

    async def delete_file(self, object_name: str) -> bool:
        """Delete a file from MinIO.

        Args:
            object_name: The object name in the bucket

        Returns:
            True if successful, False otherwise
        """
        try:
            self.client.remove_object(settings.MINIO_BUCKET, object_name)
            logger.info(f"Deleted file: {object_name}")
            return True
        except S3Error as e:
            logger.error(f"Failed to delete file: {e}")
            return False

    async def delete_expired_files(self, user_id: str, before_date: datetime) -> int:
        """Delete files that have expired.

        Args:
            user_id: User ID to clean up files for
            before_date: Delete files created before this date

        Returns:
            Number of files deleted
        """
        deleted_count = 0

        for prefix in [self.IMAGE_PREFIX, self.AUDIO_PREFIX]:
            full_prefix = f"{prefix}{user_id}/"
            try:
                objects = self.client.list_objects(
                    settings.MINIO_BUCKET,
                    prefix=full_prefix,
                    recursive=True,
                )

                for obj in objects:
                    if obj.last_modified and obj.last_modified < before_date:
                        if await self.delete_file(obj.object_name):
                            deleted_count += 1

            except S3Error as e:
                logger.error(f"Failed to list objects for cleanup: {e}")

        return deleted_count

    def extract_object_name_from_url(self, url: str) -> Optional[str]:
        """Extract object name from full URL.

        Args:
            url: Full MinIO URL

        Returns:
            Object name or None if URL format is invalid
        """
        # URL format: http(s)://endpoint/bucket/object_name
        bucket_prefix = f"/{settings.MINIO_BUCKET}/"
        if bucket_prefix in url:
            return url.split(bucket_prefix, 1)[1]
        return None


# Singleton instance
file_storage_service = FileStorageService()
