export function formatRelativeTime(iso: string): string {
  const then = new Date(iso).getTime();
  const now = Date.now();
  const diffSeconds = Math.round((now - then) / 1000);

  if (diffSeconds < 5) return "just now";
  if (diffSeconds < 60) return `${diffSeconds}s`;
  const diffMinutes = Math.round(diffSeconds / 60);
  if (diffMinutes < 60) return `${diffMinutes}m`;
  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours}h`;
  const diffDays = Math.round(diffHours / 24);
  if (diffDays < 7) return `${diffDays}d`;
  return new Intl.DateTimeFormat("en-US", { dateStyle: "medium" }).format(new Date(iso));
}

export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  const first = parts[0]?.[0] ?? "";
  const last = parts.length > 1 ? (parts[parts.length - 1]?.[0] ?? "") : "";
  return (first + last).toUpperCase();
}

/** djb2, a small deterministic string hash — used below to derive a stable pseudo-ObjectId,
 * nothing more. */
function djb2(str: string): number {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = (hash * 33) ^ str.charCodeAt(i);
  }
  return hash >>> 0;
}

/**
 * There is no `users` collection in this app's data model (see
 * plan/build-plan.md), so an assignee is captured as a free-typed name rather
 * than looked up from a directory. `cards.assigneeId` is schema-typed as an
 * ObjectId reference on the live platform — a plain slug like "mia-member" is
 * rejected with "Invalid ObjectId format for assigneeId". This derives a
 * stable, valid-looking 24-hex-char id from the typed name (the same name
 * always maps to the same id) purely so `assigneeId` passes that format check
 * and is never left orphaned from `assigneeName` — it is not a real user
 * lookup key. Byte-for-byte port of web/src/lib/utils.ts's `pseudoObjectId()`.
 */
export function pseudoObjectId(seed: string): string {
  const trimmed = seed.trim().toLowerCase();
  let hex = "";
  for (let round = 0; hex.length < 24; round++) {
    hex += djb2(`${trimmed}:${round}`).toString(16).padStart(8, "0");
  }
  return hex.slice(0, 24);
}
