import random
import string
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app import models, schemas
from app.database import Base, engine, get_db


def generate_short_code(length: int = 6) -> str:
    chars = string.ascii_letters + string.digits
    return "".join(random.choices(chars, k=length))


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="URL Shortener", lifespan=lifespan)

Instrumentator().instrument(app).expose(app)


@app.post("/shorten", response_model=schemas.URLResponse, status_code=201)
def shorten_url(payload: schemas.URLCreate, db: Session = Depends(get_db)):
    code = generate_short_code()

    url_entry = models.URL(short_code=code, target_url=str(payload.target_url))

    db.add(url_entry)
    db.commit()
    db.refresh(url_entry)

    return url_entry


@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ok"}
    except SQLAlchemyError:
        raise HTTPException(status_code=503, detail="database unavailable")


@app.get("/stats/{short_code}", response_model=schemas.URLResponse)
def get_stats(short_code: str, db: Session = Depends(get_db)):
    url_entry = db.query(models.URL).filter(models.URL.short_code == short_code).first()
    if not url_entry:
        raise HTTPException(status_code=404, detail="short code not found")
    return url_entry


@app.get("/{short_code}")
def redirect_to_target(short_code: str, db: Session = Depends(get_db)):
    url_entry = db.query(models.URL).filter(models.URL.short_code == short_code).first()
    if not url_entry:
        raise HTTPException(status_code=404, detail="short code not found")

    url_entry.clicks += 1
    db.commit()
    return RedirectResponse(url=url_entry.target_url)
