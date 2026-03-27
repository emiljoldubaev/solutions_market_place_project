from pydantic import BaseModel, ConfigDict
from typing import List, Optional
from datetime import datetime
from schemas.auth import UserBaseOut
from schemas.listing import ListingOut

class MessageAttachmentOut(BaseModel):
    id: int
    file_name: str
    original_name: str
    mime_type: str
    file_size: int
    file_url: str
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class MessageOut(BaseModel):
    id: int
    conversation_id: int
    sender_id: int
    text_body: Optional[str] = None
    message_type: str
    is_read: bool
    sent_at: datetime
    attachment: Optional[MessageAttachmentOut] = None
    
    model_config = ConfigDict(from_attributes=True)

class ConversationOut(BaseModel):
    id: int
    listing_id: Optional[int]
    participant_a_id: int
    participant_b_id: int
    last_message_at: Optional[datetime]
    created_at: datetime
    
    # Preview fields (calculated in service)
    last_message_preview: Optional[str] = None
    unread_count: int = 0
    other_participant: UserBaseOut
    listing: Optional[ListingOut] = None
    
    model_config = ConfigDict(from_attributes=True)

class ConversationDetailOut(ConversationOut):
    participant_a: UserBaseOut
    participant_b: UserBaseOut

class ConversationCreate(BaseModel):
    listing_id: int
    recipient_id: int

class UnreadCountOut(BaseModel):
    total_unread: int
