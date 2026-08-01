"""Mirrors the zod schema in ../web/src/components/auth/LoginForm.tsx. There
is no register schema here — this app has no self-registration UI (see
plan/build-plan.md "Auth Model"), only sign-in with an already-provisioned
owner/member/viewer account."""

from pydantic import BaseModel, EmailStr, Field


class LoginFormValues(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)
