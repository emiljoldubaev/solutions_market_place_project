from fastapi import APIRouter, Depends, status, Response, Body
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
from typing import Optional
import secrets

from database import get_db
from models.user import User
from schemas.auth import (
    RegisterRequest, LoginRequest, TokenResponse, 
    ForgotPasswordRequest, ResetPasswordRequest, ChangePasswordRequest
)
from services.auth_service import (
    hash_password, verify_password, create_access_token
)
from dependencies import get_current_user
from exceptions import ConflictError, UnauthorizedError, ForbiddenError


router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(request: RegisterRequest, db: Session = Depends(get_db)):
    # Check if user already exists
    if db.query(User).filter(User.email == request.email).first():
        raise ConflictError("Email already registered")
        
    # Create new user
    new_user = User(
        full_name=request.full_name,
        email=request.email,
        password_hash=hash_password(request.password),
        preferred_language=request.preferred_language,
        account_status="pending_verification",
        role="user"
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Generate token
    access_token = create_access_token(
        user_id=new_user.id, 
        role=new_user.role, 
        email=new_user.email
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": new_user
    }


@router.post("/login", response_model=TokenResponse)
def login(
    request: Optional[LoginRequest] = Body(None),
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    # If JSON request body is provided, use it. Otherwise use form_data (for Swagger)
    email = None
    password = None
    
    if request:
        email = request.email
        password = request.password
    elif form_data:
        email = form_data.username
        password = form_data.password
        
    if not email or not password:
         raise UnauthorizedError("Missing email or password")
    
    user = db.query(User).filter(User.email == email).first()
    
    if not user or not verify_password(password, user.password_hash):
        raise UnauthorizedError("Invalid email or password")
        
    # Check account status
    if user.account_status in ["blocked", "suspended"]:
        raise ForbiddenError("Account is suspended")
        
    if user.account_status == "deactivated":
        raise ForbiddenError("Account is deactivated")
        
    # Update last seen
    user.last_seen_at = datetime.now(timezone.utc)
    db.commit()
    
    access_token = create_access_token(
        user_id=user.id, 
        role=user.role, 
        email=user.email
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user
    }


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)):
    return {"message": "Successfully logged out"}


@router.post("/forgot-password")
def forgot_password(request: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == request.email).first()
    
    if not user:
        # For security, we might not want to reveal if email exists, 
        # but the spec says "return token directly in response (mock flow)"
        return {"message": "If the email is registered, a reset link will be sent.", "reset_token": "mock-not-found"}

    # Generate pseudo-random token
    reset_token = secrets.token_urlsafe(32)
    user.password_reset_token = reset_token
    user.password_reset_expires = datetime.now(timezone.utc) + timedelta(hours=1)
    
    db.commit()
    
    return {
        "message": "Password reset token generated (mock flow)",
        "reset_token": reset_token
    }


@router.post("/reset-password")
def reset_password(request: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(
        User.password_reset_token == request.reset_token,
        User.password_reset_expires > datetime.now(timezone.utc)
    ).first()
    
    if not user:
        raise UnauthorizedError("Invalid or expired reset token")
        
    # Update password and clear token
    user.password_hash = hash_password(request.new_password)
    user.password_reset_token = None
    user.password_reset_expires = None
    
    db.commit()
    
    return {"message": "Password has been reset successfully"}


@router.post("/change-password")
def change_password(request: ChangePasswordRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if not verify_password(request.current_password, current_user.password_hash):
        raise UnauthorizedError("Incorrect current password")
        
    current_user.password_hash = hash_password(request.new_password)
    db.commit()
    
    return {"message": "Password changed successfully"}
