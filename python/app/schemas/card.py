"""Mirrors ../web/src/types/card.ts. Field aliases match the raw Mudbase
document shape (camelCase, `_id`) so `BoardCard.model_validate(doc)` works
directly off a `DataApi` response dict — no separate mapping layer.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

_MAX_TITLE_LENGTH = 120
_MAX_DESCRIPTION_LENGTH = 2000
_MAX_ASSIGNEE_NAME_LENGTH = 80


class BoardCard(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    board_id: str = Field(alias="boardId")
    list_id: str = Field(alias="listId")
    title: str
    description: str | None = Field(default=None, alias="description")
    position: float
    assignee_id: str | None = Field(default=None, alias="assigneeId")
    assignee_name: str | None = Field(default=None, alias="assigneeName")
    created_by_id: str = Field(alias="createdById")
    created_by_name: str = Field(alias="createdByName")
    created_at: datetime | None = Field(default=None, alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")


class CardFormValues(BaseModel):
    """Validated shape of the card composer/edit form. Mirrors the zod
    schema implied by ../web/src/components/board/CardDialog.tsx — 120-char
    title cap, 2000-char description cap, per plan/build-plan.md."""

    title: str = Field(min_length=1, max_length=_MAX_TITLE_LENGTH)
    description: str = Field(default="", max_length=_MAX_DESCRIPTION_LENGTH)
    assignee_name: str = Field(default="", max_length=_MAX_ASSIGNEE_NAME_LENGTH)

    @field_validator("title")
    @classmethod
    def _strip_title(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("Give the card a title.")
        return stripped

    @field_validator("description", "assignee_name")
    @classmethod
    def _strip_optional(cls, value: str) -> str:
        return value.strip()
