from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime

class NotificationOut(BaseModel):
    id: int
    user_id: int
    type: str
    title: str
    body: str
    reference_type: Optional[str] = None
    reference_id: Optional[int] = None
    is_read: bool
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class UnreadNotificationCountOut(BaseModel):
    unread_count: int
