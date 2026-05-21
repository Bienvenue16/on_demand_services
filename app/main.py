from contextlib import asynccontextmanager
from bson import ObjectId
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.encoders import ENCODERS_BY_TYPE
from app.core.config import settings
from app.core.database import init_db
from app.core.exceptions import add_exception_handlers
from app.routers import auth, users, requests, proposals, messages, websocket, \
                        reviews, notifications, categories, uploads, admin

# Sérialise tous les ObjectId MongoDB en string automatiquement
ENCODERS_BY_TYPE[ObjectId] = str


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)

add_exception_handlers(app)

cors_origins = ["*"] if settings.DEBUG else settings.CORS_ORIGINS.split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=not settings.DEBUG,  # credentials incompatible avec allow_origins=["*"]
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=settings.UPLOAD_DIR), name="static") 

app.include_router(auth.router,          prefix="/auth",          tags=["Auth"])
app.include_router(users.router,         prefix="/users",         tags=["Users"])
app.include_router(requests.router,      prefix="/requests",      tags=["Requests"])
app.include_router(proposals.router,     prefix="/proposals",     tags=["Proposals"])
app.include_router(messages.router,      prefix="/messages",      tags=["Messages"])
app.include_router(websocket.router,     prefix="/ws",            tags=["WebSocket"])
app.include_router(reviews.router,       prefix="/reviews",       tags=["Reviews"])
app.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])
app.include_router(categories.router,    prefix="/categories",    tags=["Categories"])
app.include_router(uploads.router,       prefix="/uploads",       tags=["Uploads"])
app.include_router(admin.router,         prefix="/admin",         tags=["Admin"])
