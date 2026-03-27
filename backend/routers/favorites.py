from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy.orm import Session
from typing import List, Dict

from database import get_db
from models.user import User
from models.listing import Listing
from models.favorite import Favorite
from dependencies import get_current_user
from schemas.listing import ListingOut
from schemas.common import PaginatedResponse
from exceptions import NotFoundError, ConflictError

router = APIRouter(prefix="/favorites", tags=["Favorites"])


@router.post("/{listing_id}", status_code=201)
def add_favorite(
    listing_id: int = Path(..., ge=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add a listing to favorites."""
    # Check if listing exists and is not deleted
    listing = db.query(Listing).filter(Listing.id == listing_id, Listing.deleted_at == None).first()
    if not listing:
        raise NotFoundError("Listing not found")
        
    # Check if already favorited
    existing = db.query(Favorite).filter(
        Favorite.user_id == current_user.id,
        Favorite.listing_id == listing_id
    ).first()
    
    if existing:
        raise ConflictError("Listing already in favorites")
        
    new_fav = Favorite(user_id=current_user.id, listing_id=listing_id)
    db.add(new_fav)
    db.commit()
    
    return {"message": "Added to favorites"}


@router.delete("/{listing_id}")
def remove_favorite(
    listing_id: int = Path(..., ge=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Remove a listing from favorites."""
    fav = db.query(Favorite).filter(
        Favorite.user_id == current_user.id,
        Favorite.listing_id == listing_id
    ).first()
    
    if not fav:
        raise NotFoundError("Favorite not found")
        
    db.delete(fav)
    db.commit()
    
    return {"message": "Removed from favorites"}


@router.get("", response_model=PaginatedResponse[ListingOut])
def list_favorites(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current user's favorite listings (paginated, skips deleted)."""
    query = db.query(Listing).join(Favorite).filter(
        Favorite.user_id == current_user.id,
        Listing.deleted_at == None
    )
    
    total = query.count()
    listings = query.offset((page - 1) * page_size).limit(page_size).all()
    
    return PaginatedResponse.create(
        items=listings,
        total=total,
        page=page,
        page_size=page_size
    )


@router.get("/check/{listing_id}")
def check_favorite(
    listing_id: int = Path(..., ge=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict[str, bool]:
    """Check if a listing is favorited by the current user."""
    fav = db.query(Favorite).filter(
        Favorite.user_id == current_user.id,
        Favorite.listing_id == listing_id
    ).first()
    
    return {"is_favorited": bool(fav)}
