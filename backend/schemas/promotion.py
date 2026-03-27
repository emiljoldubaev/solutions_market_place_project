from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime
from decimal import Decimal

class PromotionPackageOut(BaseModel):
    id: int
    name: str
    description: str
    duration_days: int
    price: Decimal
    currency: str
    is_active: bool
    
    model_config = ConfigDict(from_attributes=True)

class PromotionCreate(BaseModel):
    listing_id: int
    package_id: int

class PromotionOut(BaseModel):
    id: int
    listing_id: int
    package_id: int
    status: str
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
