from fastapi import APIRouter, Depends, UploadFile, File, Path, Body
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from models.user import User
from models.listing import Listing
from models.listing_image import ListingImage
from dependencies import get_current_user, require_active
from schemas.listing import ListingImageOut
from services import media_service
from exceptions import NotFoundError, ForbiddenError, BadRequestError
from config import settings


router = APIRouter(prefix="/listings/{listing_id}/images", tags=["Listing Images"])


@router.post("", response_model=List[ListingImageOut])
async def upload_listing_images(
    listing_id: int = Path(..., ge=1),
    files: List[UploadFile] = File(...),
    current_user: User = Depends(require_active),
    db: Session = Depends(get_db)
):
    """
    Upload multiple images for a listing (max 5 total).
    First upload automatically becomes primary.
    """
    listing = db.query(Listing).filter(Listing.id == listing_id, Listing.deleted_at == None).first()
    if not listing:
        raise NotFoundError("Listing not found")
    
    if listing.owner_id != current_user.id and current_user.role != "admin":
        raise ForbiddenError("You don't have permission to modify this listing")

    current_count = db.query(ListingImage).filter(ListingImage.listing_id == listing_id).count()
    if current_count + len(files) > settings.MAX_IMAGES_PER_LISTING:
        raise BadRequestError(f"Maximum {settings.MAX_IMAGES_PER_LISTING} images allowed per listing")

    new_images = []
    for (i, file) in enumerate(files):
        # Validate format
        if file.content_type not in settings.allowed_image_types_list:
            raise BadRequestError(f"Invalid file type: {file.content_type}")
            
        # Save file
        image_url = await media_service.save_image(file, folder="listings")
        
        # Create DB record
        is_primary = False
        if current_count == 0 and i == 0:
            is_primary = True
            
        new_img = ListingImage(
            listing_id=listing_id,
            image_url=image_url,
            is_primary=is_primary,
            display_order=current_count + i,
            file_size=0, # Optional: we could get it from media_service
            mime_type=file.content_type
        )
        db.add(new_img)
        new_images.append(new_img)

    db.commit()
    for img in new_images:
        db.refresh(img)
        
    return new_images


@router.put("/reorder", response_model=List[ListingImageOut])
def reorder_listing_images(
    listing_id: int = Path(..., ge=1),
    image_ids: List[int] = Body(..., embed=True),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update display order of images."""
    listing = db.query(Listing).filter(Listing.id == listing_id, Listing.deleted_at == None).first()
    if not listing:
        raise NotFoundError("Listing not found")
    
    if listing.owner_id != current_user.id and current_user.role != "admin":
        raise ForbiddenError("Permission denied")

    images = db.query(ListingImage).filter(ListingImage.listing_id == listing_id).all()
    img_map = {img.id: img for img in images}
    
    # Simple validation: ensure all provided IDs belong to this listing
    if not all(id in img_map for id in image_ids):
        raise BadRequestError("Invalid image IDs provided")

    for (order, img_id) in enumerate(image_ids):
        img_map[img_id].display_order = order
        
    db.commit()
    return sorted(images, key=lambda x: x.display_order)


@router.put("/{image_id}/primary", response_model=ListingImageOut)
def set_primary_image(
    listing_id: int = Path(..., ge=1),
    image_id: int = Path(..., ge=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Set an image as the primary listing image."""
    listing = db.query(Listing).filter(Listing.id == listing_id, Listing.deleted_at == None).first()
    if not listing:
        raise NotFoundError("Listing not found")
    
    if listing.owner_id != current_user.id and current_user.role != "admin":
        raise ForbiddenError("Permission denied")

    # Reset others
    db.query(ListingImage).filter(ListingImage.listing_id == listing_id).update({"is_primary": False})
    
    img = db.query(ListingImage).filter(
        ListingImage.id == image_id, 
        ListingImage.listing_id == listing_id
    ).first()
    
    if not img:
        raise NotFoundError("Image not found")
        
    img.is_primary = True
    db.commit()
    db.refresh(img)
    return img


@router.delete("/{image_id}")
def delete_listing_image(
    listing_id: int = Path(..., ge=1),
    image_id: int = Path(..., ge=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete an image (file + record)."""
    listing = db.query(Listing).filter(Listing.id == listing_id, Listing.deleted_at == None).first()
    if not listing:
        raise NotFoundError("Listing not found")
    
    if listing.owner_id != current_user.id and current_user.role != "admin":
        raise ForbiddenError("Permission denied")

    img = db.query(ListingImage).filter(
        ListingImage.id == image_id, 
        ListingImage.listing_id == listing_id
    ).first()
    
    if not img:
        raise NotFoundError("Image not found")

    # Delete physical file
    media_service.delete_image(img.image_url)
    
    was_primary = img.is_primary
    db.delete(img)
    
    # If we deleted the primary image, pick a new one if available
    if was_primary:
        next_img = db.query(ListingImage).filter(ListingImage.listing_id == listing_id).first()
        if next_img:
            next_img.is_primary = True
            
    db.commit()
    return {"message": "Image deleted"}
