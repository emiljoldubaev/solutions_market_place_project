from fastapi import APIRouter, Depends, Query, Path, UploadFile, File, Form, Body
from sqlalchemy.orm import Session
from typing import List, Optional

from database import get_db
from models.user import User
from dependencies import get_current_user
from schemas.conversation import (
    ConversationOut, 
    ConversationDetailOut, 
    ConversationCreate, 
    MessageOut, 
    UnreadCountOut
)
from schemas.common import PaginatedResponse
from services.conversation_service import conversation_service
from services.message_service import message_service

router = APIRouter(prefix="/conversations", tags=["Conversations"])


@router.get("", response_model=PaginatedResponse[ConversationOut])
def list_conversations(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get the current user's conversations (inbox)."""
    conversations, total = conversation_service.get_user_conversations(
        db, current_user.id, page, page_size
    )
    return PaginatedResponse.create(
        items=conversations,
        total=total,
        page=page,
        page_size=page_size
    )


@router.post("", response_model=ConversationDetailOut)
def start_conversation(
    data: ConversationCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Start or retrieve a conversation about a listing."""
    conv = conversation_service.get_or_create_conversation(
        db, data.listing_id, current_user.id, data.recipient_id
    )
    
    # Enrich with other participant for schema
    other_id = conv.participant_b_id if conv.participant_a_id == current_user.id else conv.participant_a_id
    conv.other_participant = db.query(User).filter(User.id == other_id).first()
    
    return conv


@router.get("/unread-count", response_model=UnreadCountOut)
def get_unread_count(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get the total unread message count for the current user."""
    count = message_service.get_unread_count(db, current_user.id)
    return {"total_unread": count}


@router.get("/{id}", response_model=ConversationDetailOut)
def get_conversation_detail(
    id: int = Path(..., ge=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get details of a specific conversation."""
    # We could move this to service, but simple enough here
    from models.conversation import Conversation
    from exceptions import NotFoundError, ForbiddenError
    
    conv = db.query(Conversation).filter(Conversation.id == id).first()
    if not conv:
        raise NotFoundError("Conversation not found")
    
    if current_user.id not in [conv.participant_a_id, conv.participant_b_id]:
        raise ForbiddenError("Access denied")
        
    other_id = conv.participant_b_id if conv.participant_a_id == current_user.id else conv.participant_a_id
    conv.other_participant = db.query(User).filter(User.id == other_id).first()
    
    return conv


@router.get("/{id}/messages", response_model=PaginatedResponse[MessageOut])
def list_messages(
    id: int = Path(..., ge=1),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get messages for a conversation."""
    messages, total = message_service.get_messages(db, id, current_user.id, page, page_size)
    return PaginatedResponse.create(
        items=messages,
        total=total,
        page=page,
        page_size=page_size
    )


@router.post("/{id}/messages", response_model=MessageOut)
async def send_message(
    id: int = Path(..., ge=1),
    text_body: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Send a message (text and/or file)."""
    return await message_service.send_message(db, id, current_user.id, text_body, file)


@router.post("/{id}/mark-read")
def mark_as_read(
    id: int = Path(..., ge=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark all messages in a conversation as read."""
    message_service.mark_conversation_read(db, id, current_user.id)
    return {"message": "Marked as read"}
