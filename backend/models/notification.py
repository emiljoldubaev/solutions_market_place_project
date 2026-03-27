from sqlalchemy import Column, Integer, String, Text, Enum, DateTime, Boolean, ForeignKey, func, Index
from sqlalchemy.orm import relationship
from database import Base


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    type = Column(
        Enum(
            "listing_approved", "listing_rejected", "new_message",
            "report_resolved", "payment_successful",
            "promotion_activated", "promotion_expired",
            name="notification_type_enum",
        ),
        nullable=False,
    )
    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=True)
    reference_type = Column(String(50), nullable=True)
    reference_id = Column(Integer, nullable=True)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now(), index=True)

    __table_args__ = (
        Index("idx_notifications_read", "user_id", "is_read"),
    )

    # Relationships
    user = relationship("User", back_populates="notifications")
