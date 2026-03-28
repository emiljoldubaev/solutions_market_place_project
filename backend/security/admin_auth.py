from fastapi import Request, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
from models.user import User

def require_SSR_admin(request: Request, db: Session = Depends(get_db)):
    """
    Global dependency for Admin SSR routes.
    Redirects to login if unauthorized, preventing raw JSON errors for web users.
    """
    admin_id = request.session.get("admin_id")
    if not admin_id:
        raise HTTPException(
            status_code=status.HTTP_303_SEE_OTHER,
            headers={"Location": "/admin/login"}
        )
    
    admin = db.query(User).filter(User.id == admin_id, User.role == "admin").first()
    if not admin:
        request.session.clear()
        raise HTTPException(
            status_code=status.HTTP_303_SEE_OTHER,
            headers={"Location": "/admin/login"}
        )
    
    # Store the admin object in request state for downstream use
    request.state.admin = admin
    return admin
