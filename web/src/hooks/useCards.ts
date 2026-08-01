"use client"

import { useCallback } from "react"
import { useMutation, useQueryClient } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import { useDocuments } from "@/hooks/useCollection"
import { CARDS_COLLECTION_ID, ACTIVITY_COLLECTION_ID, BOARD_ID } from "@/lib/config"
import type { BoardCard } from "@/types/card"
import type { ActivityEntry } from "@/types/activity"

/** All cards for the single shared board, ascending by in-column order - fetched once and
 * grouped client-side by listId (see BoardView), rather than one query per column. */
export function useBoardCards() {
  return useDocuments<BoardCard>(CARDS_COLLECTION_ID, { filter: { boardId: BOARD_ID }, sort: "position" })
}

function actorFields(user: { id: string; firstName: string; lastName: string } | null | undefined): {
  actorId: string
  actorName: string
} {
  if (!user) throw new Error("Must be signed in")
  return { actorId: user.id, actorName: `${user.firstName} ${user.lastName}`.trim() }
}

function invalidateBoard(queryClient: ReturnType<typeof useQueryClient>): void {
  queryClient.invalidateQueries({ queryKey: ["collection", CARDS_COLLECTION_ID] })
  queryClient.invalidateQueries({ queryKey: ["collection", ACTIVITY_COLLECTION_ID] })
}

export interface CreateCardInput {
  listId: string
  listName: string
  position: number
  title: string
  description?: string
  assigneeId?: string
  assigneeName?: string
}

/** Owner/member: creates a new card at the end of a column. */
export function useCreateCard() {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async (input: CreateCardInput): Promise<BoardCard> => {
      const { actorId, actorName } = actorFields(session?.user)
      const created = await client.createDocument<BoardCard>(CARDS_COLLECTION_ID, {
        boardId: BOARD_ID,
        listId: input.listId,
        title: input.title,
        position: input.position,
        ...(input.description ? { description: input.description } : {}),
        ...(input.assigneeId ? { assigneeId: input.assigneeId, assigneeName: input.assigneeName } : {}),
        createdById: actorId,
        createdByName: actorName,
      })
      await client.createDocument<ActivityEntry>(ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "created_card",
        cardTitle: input.title,
        toList: input.listName,
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

export interface EditCardInput {
  card: BoardCard
  title: string
  description?: string
  assigneeId?: string
  assigneeName?: string
}

/** Owner/member: edits a card's title/description/assignee in place. Not itself logged to the
 * activity feed - only creation, movement, and deletion are (see plan/build-plan.md). */
export function useUpdateCard() {
  const { client } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async (input: EditCardInput): Promise<BoardCard> => {
      // `assigneeId` is validated server-side as an ObjectId reference (verified live) - an
      // empty string fails that check the same way an invalid slug would
      // ("Invalid ObjectId format for assigneeId"). `null` is the value that actually clears
      // it; never send "" here.
      return client.updateDocument<BoardCard>(CARDS_COLLECTION_ID, input.card._id, {
        title: input.title,
        description: input.description ?? "",
        assigneeId: input.assigneeId ?? null,
        assigneeName: input.assigneeName ?? null,
      })
    },
    [client],
  )

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["collection", CARDS_COLLECTION_ID] }),
  })
}

/** Owner/member: deletes a card. */
export function useDeleteCard() {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async ({ card, listName }: { card: BoardCard; listName: string }): Promise<void> => {
      const { actorId, actorName } = actorFields(session?.user)
      await client.deleteDocument(CARDS_COLLECTION_ID, card._id)
      await client.createDocument<ActivityEntry>(ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "deleted_card",
        cardTitle: card.title,
        fromList: listName,
      })
    },
    [client, session],
  )

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => invalidateBoard(queryClient),
  })
}

/** Owner/member: moves a card to a different column, appended to the end of it. Every move
 * writes both `listId` and `position` and appends a `moved` activity entry, per the task spec. */
export function useMoveCardToList() {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async (params: {
      card: BoardCard
      fromListName: string
      toListId: string
      toListName: string
      newPosition: number
    }): Promise<BoardCard> => {
      const { actorId, actorName } = actorFields(session?.user)
      const updated = await client.updateDocument<BoardCard>(CARDS_COLLECTION_ID, params.card._id, {
        listId: params.toListId,
        position: params.newPosition,
      })
      await client.createDocument<ActivityEntry>(ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "moved",
        cardTitle: params.card.title,
        fromList: params.fromListName,
        toList: params.toListName,
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

/** Owner/member: reorders a card up/down within its own column by swapping `position` with the
 * adjacent card. Still logs a `moved` activity entry (fromList === toList) per the task's
 * "every move...appends an activity entry" requirement. */
export function useReorderCardInList() {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async (params: { card: BoardCard; neighbor: BoardCard; listName: string }): Promise<void> => {
      const { actorId, actorName } = actorFields(session?.user)
      await Promise.all([
        client.updateDocument<BoardCard>(CARDS_COLLECTION_ID, params.card._id, { position: params.neighbor.position }),
        client.updateDocument<BoardCard>(CARDS_COLLECTION_ID, params.neighbor._id, { position: params.card.position }),
      ])
      await client.createDocument<ActivityEntry>(ACTIVITY_COLLECTION_ID, {
        boardId: BOARD_ID,
        actorId,
        actorName,
        action: "moved",
        cardTitle: params.card.title,
        fromList: params.listName,
        toList: params.listName,
      })
    },
    [client, session],
  )

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => invalidateBoard(queryClient),
  })
}
