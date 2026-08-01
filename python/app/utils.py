"""Small formatting helpers. Ported from the sibling mudbase-showcase-social
Python port's app/utils.py, plus `pseudo_object_id` — a Python port of
../web/src/lib/utils.ts::pseudoObjectId (see that file's docstring for the
full "why": `cards.assigneeId` is schema-typed as an ObjectId reference, not
a free-form string, and there is no `users` collection to look a real one up
from — this derives a stable, valid-looking 24-hex-char id from the
free-typed assignee name so `assigneeId` always passes the platform's
ObjectId-format check and is never left orphaned from `assigneeName`. It is
not a real user lookup key.
"""

from datetime import datetime


def format_date(value: datetime | str | None) -> str:
    """Formats an ISO timestamp (or already-parsed datetime) for display."""
    if value is None:
        return ""
    parsed: datetime
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return value
    else:
        parsed = value
    return parsed.strftime("%b %-d, %Y, %-I:%M %p")


def initial(name: str | None) -> str:
    """First letter of a display name, uppercased, for the avatar circle.
    Falls back to "?" for an empty/missing name."""
    stripped = (name or "").strip()
    return stripped[0].upper() if stripped else "?"


def relative_time(value: datetime | str | None) -> str:
    """A short "2h ago"-style label for the activity feed, falling back to
    `format_date` for anything older than a week (where a relative label
    stops being useful)."""
    if value is None:
        return ""
    parsed: datetime
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return value
    else:
        parsed = value

    now = datetime.now(parsed.tzinfo) if parsed.tzinfo else datetime.now()
    delta_seconds = (now - parsed).total_seconds()
    if delta_seconds < 60:
        return "just now"
    if delta_seconds < 3600:
        minutes = int(delta_seconds // 60)
        return f"{minutes}m ago"
    if delta_seconds < 86400:
        hours = int(delta_seconds // 3600)
        return f"{hours}h ago"
    if delta_seconds < 604800:
        days = int(delta_seconds // 86400)
        return f"{days}d ago"
    return format_date(parsed)


_DJB2_MASK = 0xFFFFFFFF


def _djb2(value: str) -> int:
    """djb2, a small deterministic string hash — used below to derive a
    stable pseudo-ObjectId, nothing more. Matches the algorithm in
    ../web/src/lib/utils.ts so both ports produce the same id for the same
    name, though that equivalence is a nicety, not a requirement."""
    hash_value = 5381
    for char in value:
        hash_value = ((hash_value * 33) ^ ord(char)) & _DJB2_MASK
    return hash_value


def pseudo_object_id(seed: str) -> str:
    """Derives a stable, valid-looking 24-hex-char id from a free-typed
    name — the same name always maps to the same id. Not a real user lookup
    key; see module docstring."""
    trimmed = seed.strip().lower()
    hex_str = ""
    round_number = 0
    while len(hex_str) < 24:
        hex_str += format(_djb2(f"{trimmed}:{round_number}"), "08x")
        round_number += 1
    return hex_str[:24]
