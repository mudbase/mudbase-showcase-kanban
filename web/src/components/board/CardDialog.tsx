"use client"

import { useEffect, useState } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useAuth } from "@/hooks/useAuth"
import { useCreateCard, useUpdateCard } from "@/hooks/useCards"
import { pseudoObjectId } from "@/lib/utils"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import type { BoardCard } from "@/types/card"

const cardSchema = z.object({
  title: z.string().min(1, "Title is required").max(120, "Keep the title under 120 characters"),
  description: z.string().max(2000, "Keep the description under 2000 characters").optional(),
  assigneeName: z.string().max(80, "Keep the assignee name under 80 characters").optional(),
})

type CardFormValues = z.infer<typeof cardSchema>

interface CardDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  listId: string
  listName: string
  nextPosition: number
  editingCard?: BoardCard
}

/** Create-or-edit modal for a card. Which mode it's in is determined by whether `editingCard`
 * is present - both modes share the same form and validation. */
export function CardDialog({
  open,
  onOpenChange,
  listId,
  listName,
  nextPosition,
  editingCard,
}: CardDialogProps): React.JSX.Element {
  const { user } = useAuth()
  const createCard = useCreateCard()
  const updateCard = useUpdateCard()
  const isEditing = !!editingCard
  const [submitError, setSubmitError] = useState<string | null>(null)

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<CardFormValues>({
    resolver: zodResolver(cardSchema),
    defaultValues: { title: "", description: "", assigneeName: "" },
  })

  useEffect(() => {
    if (open) {
      reset({
        title: editingCard?.title ?? "",
        description: editingCard?.description ?? "",
        assigneeName: editingCard?.assigneeName ?? "",
      })
      setSubmitError(null)
    }
  }, [open, editingCard, reset])

  const onSubmit = async (values: CardFormValues): Promise<void> => {
    setSubmitError(null)
    const assigneeName = values.assigneeName?.trim() || undefined
    try {
      if (isEditing && editingCard) {
        await updateCard.mutateAsync({
          card: editingCard,
          title: values.title.trim(),
          description: values.description?.trim(),
          assigneeId: assigneeName ? pseudoObjectId(assigneeName) : undefined,
          assigneeName,
        })
      } else {
        if (!user) throw new Error("Must be signed in")
        await createCard.mutateAsync({
          listId,
          listName,
          position: nextPosition,
          title: values.title.trim(),
          description: values.description?.trim(),
          assigneeId: assigneeName ? pseudoObjectId(assigneeName) : undefined,
          assigneeName,
        })
      }
      onOpenChange(false)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Something went wrong")
    }
  }

  const pending = createCard.isPending || updateCard.isPending

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{isEditing ? "Edit card" : `New card in ${listName}`}</DialogTitle>
          <DialogDescription>
            {isEditing ? "Update the card's details." : "Add a task to this column."}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
          <div className="space-y-2">
            <Label htmlFor="card-title">Title</Label>
            <Input id="card-title" placeholder="e.g. Write onboarding docs" {...register("title")} />
            {errors.title && <p className="text-sm text-destructive">{errors.title.message}</p>}
          </div>

          <div className="space-y-2">
            <Label htmlFor="card-description">Description (optional)</Label>
            <Textarea id="card-description" rows={4} {...register("description")} />
            {errors.description && <p className="text-sm text-destructive">{errors.description.message}</p>}
          </div>

          <div className="space-y-2">
            <Label htmlFor="card-assignee">Assignee (optional)</Label>
            <Input id="card-assignee" placeholder="e.g. Ben Chen" {...register("assigneeName")} />
            {errors.assigneeName && <p className="text-sm text-destructive">{errors.assigneeName.message}</p>}
          </div>

          {submitError && <p className="text-sm text-destructive">{submitError}</p>}

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={pending}>
              {pending ? "Saving…" : isEditing ? "Save changes" : "Create card"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
