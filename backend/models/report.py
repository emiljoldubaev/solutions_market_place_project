from sqlalchemy import Column, Integer, String, Text, Enum, DateTime, ForeignKey, func, Index
from sqlalchemy.orm import relationship
from database import Base


class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True, autoincrement=True)
    reporter_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    target_type = Column(Enum("listing", "user", name="report_target_type_enum"), nullable=False)
    target_id = Column(Integer, nullable=False)
    reason_code = Column(
        Enum(
            "spam", "fake_listing", "scam", "duplicate",
            "offensive", "prohibited", "harassment",
            name="report_reason_enum",
        ),
        nullable=False,
    )
    reason_text = Column(Text, nullable=True)
    status = Column(
        Enum("pending", "reviewed", "resolved", "dismissed", name="report_status_enum"),
        default="pending",
        index=True,
    )
    resolution_note = Column(Text, nullable=True)
    reviewed_by_admin_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    reviewed_at = Column(DateTime, nullable=True)

    __table_args__ = (
        Index("idx_reports_target", "target_type", "target_id"),
    )

    # Relationships
    reporter = relationship("User", back_populates="reports_filed", foreign_keys=[reporter_user_id])
    reviewed_by = relationship("User", foreign_keys=[reviewed_by_admin_id])
