"""Mirrors ../web/src/types/list.ts. Field aliases match the raw Mudbase
document shape (camelCase, `_id`) so `BoardList.model_validate(doc)` works
directly off a `DataApi` response dict — no separate mapping layer.

Named `list_.py` (not `list.py`) purely to avoid shadowing the builtin
`list` when imported as `from app.schemas import list_` elsewhere — this
project otherwise has no reason to import the module unqualified."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

_MAX_NAME_LENGTH = 60


class BoardList(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    board_id: str = Field(alias="boardId")
    name: str
    position: float
    created_at: datetime | None = Field(default=None, alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")


class ListFormValues(BaseModel):
    """Validated shape of the add/rename-list form. Mirrors the zod schema
    implied by ../web/src/components/board/AddListForm.tsx (60-char cap)."""

    name: str = Field(min_length=1, max_length=_MAX_NAME_LENGTH)

    @field_validator("name")
    @classmethod
    def _strip_name(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("Give the list a name.")
        return stripped
