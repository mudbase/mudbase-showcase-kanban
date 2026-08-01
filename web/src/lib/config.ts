function requireEnv(name: string, value: string | undefined): string {
  if (!value) throw new Error(`Missing required environment variable: ${name}`)
  return value
}

export const MUDBASE_PROJECT_ID = requireEnv(
  "NEXT_PUBLIC_MUDBASE_PROJECT_ID",
  process.env.NEXT_PUBLIC_MUDBASE_PROJECT_ID,
)
export const MUDBASE_URL = process.env.NEXT_PUBLIC_MUDBASE_URL ?? "https://cloud.mudbase.dev"

// Project publishable key - kept for parity with the platform dashboard; see .env.example for
// why every request in this app authenticates with a JWT instead.
export const MUDBASE_API_KEY = process.env.NEXT_PUBLIC_MUDBASE_API_KEY ?? ""

export const LISTS_COLLECTION_ID = requireEnv(
  "NEXT_PUBLIC_LISTS_COLLECTION_ID",
  process.env.NEXT_PUBLIC_LISTS_COLLECTION_ID,
)
export const CARDS_COLLECTION_ID = requireEnv(
  "NEXT_PUBLIC_CARDS_COLLECTION_ID",
  process.env.NEXT_PUBLIC_CARDS_COLLECTION_ID,
)
export const ACTIVITY_COLLECTION_ID = requireEnv(
  "NEXT_PUBLIC_ACTIVITY_COLLECTION_ID",
  process.env.NEXT_PUBLIC_ACTIVITY_COLLECTION_ID,
)

/** This is a single shared-board demo, not multi-tenant - every boardId field everywhere is
 * this one constant string (see plan/build-plan.md). Must be a real 24-hex-char ObjectId, not
 * an arbitrary slug: verified live that `lists.boardId`/`cards.boardId`/`activity.boardId` (and
 * `cards.assigneeId`) are validated by the platform's query sanitizer as ObjectId references,
 * which rejects a non-ObjectId value like "main-board" with "Invalid ObjectId format for
 * boardId". This is the id of the single document in the `boards` collection
 * (`6a6d405cd07caabbbdfc5c79`) provisioned for this app - see plan/build-plan.md. */
export const BOARD_ID = process.env.NEXT_PUBLIC_BOARD_ID ?? "6a6d4072d07caabbbdfc5d3c"
