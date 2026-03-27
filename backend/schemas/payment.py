from pydantic import BaseModel, ConfigDict
from datetime import datetime
from decimal import Decimal

class PaymentInitiate(BaseModel):
    promotion_id: int
    payment_method: str = "card"

class PaymentConfirm(BaseModel):
    mock_status: str

class PaymentOut(BaseModel):
    id: int
    user_id: int
    promotion_id: int
    amount: Decimal
    currency: str
    status: str
    payment_method: str
    transaction_id: str
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
