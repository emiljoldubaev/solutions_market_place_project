from sqlalchemy import Column, Integer, String, Text, Enum, DateTime, Boolean, func
from sqlalchemy.orm import relationship
from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    full_name = Column(String(100), nullable=False)
    email = Column(String(255), nullable=False, unique=True, index=True)
    password_hash = Column(String(255), nullable=False)
    phone = Column(String(20), nullable=True, unique=True)
    profile_image_url = Column(String(500), nullable=True)
    bio = Column(Text, nullable=True)
    city = Column(String(100), nullable=True)
    preferred_language = Column(String(10), default="en")
    role = Column(Enum("user", "admin", name="user_role"), default="user", index=True)
    account_status = Column(
        Enum("active", "blocked", "pending_verification", "deactivated", name="account_status_enum"),
        default="pending_verification",
        index=True,
    )
    last_seen_at = Column(DateTime, nullable=True)
    password_reset_token = Column(String(255), nullable=True, index=True)
    password_reset_expires = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    # Relationships
    listings = relationship("Listing", back_populates="owner", cascade="all, delete-orphan")
    favorites = relationship("Favorite", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    reports_filed = relationship("Report", back_populates="reporter", foreign_keys="Report.reporter_user_id")
    payments = relationship("Payment", back_populates="user", cascade="all, delete-orphan")
    promotions = relationship("Promotion", back_populates="user", cascade="all, delete-orphan")
    audit_logs = relationship("AuditLog", back_populates="admin_user")
