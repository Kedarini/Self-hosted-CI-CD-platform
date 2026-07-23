from sqlalchemy import Column, Integer, String, DateTime, func
from app.database import Base


class URL(Base):
    __tablename__ = "urls"

    id = Column(Integer, primary_key=True)
    short_code = Column(String, unique=True, index=True)
    target_url = Column(String)
    clicks = Column(Integer, default=0)
    created_at = Column(DateTime, server_default=func.now())
