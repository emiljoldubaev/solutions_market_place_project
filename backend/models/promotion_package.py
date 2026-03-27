from sqlalchemy import Column, Integer, String, Text, Enum, DateTime, Boolean, ForeignKey, Numeric, func
from sqlalchemy.orm import relationship
from database import Base


class PromotionPackage(Base):
    __tablename__ = "promotion_packages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    name_ru = Column(String(100), nullable=True)
    description = Column(Text, nullable=True)
    promotion_type = Column(
        Enum("boost", "featured", "city_spotlight", name="promotion_type_enum"),
        nullable=False,
    )
    duration_days = Column(Integer, nullable=False)
    price = Column(Numeric(10, 2), nullable=False)
    currency = Column(String(3), default="USD")
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime, server_default=func.now())

    # Relationships
    promotions = relationship("Promotion", back_populates="package")
