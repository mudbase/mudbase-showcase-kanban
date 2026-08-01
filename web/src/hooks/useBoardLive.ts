"use client"

import { useEffect } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { getMudbaseSocket } from "@/lib/mudbase-socket"
import { useMudbase } from "@/lib/mudbase-provider"
import { LISTS_COLLECTION_ID, CARDS_COLLECTION_ID, ACTIVITY_COLLECTION_ID } from "@/lib/config"

interface RowEvent {
  projectId: string
  collectionId: string
  action: string
  data: { _id: string }
  timestamp: string
}

/**
 * Subscribes to the Socket.IO rooms for `lists`, `cards`, and `activity` so another signed-in
 * user's column add/rename/delete/reorder, card create/edit/move/delete, and every new activity
 * row all appear live, with no polling - the same `subscribe:collection` / `db:create` /
 * `db:update` / `db:delete` contract the social showcase's `usePostsLive` uses.
 *
 * Unlike that showcase (a single collection, manually patched into an infinite-query cache),
 * this board touches three collections whose local mutations already invalidate + refetch on
 * success. A live event from *another* user therefore just invalidates the same query keys -
 * simpler and less failure-prone than replicating three different cache-patch shapes, and at
 * demo scale (a handful of lists/cards) a refetch is effectively instant.
 */
export function useBoardLive(enabled: boolean): void {
  const { client } = useMudbase()
  const queryClient = useQueryClient()
  const projectId = client.getProjectId()

  useEffect(() => {
    if (!enabled) return
    const socket = getMudbaseSocket()
    const collectionIds = [LISTS_COLLECTION_ID, CARDS_COLLECTION_ID, ACTIVITY_COLLECTION_ID]

    const trySubscribe = (): void => {
      if (!socket.connected) return
      collectionIds.forEach((collectionId) => socket.emit("subscribe:collection", { projectId, collectionId }))
    }
    trySubscribe()
    const offStatus = socket.onStatus(trySubscribe)

    const onRowEvent = (ev: RowEvent): void => {
      if (!collectionIds.includes(ev.collectionId)) return
      void queryClient.invalidateQueries({ queryKey: ["collection", ev.collectionId] })
    }

    const offCreate = socket.on<RowEvent>("db:create", onRowEvent)
    const offUpdate = socket.on<RowEvent>("db:update", onRowEvent)
    const offDelete = socket.on<RowEvent>("db:delete", onRowEvent)

    return () => {
      collectionIds.forEach((collectionId) => socket.emit("unsubscribe:collection", { collectionId }))
      offStatus()
      offCreate()
      offUpdate()
      offDelete()
    }
  }, [enabled, projectId, queryClient])
}
