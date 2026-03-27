from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from models.promotion import Promotion
from models.promotion_package import PromotionPackage
from models.listing import Listing
from models.user import User
from schemas.promotion import PromotionCreate
from exceptions import NotFoundError, BadRequestError, ForbiddenError

class PromotionService:
    @staticmethod
    def get_active_packages(db: Session):
        """Retrieve all active promotion packages."""
        return db.query(PromotionPackage).filter(PromotionPackage.is_active == True).all()

    @staticmethod
    def create_promotion(db: Session, user_id: int, data: PromotionCreate) -> Promotion:
        """Create a promotion for a listing, setting it to pending_payment."""
        listing = db.query(Listing).filter(Listing.id == data.listing_id).first()
        if not listing:
            raise NotFoundError("Listing not found")
        if listing.owner_id != user_id:
            raise ForbiddenError("You do not own this listing")
        if listing.status != "approved":
            raise BadRequestError("Only approved listings can be promoted")
            
        package = db.query(PromotionPackage).filter(PromotionPackage.id == data.package_id, PromotionPackage.is_active == True).first()
        if not package:
            raise NotFoundError("Promotion package not found")
            
        existing = db.query(Promotion).filter(
            Promotion.listing_id == data.listing_id,
            Promotion.status.in_(["active", "pending_payment"])
        ).first()
        if existing:
            raise BadRequestError("Listing already has an active or pending promotion")

        promotion = Promotion(
            listing_id=data.listing_id,
            package_id=data.package_id,
            status="pending_payment"
        )
        db.add(promotion)
        db.commit()
        db.refresh(promotion)
        return promotion

    @staticmethod
    def get_my_promotions(db: Session, user_id: int, page: int = 1, page_size: int = 20):
        """Get paginated promotions created by the user."""
        query = db.query(Promotion).join(Listing).filter(Listing.owner_id == user_id).order_by(Promotion.created_at.desc())
        total = query.count()
        items = query.offset((page - 1) * page_size).limit(page_size).all()
        return items, total

    @staticmethod
    def activate_promotion(db: Session, promotion_id: int) -> Promotion:
        """Internal service to activate a promotion (used by PaymentService)."""
        promotion = db.query(Promotion).filter(Promotion.id == promotion_id).first()
        if promotion and promotion.status == "pending_payment":
            package = db.query(PromotionPackage).filter(PromotionPackage.id == promotion.package_id).first()
            promotion.status = "active"
            promotion.start_date = datetime.utcnow()
            promotion.end_date = datetime.utcnow() + timedelta(days=package.duration_days)
            
            listing = db.query(Listing).filter(Listing.id == promotion.listing_id).first()
            listing.promotion_status = "promoted"
            
        return promotion

promotion_service = PromotionService()
