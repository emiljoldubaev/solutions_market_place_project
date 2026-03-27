from sqlalchemy import Column, Integer, String, Enum, DateTime, ForeignKey, Numeric, func, Index
from sqlalchemy.orm import relationship
from database import Base


class Promotion(Base):
    __tablename__ = "promotions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    listing_id = Column(Integer, ForeignKey("listings.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    package_id = Column(Integer, ForeignKey("promotion_packages.id", ondelete="RESTRICT"), nullable=False)
    promotion_type = Column(
        Enum("boost", "featured", "city_spotlight", name="promotion_type_enum"),
        nullable=False,
    )
    target_city = Column(String(100), nullable=True)
    target_category_id = Column(Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True)
    starts_at = Column(DateTime, nullable=False)
    ends_at = Column(DateTime, nullable=False)
    status = Column(
        Enum("pending_payment", "active", "expired", "cancelled", name="promotion_status_enum"),
        default="pending_payment",
        index=True,
    )
    purchased_price = Column(Numeric(10, 2), nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        Index("idx_promotions_dates", "starts_at", "ends_at"),
    )

    # Relationships
    listing = relationship("Listing", back_populates="promotions")
    user = relationship("User", back_populates="promotions")
    package = relationship("PromotionPackage", back_populates="promotions")
    target_category = relationship("Category", foreign_keys=[target_category_id])
    payment = relationship("Payment", back_populates="promotion", uselist=False)
