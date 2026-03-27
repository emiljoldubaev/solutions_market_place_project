from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database import get_db
from models.user import User
from dependencies import get_current_user
from schemas.report import ReportCreate, ReportOut
from schemas.common import PaginatedResponse
from services.report_service import report_service

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.post("", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
def create_report(
    data: ReportCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Submit a report against a listing, user, or other entity."""
    return report_service.create_report(db, current_user.id, data)


@router.get("/my", response_model=PaginatedResponse[ReportOut])
def get_my_reports(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get paginated history of reports submitted by the current user."""
    items, total = report_service.get_my_reports(db, current_user.id, page, page_size)
    return PaginatedResponse.create(
        items=items,
        total=total,
        page=page,
        page_size=page_size
    )
