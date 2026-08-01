"use client"

import { useCallback } from "react"
import { useMutation, useQueryClient } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import { useDocuments } from "@/hooks/useCollection"
import { LISTS_COLLECTION_ID, CARDS_COLLECTION_ID, ACTIVITY_COLLECTION_ID, BOARD_ID } from "@/lib/config"
import type { BoardList } from "@/types/list"
import type { BoardCard } from "@/types/card"
import type { ActivityEntry } from "@/types/activity"

/** All lists for the single shared board, ascending by column order. */
export function useBoardLists() {
  return useDocuments<BoardList>(LISTS_COLLECTION_ID, { filter: { boardId: BOARD_ID }, sort: "position" })
}

function actorFields(user: { id: string; firstName: string; lastName: string } | null | undefined): {
  actorId: string
  actorName: string
} {
  if (!user) throw new Error("Must be signed in")
  return { actorId: user.id, actorName: `${user.firstName} ${user.lastName}`.trim() }
}

function invalidateBoard(queryClient: ReturnType<typeof useQueryClient>): void {
  queryClient.invalidateQueries({ queryKey: ["collection", LISTS_COLLECTION_ID] })
  queryClient.invalidateQueries({ queryKey: ["collection", ACTIVITY_COLLECTION_ID] })
}

/** Owner-only: creates a new column at the end of the board. */
export function useCreateList() {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async ({ name, position }: { name: string; position: number }): Promise<BoardList> => {
      const { actorId, actorName } = actorFields(session?.user)
      const created = await client.createDocument<BoardList>(LISTS_COLLECTION_ID, {
        boardId: BOARD_ID,
        name,
        position,
      })
      await client.createDocument<ActivityEntry>(ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "created_list",
        toList: name,
      })
      return created
    },
    [client, session],
  )

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => invalidateBoard(queryClient),
  })
}

/** Owner-only: renames a column. */
export function useRenameList() {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async ({ list, newName }: { list: BoardList; newName: string }): Promise<BoardList> => {
      const { actorId, actorName } = actorFields(session?.user)
      const updated = await client.updateDocument<BoardList>(LISTS_COLLECTION_ID, list._id, { name: newName })
      await client.createDocument<ActivityEntry>(ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "renamed_list",
        fromList: list.name,
        toList: newName,
      })
      return updated
    },
    [client, session],
  )

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => invalidateBoard(queryClient),
  })
}

/** Owner-only: swaps this list's position with an adjacent one (left/right reorder). */
export function useReorderList() {
  const { client } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async ({ list, neighbor }: { list: BoardList; neighbor: BoardList }): Promise<void> => {
      await Promise.all([
        client.updateDocument<BoardList>(LISTS_COLLECTION_ID, list._id, { position: neighbor.position }),
        client.updateDocument<BoardList>(LISTS_COLLECTION_ID, neighbor._id, { position: list.position }),
      ])
    },
    [client],
  )

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["collection", LISTS_COLLECTION_ID] }),
  })
}

/** Owner-only: deletes a column and cascades to every card inside it - a list's cards have
 * nowhere else to live once the column is gone, there's no "uncategorized" list to fall back to. */
export function useDeleteList() {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async ({ list, cardsInList }: { list: BoardList; cardsInList: BoardCard[] }): Promise<void> => {
      const { actorId, actorName } = actorFields(session?.user)
      await Promise.all(cardsInList.map((card) => client.deleteDocument(CARDS_COLLECTION_ID, card._id)))
      await client.deleteDocument(LISTS_COLLECTION_ID, list._id)
      await client.createDocument<ActivityEntry>(ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "deleted_list",
        fromList: list.name,
      })
    },
    [client, session],
  )

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => {
      invalidateBoard(queryClient)
      queryClient.invalidateQueries({ queryKey: ["collection", CARDS_COLLECTION_ID] })
    },
  })
}
