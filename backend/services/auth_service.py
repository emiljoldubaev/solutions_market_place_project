from datetime import datetime, timedelta, timezone
from typing import Optional, Dict
from jose import JWTError, jwt
import bcrypt
from config import settings
from exceptions import UnauthorizedError


def hash_password(password: str) -> str:
    """Hash a plain text password using bcrypt."""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain text password against its hash."""
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"), 
            hashed_password.encode("utf-8")
        )
    except Exception:
        return False


def create_access_token(user_id: int, role: str, email: str, expires_delta: Optional[timedelta] = None) -> str:
    """
    Create a JWT access token for the user.
    Claims: sub (user_id), role, email, exp (expiration time).
    """
    to_encode = {
        "sub": str(user_id),
        "role": role,
        "email": email
    }
    
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    
    encoded_jwt = jwt.encode(
        to_encode, 
        settings.JWT_SECRET_KEY, 
        algorithm=settings.JWT_ALGORITHM
    )
    return encoded_jwt


def decode_access_token(token: str) -> Dict[str, str]:
    """
    Decode and validate a JWT access token.
    Raises UnauthorizedError if the token is invalid or expired.
    """
    try:
        payload = jwt.decode(
            token, 
            settings.JWT_SECRET_KEY, 
            algorithms=[settings.JWT_ALGORITHM]
        )
        return payload
    except JWTError:
        raise UnauthorizedError("Invalid or expired token")
def get_user_id_from_token(token: str) -> int:
    """Extract user_id from a validated JWT token."""
    payload = decode_access_token(token)
    user_id = payload.get("sub")
    if not user_id:
        raise UnauthorizedError("Invalid token: missing subject")
    return int(user_id)
