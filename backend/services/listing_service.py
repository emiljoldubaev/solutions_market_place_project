from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, desc, func
from models.listing import Listing
from models.user import User
from schemas.listing import ListingCreate, ListingUpdate, ListingStatus
from exceptions import BadRequestError, ForbiddenError, NotFoundError
from datetime import datetime
import math
from services.notification_service import notification_service


ALLOWED_TRANSITIONS = {
    "draft": ["pending_review"],
    "pending_review": ["approved", "rejected"],
    "approved": ["archived", "sold", "pending_review"],  # pending_review = re-moderation on edit
    "rejected": ["draft"],  # user can edit and resubmit
    "archived": ["draft"],
    "sold": [],  # terminal
}


def transition_listing_status(listing: Listing, new_status: str, actor: User):
    """
    Validates and performs a status transition for a listing.
    """
    current_status = listing.status
    
    # Check if transition is allowed
    if new_status not in ALLOWED_TRANSITIONS.get(current_status, []):
        raise BadRequestError(f"Invalid status transition from {current_status} to {new_status}")
    
    # Role-based validation
    if new_status in ["approved", "rejected"] and actor.role != "admin":
        raise ForbiddenError("Only admins can approve or reject listings")
    
    if new_status in ["archived", "sold", "pending_review"] and actor.id != listing.owner_id and actor.role != "admin":
        raise ForbiddenError("You don't have permission to change this listing's status")

    listing.status = new_status
    if new_status == "approved":
        listing.published_at = datetime.utcnow()
        notification_service.create_notification(
            db=db, user_id=listing.owner_id, type="listing_approved", 
            title="Listing Approved", body=f"Your listing '{listing.title}' has been approved.", 
            reference_type="listing", reference_id=listing.id
        )
    elif new_status == "rejected":
        notification_service.create_notification(
            db=db, user_id=listing.owner_id, type="listing_rejected", 
            title="Listing Rejected", body=f"Your listing '{listing.title}' has been rejected.", 
            reference_type="listing", reference_id=listing.id
        )


def create_listing(db: Session, user_id: int, data: ListingCreate) -> Listing:
    """Create a new listing in draft status."""
    listing = Listing(
        **data.model_dump(),
        owner_id=user_id,
        status="draft"
    )
    db.add(listing)
    db.commit()
    db.refresh(listing)
    return listing


def update_listing(db: Session, listing: Listing, data: ListingUpdate, actor: User) -> Listing:
    """
    Update listing fields. 
    Critical field changes trigger re-moderation (pending_review) if listing was approved.
    """
    if actor.id != listing.owner_id and actor.role != "admin":
        raise ForbiddenError("You don't have permission to update this listing")

    update_data = data.model_dump(exclude_unset=True)
    
    # Check for critical field changes
    critical_fields = ["title", "description", "price", "category_id"]
    has_critical_change = any(field in update_data for field in critical_fields)
    
    if has_critical_change and listing.status == "approved":
        listing.status = "pending_review"

    for field, value in update_data.items():
        setattr(listing, field, value)
    
    db.commit()
    db.refresh(listing)
    return listing


def get_listings(
    db: Session, 
    page: int = 1, 
    page_size: int = 20,
    search: str = None,
    category_id: int = None,
    city: str = None,
    min_price: float = None,
    max_price: float = None,
    condition: str = None,
    sort_by: str = "newest"
):
    """Get approved listings with filters and pagination."""
    query = db.query(Listing).filter(
        Listing.status == "approved",
        Listing.deleted_at == None
    )
    
    if search:
        search_filter = or_(
            Listing.title.ilike(f"%{search}%"),
            Listing.description.ilike(f"%{search}%")
        )
        query = query.filter(search_filter)
        
    if category_id:
        query = query.filter(Listing.category_id == category_id)
        
    if city:
        query = query.filter(Listing.city == city)
        
    if min_price is not None:
        query = query.filter(Listing.price >= min_price)
        
    if max_price is not None:
        query = query.filter(Listing.price <= max_price)
        
    if condition:
        query = query.filter(Listing.condition == condition)

    # Sorting
    if sort_by == "newest":
        query = query.order_by(desc(Listing.created_at))
    elif sort_by == "oldest":
        query = query.order_by(Listing.created_at)
    elif sort_by == "price_low":
        query = query.order_by(Listing.price)
    elif sort_by == "price_high":
        query = query.order_by(desc(Listing.price))
    elif sort_by == "popular":
        query = query.order_by(desc(Listing.view_count))

    total = query.count()
    listings = query.offset((page - 1) * page_size).limit(page_size).all()
    
    return listings, total


def get_my_listings(db: Session, user_id: int, status: str = None):
    """Get all listings owned by the user, including all statuses."""
    query = db.query(Listing).filter(
        Listing.owner_id == user_id,
        Listing.deleted_at == None
    )
    
    if status:
        query = query.filter(Listing.status == status)
        
    return query.order_by(desc(Listing.created_at)).all()


def delete_listing(db: Session, listing: Listing, actor: User):
    """Soft delete a listing."""
    if actor.id != listing.owner_id and actor.role != "admin":
        raise ForbiddenError("You don't have permission to delete this listing")
        
    listing.deleted_at = datetime.utcnow()
    db.commit()
