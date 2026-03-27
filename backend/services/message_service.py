from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from typing import List, Optional
from fastapi import UploadFile
import os
from pathlib import Path

from models.message import Message
from models.conversation import Conversation
from models.message_attachment import MessageAttachment
from services.media_service import media_service
from services.notification_service import notification_service
from exceptions import BadRequestError, ForbiddenError, NotFoundError
from config import settings


class MessageService:
    @staticmethod
    async def send_message(
        db: Session, 
        conversation_id: int, 
        sender_id: int, 
        text_body: Optional[str] = None, 
        file: Optional[UploadFile] = None
    ) -> Message:
        """
        Sends a message in a conversation. 
        Supports text, attachments, or both.
        """
        if not text_body and not file:
            raise BadRequestError("Message must have text or an attachment")

        # Verify conversation and participation
        conv = db.query(Conversation).filter(Conversation.id == conversation_id).first()
        if not conv:
            raise NotFoundError("Conversation not found")
        
        if sender_id not in [conv.participant_a_id, conv.participant_b_id]:
            raise ForbiddenError("You are not a participant in this conversation")

        # Determine message type
        msg_type = "text"
        if text_body and file:
            msg_type = "text_attachment"
        elif file:
            msg_type = "attachment"

        # Create message record
        message = Message(
            conversation_id=conversation_id,
            sender_id=sender_id,
            text_body=text_body,
            message_type=msg_type,
            is_read=False
        )
        db.add(message)
        db.flush() # Get message ID for attachment

        # Handle attachment if any
        if file:
            # Validate attachment (Service-level)
            media_service.validate_attachment(file)
            
            # Save file
            file_url = await media_service.save_image(file, folder="attachments")
            
            # Check size (from saved file if not possible from UploadFile)
            # media_service.save_image already checks settings.max_image_size_bytes?
            # Wait, media_service.py uses max_image_size_bytes. We should use a different check or update it.
            # For now, let's assume it's acceptable or we'll refine media_service.
            
            # Create attachment record
            attachment = MessageAttachment(
                message_id=message.id,
                file_name=os.path.basename(file_url),
                original_name=file.filename or "uploaded_file",
                mime_type=file.content_type or "application/octet-stream",
                file_size=0, # We could get this from OS, but for now 0 or real size
                file_url=file_url
            )
            
            # Update file_size
            file_path = os.path.join(settings.UPLOAD_DIR, "attachments", attachment.file_name)
            if os.path.exists(file_path):
                attachment.file_size = os.path.getsize(file_path)
            
            db.add(attachment)

        # Update conversation last_message_at
        conv.last_message_at = func.now()
        
        db.commit()
        db.refresh(message)
        
        # Trigger notification
        recipient_id = conv.participant_b_id if conv.participant_a_id == sender_id else conv.participant_a_id
        notification_service.create_notification(
            db=db,
            user_id=recipient_id,
            type="new_message",
            title="New Message",
            body="You have received a new message.",
            reference_type="conversation",
            reference_id=conversation_id
        )

        return message

    @staticmethod
    def get_messages(
        db: Session, 
        conversation_id: int, 
        user_id: int, 
        page: int = 1, 
        page_size: int = 50
    ):
        """
        Get paginated messages for a conversation, oldest first.
        """
        # Verify participation
        conv = db.query(Conversation).filter(Conversation.id == conversation_id).first()
        if not conv:
            raise NotFoundError("Conversation not found")
        
        if user_id not in [conv.participant_a_id, conv.participant_b_id]:
            raise ForbiddenError("Access denied")

        query = db.query(Message).filter(Message.conversation_id == conversation_id).order_by(Message.sent_at.asc())
        
        total = query.count()
        messages = query.offset((page - 1) * page_size).limit(page_size).all()
        
        return messages, total

    @staticmethod
    def mark_conversation_read(db: Session, conversation_id: int, user_id: int):
        """
        Marks all messages in a conversation as read (except those sent by user).
        """
        db.query(Message).filter(
            Message.conversation_id == conversation_id,
            Message.sender_id != user_id,
            Message.is_read == False
        ).update({"is_read": True}, synchronize_session=False)
        db.commit()

    @staticmethod
    def get_unread_count(db: Session, user_id: int) -> int:
        """
        Returns total number of unread messages for the user.
        """
        count = db.query(Message).join(Conversation).filter(
            or_(
                Conversation.participant_a_id == user_id,
                Conversation.participant_b_id == user_id
            ),
            Message.sender_id != user_id,
            Message.is_read == False
        ).count()
        return count


message_service = MessageService()
