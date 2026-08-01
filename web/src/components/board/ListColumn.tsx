"use client"

import { useState } from "react"
import { z } from "zod"
import { ChevronLeft, ChevronRight, Pencil, Plus, Trash2 } from "lucide-react"
import { useRenameList, useDeleteList, useReorderList } from "@/hooks/useLists"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { CardItem } from "@/components/board/CardItem"
import { CardDialog } from "@/components/board/CardDialog"
import type { BoardList } from "@/types/list"
import type { BoardCard } from "@/types/card"

const listNameSchema = z.string().min(1, "Name is required").max(60, "Keep the name under 60 characters")

interface ListColumnProps {
  list: BoardList
  cards: BoardCard[]
  otherLists: BoardList[]
  nextPositionByListId: Record<string, number>
  prevList?: BoardList
  nextList?: BoardList
  allCardsInList: BoardCard[]
  canManageLists: boolean
  canManageCards: boolean
}

export function ListColumn({
  list,
  cards,
  otherLists,
  nextPositionByListId,
  prevList,
  nextList,
  allCardsInList,
  canManageLists,
  canManageCards,
}: ListColumnProps): React.JSX.Element {
  const [renaming, setRenaming] = useState(false)
  const [draftName, setDraftName] = useState(list.name)
  const [nameError, setNameError] = useState<string | null>(null)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [creatingCard, setCreatingCard] = useState(false)

  const renameList = useRenameList()
  const deleteList = useDeleteList()
  const reorderList = useReorderList()

  const startRename = (): void => {
    setDraftName(list.name)
    setNameError(null)
    setRenaming(true)
  }

  const saveRename = (): void => {
    const parsed = listNameSchema.safeParse(draftName.trim())
    if (!parsed.success) {
      setNameError(parsed.error.issues[0]?.message ?? "Invalid name")
      return
    }
    if (parsed.data === list.name) {
      setRenaming(false)
      return
    }
    renameList.mutate(
      { list, newName: parsed.data },
      {
        onSuccess: () => setRenaming(false),
      },
    )
  }

  const handleDelete = (): void => {
    deleteList.mutate({ list, cardsInList: allCardsInList })
    setConfirmDelete(false)
  }

  return (
    <div className="flex w-72 shrink-0 flex-col rounded-lg border border-border bg-muted/40">
      <div className="flex items-center justify-between gap-2 border-b border-border p-3">
        {renaming ? (
          <div className="flex flex-1 flex-col gap-1">
            <div className="flex gap-1">
              <Input
                value={draftName}
                onChange={(e) => setDraftName(e.target.value)}
                autoFocus
                className="h-8 text-sm"
                onKeyDown={(e) => {
                  if (e.key === "Enter") saveRename()
                  if (e.key === "Escape") setRenaming(false)
                }}
              />
              <Button size="sm" className="h-8 px-2" onClick={saveRename} disabled={renameList.isPending}>
                Save
              </Button>
              <Button size="sm" variant="outline" className="h-8 px-2" onClick={() => setRenaming(false)}>
                Cancel
              </Button>
            </div>
            {nameError && <p className="text-xs text-destructive">{nameError}</p>}
          </div>
        ) : (
          <>
            <h2 className="truncate text-sm font-semibold">
              {list.name} <span className="font-normal text-muted-foreground">({cards.length})</span>
            </h2>
            {canManageLists && (
              <div className="flex shrink-0 gap-0.5">
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-7 w-7"
                  aria-label="Move list left"
                  disabled={!prevList || reorderList.isPending}
                  onClick={() => prevList && reorderList.mutate({ list, neighbor: prevList })}
                >
                  <ChevronLeft className="h-3.5 w-3.5" />
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-7 w-7"
                  aria-label="Move list right"
                  disabled={!nextList || reorderList.isPending}
                  onClick={() => nextList && reorderList.mutate({ list, neighbor: nextList })}
                >
                  <ChevronRight className="h-3.5 w-3.5" />
                </Button>
                <Button variant="ghost" size="icon" className="h-7 w-7" aria-label="Rename list" onClick={startRename}>
                  <Pencil className="h-3.5 w-3.5" />
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-7 w-7 text-destructive hover:text-destructive"
                  aria-label="Delete list"
                  onClick={() => setConfirmDelete(true)}
                >
                  <Trash2 className="h-3.5 w-3.5" />
                </Button>
              </div>
            )}
          </>
        )}
      </div>

      {confirmDelete && (
        <div className="space-y-2 border-b border-destructive/40 bg-destructive/5 p-3 text-xs">
          <p>
            Delete &quot;{list.name}&quot;
            {allCardsInList.length > 0 ? ` and its ${allCardsInList.length} card(s)` : ""}?
          </p>
          <div className="flex gap-2">
            <Button size="sm" variant="destructive" onClick={handleDelete} disabled={deleteList.isPending}>
              {deleteList.isPending ? "Deleting…" : "Delete"}
            </Button>
            <Button size="sm" variant="outline" onClick={() => setConfirmDelete(false)}>
              Cancel
            </Button>
          </div>
        </div>
      )}

      <div className="flex flex-1 flex-col gap-2 overflow-y-auto p-3">
        {cards.map((card, index) => (
          <CardItem
            key={card._id}
            card={card}
            list={list}
            otherLists={otherLists}
            nextPositionByListId={nextPositionByListId}
            prevCard={cards[index - 1]}
            nextCard={cards[index + 1]}
            canManage={canManageCards}
          />
        ))}
        {cards.length === 0 && <p className="py-4 text-center text-xs text-muted-foreground">No cards yet</p>}
      </div>

      {canManageCards && (
        <div className="border-t border-border p-3">
          <Button variant="ghost" size="sm" className="w-full justify-start" onClick={() => setCreatingCard(true)}>
            <Plus className="mr-2 h-4 w-4" />
            Add card
          </Button>
          <CardDialog
            open={creatingCard}
            onOpenChange={setCreatingCard}
            listId={list._id}
            listName={list.name}
            nextPosition={nextPositionByListId[list._id] ?? 0}
          />
        </div>
      )}
    </div>
  )
}
