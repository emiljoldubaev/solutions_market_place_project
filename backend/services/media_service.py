import os
import uuid
import shutil
from pathlib import Path
from typing import List, Optional
from fastapi import UploadFile
from config import settings
from exceptions import BadRequestError


class MediaService:
    @staticmethod
    @staticmethod
    def validate_attachment(file: UploadFile):
        """
        Validates attachment type and size (PDF and Images).
        """
        if file.content_type not in settings.allowed_attachment_types_list:
            raise BadRequestError(
                f"Invalid file type: {file.content_type}. Allowed: {settings.ALLOWED_ATTACHMENT_TYPES}"
            )
        # Size limit is checked after/during save or via headers if available

    @staticmethod
    async def save_image(file: UploadFile, folder: str = "listings") -> str:
        """
        Saves an uploaded image to the specified folder with a unique name.
        Returns the relative URL/path.
        """
        ext = Path(file.filename).suffix.lower()
        if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
            # Fallback extension if filename is missing it or weird
            ext = ".jpg"
            
        unique_filename = f"{uuid.uuid4().hex}{ext}"
        upload_path = os.path.join(settings.UPLOAD_DIR, folder, unique_filename)
        
        # Ensure directory exists (though config.py handles this on startup)
        os.makedirs(os.path.dirname(upload_path), exist_ok=True)

        try:
            with open(upload_path, "wb") as buffer:
                # Read in chunks to handle large files
                while content := await file.read(1024 * 1024):  # 1MB chunks
                    buffer.write(content)
            
            # Check size after saving
            file_size = os.path.getsize(upload_path)
            max_size = settings.max_attachment_size_bytes if folder == "attachments" else settings.max_image_size_bytes
            if file_size > max_size:
                os.remove(upload_path)
                limit_mb = settings.MAX_ATTACHMENT_SIZE_MB if folder == "attachments" else settings.MAX_IMAGE_SIZE_MB
                raise BadRequestError(f"File too large. Max size: {limit_mb}MB")
                
            return f"/uploads/{folder}/{unique_filename}"
        except Exception as e:
            if os.path.exists(upload_path):
                os.remove(upload_path)
            raise BadRequestError(f"Failed to save image: {str(e)}")

    @staticmethod
    def delete_image(image_url: str):
        """
        Deletes the physical file associated with an image URL.
        URL format expected: /uploads/listings/filename.ext
        """
        if not image_url.startswith("/uploads/"):
            return
            
        relative_path = image_url.replace("/uploads/", "")
        file_path = os.path.join(settings.UPLOAD_DIR, relative_path)
        
        if os.path.exists(file_path):
            os.remove(file_path)


media_service = MediaService()
