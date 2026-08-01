"use client"

import { useState } from "react"
import { ChevronUp, ChevronDown, Pencil, Trash2 } from "lucide-react"
import { useDeleteCard, useReorderCardInList } from "@/hooks/useCards"
import { Card, CardContent } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Avatar } from "@/components/ui/avatar"
import { CardDialog } from "@/components/board/CardDialog"
import { MoveCardControl } from "@/components/board/MoveCardControl"
import type { BoardCard } from "@/types/card"
import type { BoardList } from "@/types/list"

interface CardItemProps {
  card: BoardCard
  list: BoardList
  otherLists: BoardList[]
  nextPositionByListId: Record<string, number>
  prevCard?: BoardCard
  nextCard?: BoardCard
  canManage: boolean
}

export function CardItem({
  card,
  list,
  otherLists,
  nextPositionByListId,
  prevCard,
  nextCard,
  canManage,
}: CardItemProps): React.JSX.Element {
  const [editOpen, setEditOpen] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const deleteCard = useDeleteCard()
  const reorderCard = useReorderCardInList()

  const handleDelete = (): void => {
    deleteCard.mutate({ card, listName: list.name })
    setConfirmDelete(false)
  }

  return (
    <Card className="shadow-none">
      <CardContent className="space-y-2 p-3">
        <div className="flex items-start justify-between gap-2">
          <p className="text-sm font-medium leading-snug">{card.title}</p>
          {canManage && (
            <div className="flex shrink-0 gap-0.5">
              <Button
                variant="ghost"
                size="icon"
                className="h-6 w-6"
                aria-label="Edit card"
                onClick={() => setEditOpen(true)}
              >
                <Pencil className="h-3.5 w-3.5" />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                className="h-6 w-6 text-destructive hover:text-destructive"
                aria-label="Delete card"
                onClick={() => setConfirmDelete(true)}
              >
                <Trash2 className="h-3.5 w-3.5" />
              </Button>
            </div>
          )}
        </div>

        {card.description && <p className="line-clamp-3 text-xs text-muted-foreground">{card.description}</p>}

        {card.assigneeName && (
          <div className="flex items-center gap-1.5 pt-1">
            <Avatar name={card.assigneeName} size="sm" />
            <span className="text-xs text-muted-foreground">{card.assigneeName}</span>
          </div>
        )}

        {confirmDelete && (
          <div className="space-y-2 rounded-md border border-destructive/40 bg-destructive/5 p-2 text-xs">
            <p>Delete this card?</p>
            <div className="flex gap-2">
              <Button size="sm" variant="destructive" onClick={handleDelete} disabled={deleteCard.isPending}>
                {deleteCard.isPending ? "Deleting…" : "Delete"}
              </Button>
              <Button size="sm" variant="outline" onClick={() => setConfirmDelete(false)}>
                Cancel
              </Button>
            </div>
          </div>
        )}

        {canManage && (
          <div className="flex items-center gap-1 pt-1">
            <Button
              variant="outline"
              size="icon"
              className="h-7 w-7"
              aria-label="Move up"
              disabled={!prevCard || reorderCard.isPending}
              onClick={() => prevCard && reorderCard.mutate({ card, neighbor: prevCard, listName: list.name })}
            >
              <ChevronUp className="h-3.5 w-3.5" />
            </Button>
            <Button
              variant="outline"
              size="icon"
              className="h-7 w-7"
              aria-label="Move down"
              disabled={!nextCard || reorderCard.isPending}
              onClick={() => nextCard && reorderCard.mutate({ card, neighbor: nextCard, listName: list.name })}
            >
              <ChevronDown className="h-3.5 w-3.5" />
            </Button>
            <div className="flex-1">
              <MoveCardControl
                card={card}
                currentList={list}
                otherLists={otherLists}
                nextPositionByListId={nextPositionByListId}
              />
            </div>
          </div>
        )}
      </CardContent>

      {canManage && (
        <CardDialog
          open={editOpen}
          onOpenChange={setEditOpen}
          listId={list._id}
          listName={list.name}
          nextPosition={card.position}
          editingCard={card}
        />
      )}
    </Card>
  )
}
