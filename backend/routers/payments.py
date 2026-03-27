from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models.user import User
from dependencies import get_current_user
from schemas.payment import PaymentInitiate, PaymentConfirm, PaymentOut
from schemas.common import PaginatedResponse
from services.payment_service import payment_service

router = APIRouter(prefix="/payments", tags=["Payments"])

@router.post("/initiate", response_model=PaymentOut)
def initiate_payment(
    data: PaymentInitiate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Initiate a payment for a promotion."""
    return payment_service.initiate_payment(db, current_user.id, data)

@router.post("/{id}/confirm", response_model=PaymentOut)
def confirm_payment(
    data: PaymentConfirm,
    id: int = Path(..., ge=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Confirm a payment with mock status ('success' or 'fail')."""
    return payment_service.confirm_payment(db, current_user.id, id, data)

@router.get("/history", response_model=PaginatedResponse[PaymentOut])
def get_payment_history(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get paginated payment history for current user."""
    items, total = payment_service.get_payment_history(db, current_user.id, page, page_size)
    return PaginatedResponse.create(
        items=items,
        total=total,
        page=page,
        page_size=page_size
    )
