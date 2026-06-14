ain · PY
# api/main.py

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes import auth, runs, files

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s — %(message)s",
)
log = logging.getLogger(__name__)


# ── Lifespan — runs on startup and shutdown ───────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("OmniDomain API starting up")
    yield
    log.info("OmniDomain API shutting down")


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="OmniDomain API",
    description="Multi-kingdom genomics platform — bacterial, fungal, plant WGS",
    version="0.2.0",
    lifespan=lifespan,
)

# ── CORS — allow Streamlit UI to call the API ─────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8501"],  # Streamlit default port
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routes ────────────────────────────────────────────────────────────────────
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(runs.router, prefix="/runs", tags=["runs"])
app.include_router(files.router, prefix="/files", tags=["files"])


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/health", tags=["health"])
def health():
    """Used by load balancer and CI to verify the API is running."""
    return {"status": "ok", "version": "0.2.0"}