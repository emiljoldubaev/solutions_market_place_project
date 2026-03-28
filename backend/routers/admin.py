import math
from fastapi import APIRouter, Depends, Request, Form, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy import func, desc, or_
from typing import Optional

from database import get_db
from models.user import User
from models.listing import Listing
from models.report import Report
from models.conversation import Conversation
from models.message import Message
from models.payment import Payment
from models.promotion import Promotion
from models.promotion_package import PromotionPackage
from models.category import Category
from models.audit_log import AuditLog
from services.auth_service import verify_password
from services.notification_service import notification_service
from security.admin_auth import require_SSR_admin

router = APIRouter(prefix="/admin", tags=["AdminUI"])
public_router = APIRouter()
protected_router = APIRouter(dependencies=[Depends(require_SSR_admin)])
templates = Jinja2Templates(directory="templates")

def flash(request: Request, message: str, category: str = "success"):
    if "_messages" not in request.session:
        request.session["_messages"] = []
    request.session["_messages"].append({"text": message, "category": category})

def get_flashed_messages(request: Request):
    return request.session.pop("_messages", [])

templates.env.globals['get_flashed_messages'] = get_flashed_messages

def get_pagination(total, page, page_size):
    return {
        "page": page,
        "page_size": page_size,
        "total": total,
        "pages": math.ceil(total / page_size) if total > 0 else 1
    }

def log_audit(db: Session, admin_id: int, action: str, entity_type: str, entity_id: int, details: str = None):
    log = AuditLog(admin_id=admin_id, action=action, entity_type=entity_type, entity_id=entity_id, details=details)
    db.add(log)
    db.commit()

# --- Auth ---
@public_router.get("/login", response_class=HTMLResponse)
def login_get(request: Request):
    if request.session.get("admin_id"):
        return RedirectResponse("/admin/dashboard", status_code=303)
    return templates.TemplateResponse("admin/login.html", {"request": request, "messages": get_flashed_messages(request)})

@public_router.post("/login")
def login_post(request: Request, email: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.password_hash) or user.role != "admin":
        flash(request, "Invalid credentials or not an admin", "danger")
        return RedirectResponse("/admin/login", status_code=303)
    request.session["admin_id"] = user.id
    flash(request, f"Welcome back, {user.full_name}!", "success")
    return RedirectResponse("/admin/dashboard", status_code=303)

@public_router.get("/logout")
def logout(request: Request):
    request.session.clear()
    flash(request, "Logged out successfully.", "info")
    return RedirectResponse("/admin/login", status_code=303)

# --- Dashboard ---
@protected_router.get("/dashboard", response_class=HTMLResponse)
def dashboard(request: Request, db: Session = Depends(get_db)):
    admin = request.state.admin

    stats = {
        "total_users": db.query(User).count(),
        "active_users": db.query(User).filter(User.account_status == "active").count(),
        "blocked_users": db.query(User).filter(User.account_status == "blocked").count(),
        "total_listings": db.query(Listing).count(),
        "approved_listings": db.query(Listing).filter(Listing.status == "approved").count(),
        "pending_listings": db.query(Listing).filter(Listing.status == "pending_review").count(),
        "total_conversations": db.query(Conversation).count(),
        "total_messages": db.query(Message).count(),
        "pending_reports": db.query(Report).filter(Report.status == "pending").count(),
        "total_payments": db.query(Payment).filter(Payment.status == "successful").count(),
        "total_revenue": db.query(func.sum(Payment.amount)).filter(Payment.status == "successful").scalar() or 0.0,
        "active_promotions": db.query(Promotion).filter(Promotion.status == "active").count()
    }
    return templates.TemplateResponse("admin/dashboard.html", {
        "request": request, "stats": stats, "messages": get_flashed_messages(request), "active_page": "dashboard"
    })

# --- Users ---
@protected_router.get("/users", response_class=HTMLResponse)
def list_users(request: Request, search: str = "", page: int = 1, db: Session = Depends(get_db)):
    admin = request.state.admin
    page_size = 20
    query = db.query(User)
    if search:
        query = query.filter(User.email.ilike(f"%{search}%") | User.full_name.ilike(f"%{search}%"))
    total = query.count()
    users = query.order_by(desc(User.created_at)).offset((page-1)*page_size).limit(page_size).all()
    pag = get_pagination(total, page, page_size)
    return templates.TemplateResponse("admin/users/list.html", {
        "request": request, "users": users, "pagination": pag, "search": search,
        "messages": get_flashed_messages(request), "active_page": "users"
    })

@protected_router.get("/users/{id}", response_class=HTMLResponse)
def user_detail(request: Request, id: int, db: Session = Depends(get_db)):
    admin = request.state.admin
    user = db.query(User).filter(User.id == id).first()
    listings = db.query(Listing).filter(Listing.owner_id == id).all()
    reports = db.query(Report).filter(Report.reporter_user_id == id).all()
    return templates.TemplateResponse("admin/users/detail.html", {
        "request": request, "user": user, "listings": listings, "reports": reports,
        "messages": get_flashed_messages(request), "active_page": "users"
    })

@protected_router.post("/users/{id}/suspend")
def suspend_user(request: Request, id: int, db: Session = Depends(get_db)):
    admin = request.state.admin
    user = db.query(User).filter(User.id == id).first()
    if user:
        user.account_status = "blocked"
        db.commit()
        log_audit(db, admin.id, "suspend_user", "user", id)
        flash(request, f"User {user.email} suspended.", "warning")
    return RedirectResponse(f"/admin/users/{id}", status_code=303)

@protected_router.post("/users/{id}/unsuspend")
def unsuspend_user(request: Request, id: int, db: Session = Depends(get_db)):
    admin = request.state.admin
    user = db.query(User).filter(User.id == id).first()
    if user:
        user.account_status = "active"
        db.commit()
        log_audit(db, admin.id, "unsuspend_user", "user", id)
        flash(request, f"User {user.email} unsuspended.", "success")
    return RedirectResponse(f"/admin/users/{id}", status_code=303)

# --- Listings ---
@protected_router.get("/listings", response_class=HTMLResponse)
def list_listings(request: Request, status: str = "", category_id: int = 0, page: int = 1, db: Session = Depends(get_db)):
    admin = request.state.admin
    query = db.query(Listing)
    if status: query = query.filter(Listing.status == status)
    if category_id: query = query.filter(Listing.category_id == category_id)
    total = query.count()
    listings = query.order_by(desc(Listing.created_at)).offset((page-1)*20).limit(20).all()
    categories = db.query(Category).all()
    pag = get_pagination(total, page, 20)
    return templates.TemplateResponse("admin/listings/list.html", {
        "request": request, "listings": listings, "pagination": pag, "status": status, "category_id": category_id,
        "categories": categories, "messages": get_flashed_messages(request), "active_page": "listings"
    })

@protected_router.get("/listings/{id}", response_class=HTMLResponse)
def listing_detail(request: Request, id: int, db: Session = Depends(get_db)):
    admin = request.state.admin
    listing = db.query(Listing).filter(Listing.id == id).first()
    return templates.TemplateResponse("admin/listings/detail.html", {
        "request": request, "listing": listing, "messages": get_flashed_messages(request), "active_page": "listings"
    })

@protected_router.post("/listings/{id}/approve")
def approve_listing(request: Request, id: int, db: Session = Depends(get_db)):
    admin = request.state.admin
    listing = db.query(Listing).filter(Listing.id == id).first()
    if listing:
        listing.status = "approved"
        db.commit()
        log_audit(db, admin.id, "approve_listing", "listing", id)
        notification_service.create_notification(db, listing.owner_id, "listing_approved", "Approved", f"Your listing '{listing.title}' was approved.", "listing", id)
        flash(request, "Listing approved.", "success")
    return RedirectResponse(f"/admin/listings/{id}", status_code=303)

@protected_router.post("/listings/{id}/reject")
def reject_listing(request: Request, id: int, note: str = Form(...), db: Session = Depends(get_db)):
    admin = request.state.admin
    listing = db.query(Listing).filter(Listing.id == id).first()
    if listing:
        listing.status = "rejected"
        db.commit()
        log_audit(db, admin.id, "reject_listing", "listing", id, note)
        notification_service.create_notification(db, listing.owner_id, "listing_rejected", "Rejected", f"Your listing '{listing.title}' was rejected: {note}", "listing", id)
        flash(request, "Listing rejected.", "danger")
    return RedirectResponse(f"/admin/listings/{id}", status_code=303)

@protected_router.post("/listings/{id}/archive")
def archive_listing(request: Request, id: int, db: Session = Depends(get_db)):
    admin = request.state.admin
    listing = db.query(Listing).filter(Listing.id == id).first()
    if listing:
        listing.status = "archived"
        db.commit()
        log_audit(db, admin.id, "archive_listing", "listing", id)
        flash(request, "Listing archived.", "warning")
    return RedirectResponse(f"/admin/listings/{id}", status_code=303)

@protected_router.post("/listings/{id}/feature")
def toggle_feature_listing(request: Request, id: int, db: Session = Depends(get_db)):
    admin = request.state.admin
    listing = db.query(Listing).filter(Listing.id == id).first()
    if listing:
        listing.is_featured = not listing.is_featured
        db.commit()
        log_audit(db, admin.id, "feature_listing", "listing", id, str(listing.is_featured))
        flash(request, f"Listing featured status updated.", "info")
    return RedirectResponse(f"/admin/listings/{id}", status_code=303)

# --- Reports ---
@protected_router.get("/reports", response_class=HTMLResponse)
def list_reports(request: Request, status: str = "pending", page: int = 1, db: Session = Depends(get_db)):
    admin = request.state.admin
    query = db.query(Report)
    if status: query = query.filter(Report.status == status)
    total = query.count()
    reports = query.order_by(desc(Report.created_at)).offset((page-1)*20).limit(20).all()
    pag = get_pagination(total, page, 20)
    return templates.TemplateResponse("admin/reports/list.html", {
        "request": request, "reports": reports, "pagination": pag, "status": status,
        "messages": get_flashed_messages(request), "active_page": "reports"
    })

@protected_router.post("/reports/{id}/resolve")
def resolve_report(request: Request, id: int, resolution_note: str = Form(...), action_opt: str = Form("resolve"), db: Session = Depends(get_db)):
    admin = request.state.admin
    rep = db.query(Report).filter(Report.id == id).first()
    if rep:
        rep.status = "resolved" if action_opt == "resolve" else "dismissed"
        rep.resolution_note = resolution_note
        rep.reviewed_by_admin_id = admin.id
        rep.reviewed_at = func.now()
        db.commit()
        log_audit(db, admin.id, f"report_{action_opt}", "report", id, resolution_note)
        if rep.status == "resolved":
            notification_service.create_notification(db, rep.reporter_user_id, "report_resolved", "Report Resolved", "Your report was resolved.", "report", id)
        flash(request, f"Report {action_opt} successfully.", "success")
    return RedirectResponse("/admin/reports", status_code=303)

# --- Categories ---
@protected_router.get("/categories", response_class=HTMLResponse)
def list_categories(request: Request, db: Session = Depends(get_db)):
    admin = request.state.admin
    categories = db.query(Category).all()
    return templates.TemplateResponse("admin/categories/list.html", {
        "request": request, "categories": categories, "messages": get_flashed_messages(request), "active_page": "categories"
    })

@protected_router.post("/categories")
def create_category(request: Request, name: str = Form(...), db: Session = Depends(get_db)):
    admin = request.state.admin
    slug = name.lower().replace(" ", "-")
    cat = Category(name=name, slug=slug)
    db.add(cat)
    db.commit()
    log_audit(db, admin.id, "create_category", "category", cat.id)
    flash(request, "Category created.", "success")
    return RedirectResponse("/admin/categories", status_code=303)

@protected_router.post("/categories/{id}/toggle")
def toggle_category(request: Request, id: int, db: Session = Depends(get_db)):
    admin = request.state.admin
    cat = db.query(Category).filter(Category.id == id).first()
    if cat:
        cat.is_active = not cat.is_active
        db.commit()
        log_audit(db, admin.id, "toggle_category", "category", id, str(cat.is_active))
        flash(request, "Category status updated.", "info")
    return RedirectResponse("/admin/categories", status_code=303)

# --- Payments ---
@protected_router.get("/payments", response_class=HTMLResponse)
def list_payments(request: Request, page: int = 1, db: Session = Depends(get_db)):
    admin = request.state.admin
    query = db.query(Payment).order_by(desc(Payment.created_at))
    total = query.count()
    payments = query.offset((page-1)*20).limit(20).all()
    pag = get_pagination(total, page, 20)
    return templates.TemplateResponse("admin/payments/list.html", {
        "request": request, "payments": payments, "pagination": pag,
        "messages": get_flashed_messages(request), "active_page": "payments"
    })

# --- Promotions ---
@protected_router.get("/promotions", response_class=HTMLResponse)
def list_promotions(request: Request, status: str = "active", page: int = 1, db: Session = Depends(get_db)):
    admin = request.state.admin
    query = db.query(Promotion)
    if status: query = query.filter(Promotion.status == status)
    total = query.count()
    promotions = query.order_by(desc(Promotion.created_at)).offset((page-1)*20).limit(20).all()
    pag = get_pagination(total, page, 20)
    return templates.TemplateResponse("admin/promotions/list.html", {
        "request": request, "promotions": promotions, "pagination": pag, "status": status,
        "messages": get_flashed_messages(request), "active_page": "promotions"
    })

@protected_router.post("/promotions/{id}/deactivate")
def deactivate_promotion(request: Request, id: int, db: Session = Depends(get_db)):
    admin = request.state.admin
    promo = db.query(Promotion).filter(Promotion.id == id).first()
    if promo:
        promo.status = "expired"
        db.commit()
        log_audit(db, admin.id, "deactivate_promo", "promotion", id)
        flash(request, "Promotion deactivated.", "warning")
    return RedirectResponse("/admin/promotions", status_code=303)

router.include_router(public_router)
router.include_router(protected_router)
