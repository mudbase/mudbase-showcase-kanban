"use client"

import { useState } from "react"
import { Plus } from "lucide-react"
import { z } from "zod"
import { useCreateList } from "@/hooks/useLists"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

const listNameSchema = z.string().min(1, "Name is required").max(60, "Keep the name under 60 characters")

interface AddListFormProps {
  nextPosition: number
}

/** Owner-only column at the end of the board row for adding a new list. */
export function AddListForm({ nextPosition }: AddListFormProps): React.JSX.Element {
  const [open, setOpen] = useState(false)
  const [name, setName] = useState("")
  const [error, setError] = useState<string | null>(null)
  const createList = useCreateList()

  const handleSubmit = (e: React.FormEvent): void => {
    e.preventDefault()
    const parsed = listNameSchema.safeParse(name.trim())
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? "Invalid name")
      return
    }
    createList.mutate(
      { name: parsed.data, position: nextPosition },
      {
        onSuccess: () => {
          setName("")
          setError(null)
          setOpen(false)
        },
      },
    )
  }

  if (!open) {
    return (
      <div className="w-72 shrink-0">
        <Button variant="outline" className="w-full justify-start" onClick={() => setOpen(true)}>
          <Plus className="mr-2 h-4 w-4" />
          Add list
        </Button>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="flex w-72 shrink-0 flex-col gap-2 rounded-lg border border-border p-3">
      <Input
        autoFocus
        placeholder="List name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        onKeyDown={(e) => e.key === "Escape" && setOpen(false)}
      />
      {error && <p className="text-xs text-destructive">{error}</p>}
      <div className="flex gap-2">
        <Button type="submit" size="sm" disabled={createList.isPending}>
          {createList.isPending ? "Adding…" : "Add list"}
        </Button>
        <Button type="button" size="sm" variant="outline" onClick={() => setOpen(false)}>
          Cancel
        </Button>
      </div>
    </form>
  )
}
