from pydantic import BaseModel, Field, HttpUrl
from typing import Optional, List
from decimal import Decimal
from datetime import datetime
from enum import Enum


class ListingCondition(str, Enum):
    NEW = "new"
    LIKE_NEW = "like_new"
    GOOD = "good"
    FAIR = "fair"
    POOR = "poor"


class ContactPreference(str, Enum):
    CHAT = "chat"
    PHONE = "phone"
    BOTH = "both"


class ListingStatus(str, Enum):
    DRAFT = "draft"
    PENDING_REVIEW = "pending_review"
    APPROVED = "approved"
    REJECTED = "rejected"
    ARCHIVED = "archived"
    SOLD = "sold"


class ListingImageOut(BaseModel):
    id: int
    image_url: str
    is_primary: bool
    order_index: int

    class Config:
        from_attributes = True


class UserPublicOut(BaseModel):
    """Public user information for listing details."""
    id: int
    full_name: str
    profile_image_url: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class ListingBase(BaseModel):
    title: str = Field(..., min_length=5, max_length=200)
    description: str = Field(..., min_length=20)
    price: Decimal = Field(..., ge=0)
    currency: str = Field("USD", min_length=3, max_length=3)
    category_id: int
    city: str
    condition: Optional[ListingCondition] = None
    contact_preference: Optional[ContactPreference] = ContactPreference.BOTH
    is_negotiable: Optional[bool] = False


class ListingCreate(ListingBase):
    pass


class ListingUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=5, max_length=200)
    description: Optional[str] = Field(None, min_length=20)
    price: Optional[Decimal] = Field(None, ge=0)
    currency: Optional[str] = Field(None, min_length=3, max_length=3)
    category_id: Optional[int] = None
    city: Optional[str] = None
    condition: Optional[ListingCondition] = None
    contact_preference: Optional[ContactPreference] = None
    is_negotiable: Optional[bool] = None


class ListingOut(ListingBase):
    id: int
    status: ListingStatus
    owner_id: int
    view_count: int
    is_featured: bool
    created_at: datetime
    updated_at: datetime
    primary_image_url: Optional[str] = None
    promotion_status: Optional[str] = None
    moderation_status: Optional[str] = None

    class Config:
        from_attributes = True


class ListingDetailOut(ListingOut):
    owner: UserPublicOut
    images: List[ListingImageOut] = []

    class Config:
        from_attributes = True
