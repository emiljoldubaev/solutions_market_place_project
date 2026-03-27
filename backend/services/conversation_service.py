from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func
from typing import List, Optional
from datetime import datetime

from models.conversation import Conversation
from models.message import Message
from models.listing import Listing
from models.user import User
from exceptions import BadRequestError, NotFoundError, ForbiddenError


class ConversationService:
    @staticmethod
    def get_or_create_conversation(
        db: Session, 
        listing_id: int, 
        sender_id: int, 
        recipient_id: int
    ) -> Conversation:
        """
        Retrieves an existing conversation or creates a new one.
        Normalizes participant order to ensure a unique pair per listing.
        """
        if sender_id == recipient_id:
            raise BadRequestError("You cannot message yourself")

        # Validate listing
        listing = db.query(Listing).filter(Listing.id == listing_id, Listing.deleted_at == None).first()
        if not listing:
            raise NotFoundError("Listing not found")
        if listing.status != "approved":
            raise ForbiddenError("You can only message about approved listings")

        # Validate users (not blocked)
        users = db.query(User).filter(User.id.in_([sender_id, recipient_id])).all()
        if len(users) < 2:
            raise NotFoundError("One or more participants not found")
        
        for user in users:
            if user.account_status in ["blocked", "suspended"]:
                raise ForbiddenError(f"User {user.email} is currently blocked")

        # Normalize participant order: A < B
        p_a_id = min(sender_id, recipient_id)
        p_b_id = max(sender_id, recipient_id)

        # Check for existing
        conversation = db.query(Conversation).filter(
            Conversation.participant_a_id == p_a_id,
            Conversation.participant_b_id == p_b_id,
            Conversation.listing_id == listing_id
        ).first()

        if not conversation:
            conversation = Conversation(
                participant_a_id=p_a_id,
                participant_b_id=p_b_id,
                listing_id=listing_id,
                created_by_user_id=sender_id
            )
            db.add(conversation)
            db.commit()
            db.refresh(conversation)

        return conversation

    @staticmethod
    def get_user_conversations(
        db: Session, 
        user_id: int, 
        page: int = 1, 
        page_size: int = 20
    ):
        """
        Get all conversations for a user, sorted by last message.
        Includes last message preview and unread count.
        """
        # We need to join with Message to get unread counts for messages where sender != user_id
        # and also get the latest message text.
        
        query = db.query(Conversation).filter(
            or_(
                Conversation.participant_a_id == user_id,
                Conversation.participant_b_id == user_id
            )
        ).order_by(Conversation.last_message_at.desc())

        total = query.count()
        conversations = query.offset((page - 1) * page_size).limit(page_size).all()

        # TODO: Replace with JOIN query for production scale
        for conv in conversations:
            # Get other participant
            other_id = conv.participant_b_id if conv.participant_a_id == user_id else conv.participant_a_id
            conv.other_participant = db.query(User).filter(User.id == other_id).first()
            
            # Get last message preview
            last_msg = db.query(Message).filter(Message.conversation_id == conv.id).order_by(Message.sent_at.desc()).first()
            if last_msg:
                if last_msg.text_body:
                    conv.last_message_preview = last_msg.text_body[:50] + ("..." if len(last_msg.text_body) > 50 else "")
                elif last_msg.message_type in ["attachment", "text_attachment"]:
                    conv.last_message_preview = "[Attachment]"
                else:
                    conv.last_message_preview = ""
            else:
                conv.last_message_preview = "No messages yet"

            # Get unread count (messages sent by other, where is_read is False)
            conv.unread_count = db.query(Message).filter(
                Message.conversation_id == conv.id,
                Message.sender_id != user_id,
                Message.is_read == False
            ).count()

        return conversations, total


conversation_service = ConversationService()
