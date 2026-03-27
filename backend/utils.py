import re
import math
from typing import Any, Dict, List, Optional


def slugify(text: str) -> str:
    """Convert text to URL-friendly slug."""
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-")


def paginate(query, page: int = 1, page_size: int = 20) -> Dict[str, Any]:
    """Apply pagination to a SQLAlchemy query and return paginated result."""
    page = max(1, page)
    page_size = min(max(1, page_size), 100)  # clamp between 1 and 100

    total_items = query.count()
    total_pages = math.ceil(total_items / page_size) if total_items > 0 else 0

    items = query.offset((page - 1) * page_size).limit(page_size).all()

    return {
        "items": items,
        "page": page,
        "page_size": page_size,
        "total_items": total_items,
        "total_pages": total_pages,
    }


ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
ALLOWED_ATTACHMENT_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".pdf"}


def validate_file_extension(filename: str, allowed: set) -> bool:
    """Check if file extension is in the allowed set."""
    if not filename or "." not in filename:
        return False
    ext = "." + filename.rsplit(".", 1)[1].lower()
    return ext in allowed
