from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
import logging

from config import settings
from database import engine, Base

# Import all models so they register with Base
import models  # noqa: F401
from routers import auth, users, listings, listing_images, favorites, conversations, notifications, reports, promotions, payments


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


app = FastAPI(
    title="Marketplace API",
    description="General Classified Marketplace Platform",
    version="1.0.0",
)

# CORS - allow all origins in development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve uploaded files
uploads_dir = os.path.join(os.path.dirname(__file__), settings.UPLOAD_DIR)
if os.path.exists(uploads_dir):
    app.mount("/uploads", StaticFiles(directory=uploads_dir), name="uploads")

# Include routers
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(listings.router)
app.include_router(listing_images.router)
app.include_router(favorites.router)
app.include_router(conversations.router)
app.include_router(notifications.router)
app.include_router(reports.router)
app.include_router(promotions.router)
app.include_router(payments.router)


@app.on_event("startup")
async def startup_event():
    """Create tables if they don't exist (dev convenience) and log startup."""
    logger.info("Application starting up...")
    Base.metadata.create_all(bind=engine)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Global exception handler to catch all unhandled exceptions
    and return a standard JSON error response.
    """
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )


@app.get("/", tags=["Health"])
def health_check():
    return {"status": "ok", "service": "Marketplace API", "version": "1.0.0"}


@app.get("/health", tags=["Health"])
def health():
    return {"status": "healthy"}
