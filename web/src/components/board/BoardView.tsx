"use client"

import { useMemo } from "react"
import { useAuth } from "@/hooks/useAuth"
import { useBoardLists } from "@/hooks/useLists"
import { useBoardCards } from "@/hooks/useCards"
import { useBoardLive } from "@/hooks/useBoardLive"
import { canManageLists, canManageCards, isReadOnly, roleLabel } from "@/lib/rbac"
import { ListColumn } from "@/components/board/ListColumn"
import { AddListForm } from "@/components/board/AddListForm"
import type { BoardCard } from "@/types/card"

export function BoardView(): React.JSX.Element {
  const { role } = useAuth()
  const listsQuery = useBoardLists()
  const cardsQuery = useBoardCards()

  const isLoading = listsQuery.isLoading || cardsQuery.isLoading
  useBoardLive(!isLoading)

  const lists = useMemo(
    () => [...(listsQuery.data?.data ?? [])].sort((a, b) => a.position - b.position),
    [listsQuery.data],
  )

  const cardsByListId = useMemo(() => {
    const cards = cardsQuery.data?.data ?? []
    const map = new Map<string, BoardCard[]>()
    for (const card of cards) {
      const bucket = map.get(card.listId) ?? []
      bucket.push(card)
      map.set(card.listId, bucket)
    }
    for (const bucket of map.values()) bucket.sort((a, b) => a.position - b.position)
    return map
  }, [cardsQuery.data])

  const nextListPosition = useMemo(
    () => (lists.length === 0 ? 0 : Math.max(...lists.map((l) => l.position)) + 1),
    [lists],
  )

  const nextPositionByListId = useMemo(() => {
    const map: Record<string, number> = {}
    for (const list of lists) {
      const inList = cardsByListId.get(list._id) ?? []
      map[list._id] = inList.length === 0 ? 0 : Math.max(...inList.map((c) => c.position)) + 1
    }
    return map
  }, [lists, cardsByListId])

  const manageLists = canManageLists(role)
  const manageCards = canManageCards(role)
  const readOnly = isReadOnly(role)

  if (isLoading) {
    return <div className="flex h-[50vh] items-center justify-center text-sm text-muted-foreground">Loading board…</div>
  }

  if (listsQuery.isError || cardsQuery.isError) {
    return (
      <div className="flex h-[50vh] items-center justify-center text-sm text-destructive">
        Failed to load the board. Try refreshing the page.
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold tracking-tight">Team Board</h1>
        {readOnly && (
          <p className="rounded-md border border-border bg-muted px-3 py-1.5 text-sm text-muted-foreground">
            Read-only — you&apos;re signed in as {roleLabel(role)}
          </p>
        )}
      </div>

      <div className="flex gap-4 overflow-x-auto pb-4">
        {lists.map((list, index) => {
          const cardsInList = cardsByListId.get(list._id) ?? []
          return (
            <ListColumn
              key={list._id}
              list={list}
              cards={cardsInList}
              allCardsInList={cardsInList}
              otherLists={lists.filter((l) => l._id !== list._id)}
              nextPositionByListId={nextPositionByListId}
              prevList={lists[index - 1]}
              nextList={lists[index + 1]}
              canManageLists={manageLists}
              canManageCards={manageCards}
            />
          )
        })}

        {manageLists && <AddListForm nextPosition={nextListPosition} />}

        {lists.length === 0 && !manageLists && (
          <p className="text-sm text-muted-foreground">The board has no lists yet.</p>
        )}
      </div>
    </div>
  )
}
