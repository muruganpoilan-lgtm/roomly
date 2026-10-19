import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .db import pool
from .routes import admin, auth_routes, bookings, owner, payments, public
from .storage import upload_root


log = logging.getLogger("roomly")


async def _expire_loop():
    """Every minute, put rooms from unpaid holds back on sale."""
    while True:
        try:
            freed = await asyncio.to_thread(bookings.expire_holds)
            if freed:
                log.info("Released %s expired holds", freed)
        except Exception:
            log.exception("Could not release expired holds")
        await asyncio.sleep(60)


@asynccontextmanager
async def lifespan(app: FastAPI):
    pool.open()
    task = asyncio.create_task(_expire_loop())
    yield
    task.cancel()
    pool.close()


app = FastAPI(title="Roomly API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Uploaded photos are served from here in development. In production, serve them from S3 or a CDN.
app.mount("/uploads", StaticFiles(directory=upload_root()), name="uploads")

app.include_router(auth_routes.router)
app.include_router(owner.router)
app.include_router(public.router)
app.include_router(bookings.router)
app.include_router(payments.router)
app.include_router(admin.router)


@app.get("/health")
def health():
    return {"ok": True}
