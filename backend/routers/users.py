from fastapi import APIRouter, Depends, Query, Path, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional

from database import get_db
from models.user import User
from models.listing import Listing
from dependencies import get_current_user, require_active
from schemas.auth import UserBaseOut
from schemas.user import UserUpdate, PublicUserOut
from schemas.listing import ListingOut
from schemas.common import PaginatedResponse
from services import media_service
from exceptions import NotFoundError

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserBaseOut)
def get_me(current_user: User = Depends(get_current_user)):
    """Get the current authenticated user's profile."""
    return current_user


@router.put("/me", response_model=UserBaseOut)
def update_me(
    data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update current user's profile fields."""
    if data.full_name is not None:
        current_user.full_name = data.full_name
    if data.bio is not None:
        current_user.bio = data.bio
    if data.city is not None:
        current_user.city = data.city
    if data.preferred_language is not None:
        current_user.preferred_language = data.preferred_language
        
    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/me/profile-image", response_model=UserBaseOut)
async def upload_profile_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Upload/update profile image."""
    # Delete old image if exists
    if current_user.profile_image_url:
        media_service.delete_image(current_user.profile_image_url)
        
    image_url = await media_service.save_image(file, folder="profiles")
    current_user.profile_image_url = image_url
    
    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/{id}/public", response_model=PublicUserOut)
def get_public_profile(
    id: int = Path(..., ge=1),
    db: Session = Depends(get_db)
):
    """Get a user's public profile and active listing count."""
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise NotFoundError("User not found")
        
    # Count approved listings
    listing_count = db.query(Listing).filter(
        Listing.owner_id == id,
        Listing.status == "approved",
        Listing.deleted_at == None
    ).count()
    
    # We can't use from_attributes directly because active_listing_count is a dynamic field
    return PublicUserOut(
        id=user.id,
        full_name=user.full_name,
        profile_image_url=user.profile_image_url,
        city=user.city,
        bio=user.bio,
        created_at=user.created_at,
        active_listing_count=listing_count
    )


@router.get("/{id}/listings", response_model=PaginatedResponse[ListingOut])
def list_user_listings(
    id: int = Path(..., ge=1),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort_by: str = Query("newest", pattern="^(newest|oldest|price_low|price_high)$"),
    db: Session = Depends(get_db)
):
    """Get public approved listings of a specific user."""
    query = db.query(Listing).filter(
        Listing.owner_id == id,
        Listing.status == "approved",
        Listing.deleted_at == None
    )
    
    # Sorting
    if sort_by == "newest":
        query = query.order_by(Listing.created_at.desc())
    elif sort_by == "oldest":
        query = query.order_by(Listing.created_at.asc())
    elif sort_by == "price_low":
        query = query.order_by(Listing.price.asc())
    elif sort_by == "price_high":
        query = query.order_by(Listing.price.desc())
        
    total = query.count()
    listings = query.offset((page - 1) * page_size).limit(page_size).all()
    
    return PaginatedResponse.create(
        items=listings,
        total=total,
        page=page,
        page_size=page_size
    )
