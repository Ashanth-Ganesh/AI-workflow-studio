import uuid

from pydantic import BaseModel, ConfigDict, EmailStr


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    primary_email: EmailStr
    display_name: str
    avatar_url: str | None


class SessionResponse(BaseModel):
    user: UserResponse


class ProviderAvailabilityResponse(BaseModel):
    providers: dict[str, bool]
