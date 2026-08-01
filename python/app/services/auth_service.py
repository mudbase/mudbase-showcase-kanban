"""Login/logout only — see app/mudbase_client.py module docstring for why
there is no register/anonymous-session service here."""

import asyncio
from typing import Any

from app.mudbase_client import login_sync, logout_sync


async def login(email: str, password: str) -> dict[str, Any]:
    return await asyncio.to_thread(login_sync, email, password)


async def logout(access_token: str) -> None:
    await asyncio.to_thread(logout_sync, access_token)
