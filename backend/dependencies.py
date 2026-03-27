from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from typing import Optional

from database import get_db
from models.user import User
from exceptions import UnauthorizedError, ForbiddenError
from services.auth_service import decode_access_token


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

optional_oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/auth/login",
    auto_error=False  # Crucial for optional auth
)


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    """
    Extract current user from JWT token.
    Raises 401 if token is invalid/expired or user not found.
    Raises 403 if user is blocked or deactivated.
    """
    payload = decode_access_token(token)
    user_id = payload.get("sub")
    
    if not user_id:
        raise UnauthorizedError("Invalid token: missing subject")
        
    user = db.query(User).filter(User.id == int(user_id)).first()
    
    if not user:
        raise UnauthorizedError("User not found")
        
    if user.account_status in ["blocked", "suspended"]:
        raise ForbiddenError("Account is suspended")
        
    if user.account_status == "deactivated":
        raise ForbiddenError("Account is deactivated")
        
    return user


def get_optional_user(
    token: Optional[str] = Depends(optional_oauth2_scheme),
    db: Session = Depends(get_db)
) -> Optional[User]:
    """
    Returns the current user if a valid token is provided, 
    otherwise returns None without raising an error.
    """
    if not token:
        return None
    try:
        payload = decode_access_token(token)
        user_id = payload.get("sub")
        if not user_id:
            return None
        return db.query(User).filter(User.id == int(user_id)).first()
    except Exception:
        return None


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """Require the current user to be an admin."""
    if current_user.role != "admin":
        raise ForbiddenError("Admin access required")
    return current_user


def require_active(current_user: User = Depends(get_current_user)) -> User:
    """Require the current user to have active status."""
    if current_user.account_status != "active":
        raise ForbiddenError("Account is not active")
    return current_user
