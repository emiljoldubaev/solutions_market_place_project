from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional
from datetime import datetime

class UserUpdate(BaseModel):
    """Schema for updating current user's profile."""
    full_name: Optional[str] = Field(None, min_length=2, max_length=100)
    bio: Optional[str] = None
    city: Optional[str] = None
    preferred_language: Optional[str] = None

    @field_validator('full_name', 'bio', 'city', 'preferred_language', mode='before')
    @classmethod
    def strip_whitespace(cls, v):
        if isinstance(v, str):
            return v.strip()
        return v

class PublicUserOut(BaseModel):
    """Schema for public user profile."""
    id: int
    full_name: str
    profile_image_url: Optional[str] = None
    city: Optional[str] = None
    bio: Optional[str] = None
    created_at: datetime
    active_listing_count: int = 0

    class Config:
        from_attributes = True
