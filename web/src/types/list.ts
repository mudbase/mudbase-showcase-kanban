import type { Document } from "@/lib/mudbase"

export interface BoardList extends Document {
  boardId: string
  name: string
  position: number
}
