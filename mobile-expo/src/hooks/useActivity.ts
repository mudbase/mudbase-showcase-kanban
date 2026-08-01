import { useQuery } from "@tanstack/react-query";
import { mudbaseClient } from "@/api/client";
import { activityEntrySchema } from "@/api/schemas";
import { ACTIVITY_COLLECTION_ID, BOARD_ID } from "@/config/env";

const FEED_LIMIT = 200;

/** Reverse-chronological activity feed for the shared board. Mirrors web/src/hooks/useActivity.ts. */
export function useActivityFeed() {
  return useQuery({
    queryKey: ["collection", ACTIVITY_COLLECTION_ID, { boardId: BOARD_ID, feed: true }],
    queryFn: () =>
      mudbaseClient.listDocuments(activityEntrySchema, ACTIVITY_COLLECTION_ID, {
        filter: { boardId: BOARD_ID },
        sort: "-createdAt",
        limit: FEED_LIMIT,
      }),
  });
}
