from sqlalchemy import Column, Integer, String, Text, Enum, DateTime, Boolean, ForeignKey, func
from sqlalchemy.orm import relationship
from database import Base


class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    conversation_id = Column(Integer, ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    text_body = Column(Text, nullable=True)
    message_type = Column(
        Enum("text", "attachment", "text_attachment", name="message_type_enum"),
        default="text",
    )
    is_read = Column(Boolean, default=False, index=True)
    sent_at = Column(DateTime, server_default=func.now(), index=True)
    edited_at = Column(DateTime, nullable=True)
    deleted_at = Column(DateTime, nullable=True)

    # Relationships
    conversation = relationship("Conversation", back_populates="messages")
    sender = relationship("User", foreign_keys=[sender_id])
    attachment = relationship("MessageAttachment", back_populates="message", uselist=False, cascade="all, delete-orphan")
