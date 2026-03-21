from pydantic import BaseModel, EmailStr, Field
import uuid
from datetime import datetime


class RegisterRequest(BaseModel):
    company_name: str = Field(..., min_length=2, max_length=255)
    corporate_email: EmailStr
    contact_person: str = Field(..., min_length=2, max_length=255)
    password: str = Field(..., min_length=8)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # seconds


class RefreshRequest(BaseModel):
    refresh_token: str


class UserResponse(BaseModel):
    id: uuid.UUID
    company_name: str
    corporate_email: str
    contact_person: str
    is_active: bool
    is_verified: bool
    biometric_enabled: bool
    hardware_key_enabled: bool
    created_at: datetime
    last_login: datetime | None

    model_config = {"from_attributes": True}


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8)
