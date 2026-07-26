from datetime import datetime

from pydantic import BaseModel, ConfigDict, HttpUrl


class URLCreate(BaseModel):
    target_url: HttpUrl


class URLResponse(BaseModel):
    short_code: str
    target_url: str
    clicks: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
