"""Environment configuration.

Mirrors ../web/src/lib/config.ts and the sibling mudbase-showcase-social
Python port's app/config.py: fail fast at startup if a required collection/
project ID is missing, rather than surfacing a confusing error deep inside a
request handler later.

`board_id` and the `demo_*` fields default to this showcase's real,
already-provisioned values (see plan/build-plan.md) rather than being
required — this is a single-shared-board demo app, not a template for a
fresh project, so shipping working defaults (overridable via .env) matches
the reference web app's own NEXT_PUBLIC_BOARD_ID fallback in src/lib/config.ts.
"""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    mudbase_url: str = Field(default="https://cloud.mudbase.dev", alias="MUDBASE_URL")
    mudbase_project_id: str = Field(alias="MUDBASE_PROJECT_ID")
    lists_collection_id: str = Field(alias="LISTS_COLLECTION_ID")
    cards_collection_id: str = Field(alias="CARDS_COLLECTION_ID")
    activity_collection_id: str = Field(alias="ACTIVITY_COLLECTION_ID")

    # Single shared board — this app is not multi-tenant (see plan/build-plan.md). Must be a
    # real 24-hex-char ObjectId: Mudbase's query sanitizer validates any field whose name ends
    # in "Id" as an ObjectId reference, rejecting a slug like "main-board" server-side.
    board_id: str = Field(default="6a6d4072d07caabbbdfc5d3c", alias="BOARD_ID")

    session_secret_key: str = Field(alias="SESSION_SECRET_KEY")
    session_cookie_name: str = Field(default="mudbase_showcase_kanban_session", alias="SESSION_COOKIE_NAME")
    session_https_only: bool = Field(default=False, alias="SESSION_HTTPS_ONLY")

    # Quick sign-in demo accounts for the /login page — same three already-verified accounts
    # documented in plan/build-plan.md. Not a production secret: this whole app is a public,
    # single-shared-board showcase and these credentials are already published in this
    # project's own README/build-plan. Override via .env for a private deployment.
    demo_owner_email: str = Field(default="kanban.owner.demo@gmail.com", alias="DEMO_OWNER_EMAIL")
    demo_member_email: str = Field(default="kanban.member.demo@gmail.com", alias="DEMO_MEMBER_EMAIL")
    demo_viewer_email: str = Field(default="kanban.viewer.demo@gmail.com", alias="DEMO_VIEWER_EMAIL")
    demo_password: str = Field(default="KanbanTest123!", alias="DEMO_PASSWORD")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Cached so env parsing/validation happens once per process, not per request."""
    return Settings()  # type: ignore[call-arg]  # values come from the environment/.env file
