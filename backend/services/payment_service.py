from sqlalchemy.orm import Session
import uuid
from models.payment import Payment
from models.promotion import Promotion
from models.promotion_package import PromotionPackage
from models.listing import Listing
from schemas.payment import PaymentInitiate, PaymentConfirm
from exceptions import NotFoundError, BadRequestError, ForbiddenError
from services.promotion_service import promotion_service
from services.notification_service import notification_service

class PaymentService:
    @staticmethod
    def initiate_payment(db: Session, user_id: int, data: PaymentInitiate) -> Payment:
        """Initiate payment for a promotion."""
        promotion = db.query(Promotion).join(Listing).filter(
            Promotion.id == data.promotion_id,
            Listing.owner_id == user_id
        ).first()
        
        if not promotion:
            raise NotFoundError("Promotion not found or access denied")
        if promotion.status != "pending_payment":
            raise BadRequestError("Promotion is not pending payment")
            
        package = db.query(PromotionPackage).filter(PromotionPackage.id == promotion.package_id).first()
        
        existing = db.query(Payment).filter(
            Payment.promotion_id == data.promotion_id,
            Payment.status == "pending"
        ).first()
        if existing:
            return existing
            
        payment = Payment(
            user_id=user_id,
            promotion_id=data.promotion_id,
            amount=package.price,
            currency=package.currency,
            status="pending",
            payment_method=data.payment_method,
            transaction_id=str(uuid.uuid4())
        )
        db.add(payment)
        db.commit()
        db.refresh(payment)
        return payment

    @staticmethod
    def confirm_payment(db: Session, user_id: int, payment_id: int, data: PaymentConfirm) -> Payment:
        """Confirm payment with mock status."""
        payment = db.query(Payment).filter(Payment.id == payment_id, Payment.user_id == user_id).first()
        if not payment:
            raise NotFoundError("Payment not found")
        if payment.status != "pending":
            raise BadRequestError(f"Payment already processed (status: {payment.status})")
            
        try:
            if data.mock_status.lower() == "success":
                payment.status = "successful"
                # Activate promotion
                promotion = promotion_service.activate_promotion(db, payment.promotion_id)
                db.commit() # commit both payment and promotion
                db.refresh(payment)
                
                # trigger notifications
                notification_service.create_notification(
                    db=db, user_id=user_id, type="payment_successful",
                    title="Payment Successful", body="Your payment was successful.",
                    reference_type="payment", reference_id=payment.id
                )
                notification_service.create_notification(
                    db=db, user_id=user_id, type="promotion_activated",
                    title="Promotion Active", body="Your listing promotion is now active.",
                    reference_type="promotion", reference_id=promotion.id
                )
            else:
                payment.status = "failed"
                db.commit()
                db.refresh(payment)
                
            return payment
        except Exception as e:
            db.rollback()
            raise BadRequestError(f"Payment confirmation failed: {str(e)}")

    @staticmethod
    def get_payment_history(db: Session, user_id: int, page: int = 1, page_size: int = 20):
        """Get paginated history of payments."""
        query = db.query(Payment).filter(Payment.user_id == user_id).order_by(Payment.created_at.desc())
        total = query.count()
        items = query.offset((page - 1) * page_size).limit(page_size).all()
        return items, total

payment_service = PaymentService()
