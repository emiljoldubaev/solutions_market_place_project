from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy.orm import Session
from typing import List, Optional
from database import get_db
from models.user import User
from models.listing import Listing
from dependencies import get_current_user, require_active, get_optional_user
from schemas.listing import (
    ListingCreate, ListingUpdate, ListingOut, ListingDetailOut
)
from schemas.common import PaginatedResponse
from services import listing_service
from exceptions import NotFoundError, ForbiddenError


router = APIRouter(prefix="/listings", tags=["Listings"])


@router.get("", response_model=PaginatedResponse[ListingOut])
def list_listings(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    category_id: Optional[int] = None,
    city: Optional[str] = None,
    min_price: Optional[float] = None,
    max_price: Optional[float] = None,
    condition: Optional[str] = None,
    sort_by: str = Query("newest", pattern="^(newest|oldest|price_low|price_high|popular)$"),
    db: Session = Depends(get_db)
):
    """Public listings feed."""
    listings, total = listing_service.get_listings(
        db, page, page_size, search, category_id, city, 
        min_price, max_price, condition, sort_by
    )
    return PaginatedResponse.create(
        items=listings,
        total=total,
        page=page,
        page_size=page_size
    )


@router.get("/my", response_model=List[ListingOut])
def list_my_listings(
    status: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current user's listings."""
    return listing_service.get_my_listings(db, current_user.id, status)


@router.get("/{id}", response_model=ListingDetailOut)
def get_listing(
    id: int = Path(..., ge=1),
    current_user: Optional[User] = Depends(get_optional_user),
    db: Session = Depends(get_db)
):
    """Get listing details and increment view count."""
    listing = db.query(Listing).filter(
        Listing.id == id, 
        Listing.deleted_at == None
    ).first()
    
    if not listing:
        raise NotFoundError("Listing not found")
        
    if listing.status != "approved":
        if not current_user or (current_user.id != listing.owner_id and current_user.role != "admin"):
            raise NotFoundError("Listing not found")
    
    # Increment view count
    listing.view_count += 1
    db.commit()
    db.refresh(listing)
    
    return listing


@router.post("", response_model=ListingOut, status_code=201)
def create_listing(
    data: ListingCreate,
    current_user: User = Depends(require_active),
    db: Session = Depends(get_db)
):
    """Create a new listing (Draft)."""
    return listing_service.create_listing(db, current_user.id, data)


@router.put("/{id}", response_model=ListingOut)
def update_listing(
    id: int,
    data: ListingUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update listing details."""
    listing = db.query(Listing).filter(Listing.id == id, Listing.deleted_at == None).first()
    if not listing:
        raise NotFoundError("Listing not found")
        
    if listing.owner_id != current_user.id and current_user.role != "admin":
        raise ForbiddenError("You don't have permission to update this listing")
        
    return listing_service.update_listing(db, listing, data, current_user)


@router.delete("/{id}")
def delete_listing(
    id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Soft delete a listing."""
    listing = db.query(Listing).filter(Listing.id == id, Listing.deleted_at == None).first()
    if not listing:
        raise NotFoundError("Listing not found")
        
    if listing.owner_id != current_user.id and current_user.role != "admin":
        raise ForbiddenError("You don't have permission to delete this listing")
        
    listing_service.delete_listing(db, listing, current_user)
    return {"message": "Listing deleted successfully"}


@router.post("/{id}/submit", response_model=ListingOut)
def submit_listing(
    id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Draft -> Pending Review."""
    listing = db.query(Listing).filter(Listing.id == id, Listing.deleted_at == None).first()
    if not listing:
        raise NotFoundError("Listing not found")
        
    listing_service.transition_listing_status(listing, "pending_review", current_user)
    db.commit()
    return listing


@router.post("/{id}/archive", response_model=ListingOut)
def archive_listing(
    id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Archive a listing."""
    listing = db.query(Listing).filter(Listing.id == id, Listing.deleted_at == None).first()
    if not listing:
        raise NotFoundError("Listing not found")
        
    listing_service.transition_listing_status(listing, "archived", current_user)
    db.commit()
    return listing


@router.post("/{id}/mark-sold", response_model=ListingOut)
def mark_listing_sold(
    id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark as sold."""
    listing = db.query(Listing).filter(Listing.id == id, Listing.deleted_at == None).first()
    if not listing:
        raise NotFoundError("Listing not found")
        
    listing_service.transition_listing_status(listing, "sold", current_user)
    db.commit()
    return listing
