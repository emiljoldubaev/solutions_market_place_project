from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models.user import User
from dependencies import get_current_user
from schemas.notification import NotificationOut, UnreadNotificationCountOut
from schemas.common import PaginatedResponse
from services.notification_service import notification_service

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("", response_model=PaginatedResponse[NotificationOut])
def list_notifications(
    unread_only: bool = Query(False),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get paginated notifications."""
    items, total = notification_service.get_notifications(
        db, current_user.id, unread_only, page, page_size
    )
    return PaginatedResponse.create(
        items=items,
        total=total,
        page=page,
        page_size=page_size
    )


@router.get("/unread-count", response_model=UnreadNotificationCountOut)
def get_unread_count(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get count of unread notifications."""
    count = notification_service.get_unread_count(db, current_user.id)
    return {"unread_count": count}


@router.post("/read-all")
def mark_all_notifications_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark all notifications as read."""
    notification_service.mark_all_read(db, current_user.id)
    return {"message": "All notifications marked as read"}


@router.post("/{id}/read")
def mark_notification_read(
    id: int = Path(..., ge=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark a notification as read."""
    notification_service.mark_read(db, id, current_user.id)
    return {"message": "Notification marked as read"}

