"use client"

import { useDocuments } from "@/hooks/useCollection"
import { ACTIVITY_COLLECTION_ID, BOARD_ID } from "@/lib/config"
import type { ActivityEntry } from "@/types/activity"

const FEED_LIMIT = 200

/** Reverse-chronological activity feed for the shared board. */
export function useActivityFeed() {
  return useDocuments<ActivityEntry>(ACTIVITY_COLLECTION_ID, {
    filter: { boardId: BOARD_ID },
    sort: "-createdAt",
    limit: FEED_LIMIT,
  })
}
