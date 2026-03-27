from sqlalchemy.orm import Session
from models.report import Report
from schemas.report import ReportCreate

class ReportService:
    @staticmethod
    def create_report(db: Session, user_id: int, data: ReportCreate) -> Report:
        """Create a new report in pending status."""
        report = Report(
            reporter_user_id=user_id,
            target_type=data.target_type,
            target_id=data.target_id,
            reason_code=data.reason_code,
            reason_text=data.reason_text,
            status="pending"
        )
        db.add(report)
        db.commit()
        db.refresh(report)
        return report

    @staticmethod
    def get_my_reports(db: Session, user_id: int, page: int = 1, page_size: int = 20):
        """Get paginated reports submitted by a user."""
        query = db.query(Report).filter(Report.reporter_user_id == user_id).order_by(Report.created_at.desc())
        total = query.count()
        items = query.offset((page - 1) * page_size).limit(page_size).all()
        return items, total

    @staticmethod
    def resolve_report(db: Session, report_id: int, resolution_notes: str = None) -> Report:
        """Resolve a report and trigger notification. (Admin operation)"""
        from services.notification_service import notification_service
        
        report = db.query(Report).filter(Report.id == report_id).first()
        if report and report.status != "resolved":
            report.status = "resolved"
            if resolution_notes:
                report.resolution_notes = resolution_notes
            db.commit()
            db.refresh(report)
            
            # Trigger notification
            notification_service.create_notification(
                db=db, user_id=report.reporter_user_id, type="report_resolved",
                title="Report Resolved", body="Your report has been reviewed and resolved.",
                reference_type="report", reference_id=report.id
            )
        return report

report_service = ReportService()
