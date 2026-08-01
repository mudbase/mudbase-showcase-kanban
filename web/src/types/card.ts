import type { Document } from "@/lib/mudbase"

export interface BoardCard extends Document {
  boardId: string
  listId: string
  title: string
  description?: string
  position: number
  // `null` is a real, valid state here (an explicitly-cleared assignee - see useUpdateCard),
  // distinct from `undefined` (the field was never set on creation).
  assigneeId?: string | null
  assigneeName?: string | null
  createdById: string
  createdByName: string
}
