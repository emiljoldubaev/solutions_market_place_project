from sqlalchemy import Column, Integer, String, Enum, DateTime, ForeignKey, Numeric, func
from sqlalchemy.orm import relationship
from database import Base


class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    listing_id = Column(Integer, ForeignKey("listings.id", ondelete="SET NULL"), nullable=True)
    promotion_id = Column(Integer, ForeignKey("promotions.id", ondelete="SET NULL"), nullable=True, index=True)
    amount = Column(Numeric(10, 2), nullable=False)
    currency = Column(String(3), default="USD")
    status = Column(
        Enum("pending", "successful", "failed", "cancelled", name="payment_status_enum"),
        default="pending",
        index=True,
    )
    payment_provider = Column(String(50), default="mock_gateway")
    provider_reference = Column(String(255), nullable=True)
    created_at = Column(DateTime, server_default=func.now(), index=True)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    paid_at = Column(DateTime, nullable=True)

    # Relationships
    user = relationship("User", back_populates="payments")
    listing = relationship("Listing", foreign_keys=[listing_id])
    promotion = relationship("Promotion", back_populates="payment", foreign_keys=[promotion_id])
