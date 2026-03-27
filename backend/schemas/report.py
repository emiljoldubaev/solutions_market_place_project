from pydantic import BaseModel, ConfigDict, field_validator
from typing import Optional
from datetime import datetime

class ReportCreate(BaseModel):
    target_type: str
    target_id: int
    reason_code: str
    reason_text: Optional[str] = None

    @field_validator('reason_text', mode='before')
    @classmethod
    def strip_whitespace(cls, v):
        if isinstance(v, str):
            return v.strip()
        return v

class ReportOut(BaseModel):
    id: int
    reporter_id: int
    target_type: str
    target_id: int
    reason_code: str
    reason_text: Optional[str] = None
    status: str
    resolution_notes: Optional[str] = None
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
