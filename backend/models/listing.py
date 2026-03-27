from sqlalchemy import (
    Column, Integer, String, Text, Enum, DateTime, Boolean,
    ForeignKey, Numeric, func, Index
)
from sqlalchemy.orm import relationship
from database import Base


class Listing(Base):
    __tablename__ = "listings"

    id = Column(Integer, primary_key=True, autoincrement=True)
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="RESTRICT"), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)
    price = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(3), default="USD")
    city = Column(String(100), nullable=False, index=True)
    condition = Column(
        Enum("new", "like_new", "good", "fair", "poor", name="listing_condition_enum"),
        nullable=True,
    )
    status = Column(
        Enum("draft", "pending_review", "approved", "rejected", "archived", "sold", name="listing_status_enum"),
        default="draft",
        index=True,
    )
    moderation_note = Column(Text, nullable=True)
    contact_preference = Column(
        Enum("chat", "phone", "both", name="contact_pref_enum"),
        default="chat",
    )
    is_featured = Column(Boolean, default=False, index=True)
    is_negotiable = Column(Boolean, default=False)
    view_count = Column(Integer, default=0)
    rejection_reason = Column(Text, nullable=True)
    published_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    deleted_at = Column(DateTime, nullable=True, index=True)

    # Indexes
    __table_args__ = (
        Index("idx_listings_price", "price"),
    )

    # Relationships
    owner = relationship("User", back_populates="listings")
    category = relationship("Category", back_populates="listings")
    images = relationship("ListingImage", back_populates="listing", cascade="all, delete-orphan")
    favorites = relationship("Favorite", back_populates="listing", cascade="all, delete-orphan")
    conversations = relationship("Conversation", back_populates="listing")
    promotions = relationship("Promotion", back_populates="listing", cascade="all, delete-orphan")
