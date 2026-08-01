"use client"

import { useState } from "react"
import { useMoveCardToList } from "@/hooks/useCards"
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select"
import type { BoardCard } from "@/types/card"
import type { BoardList } from "@/types/list"

interface MoveCardControlProps {
  card: BoardCard
  currentList: BoardList
  otherLists: BoardList[]
  nextPositionByListId: Record<string, number>
}

/** "Move to…" dropdown: moves a card to the end of a different column. Reordering within the
 * same column is handled separately by the up/down buttons in CardItem. */
export function MoveCardControl({
  card,
  currentList,
  otherLists,
  nextPositionByListId,
}: MoveCardControlProps): React.JSX.Element | null {
  const moveCard = useMoveCardToList()
  const [pendingListId, setPendingListId] = useState<string | null>(null)

  if (otherLists.length === 0) return null

  const handleMove = (targetListId: string): void => {
    const target = otherLists.find((l) => l._id === targetListId)
    if (!target) return
    setPendingListId(targetListId)
    moveCard.mutate(
      {
        card,
        fromListName: currentList.name,
        toListId: target._id,
        toListName: target.name,
        newPosition: nextPositionByListId[target._id] ?? 0,
      },
      { onSettled: () => setPendingListId(null) },
    )
  }

  return (
    <Select value={pendingListId ?? ""} onValueChange={handleMove} disabled={moveCard.isPending}>
      <SelectTrigger className="h-8 text-xs">
        <SelectValue placeholder="Move to…" />
      </SelectTrigger>
      <SelectContent>
        {otherLists.map((list) => (
          <SelectItem key={list._id} value={list._id}>
            {list.name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}
