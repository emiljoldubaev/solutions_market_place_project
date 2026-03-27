from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, func
from sqlalchemy.orm import relationship
from database import Base

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    admin_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    action = Column(String(50), nullable=False) # e.g., approve_listing, suspend_user
    entity_type = Column(String(50), nullable=False) # e.g., listing, user, report
    entity_id = Column(Integer, nullable=False, index=True)
    details = Column(Text, nullable=True) # Context notes or reasons
    created_at = Column(DateTime, server_default=func.now())

    admin_user = relationship("User", back_populates="audit_logs", foreign_keys=[admin_id])
