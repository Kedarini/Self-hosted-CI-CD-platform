import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

postgresql_url = os.getenv("DATABASE_URL")

engine = create_engine(postgresql_url)

SessionLocal = sessionmaker(bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
