from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.database import get_db

app = FastAPI(title="URL Shortener")


@app.post("/shorten")
def shorten_url():
    pass


@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ok"}
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")


@app.get("/stats/{short_code}")
def get_stats():
    pass


@app.get("/{short_code}")
def redirect_to_target():
    pass
