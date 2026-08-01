import type { Document } from "@/lib/mudbase"

export type ActivityAction =
  | "created_card"
  | "moved"
  | "deleted_card"
  | "created_list"
  | "renamed_list"
  | "deleted_list"

export interface ActivityEntry extends Document {
  boardId: string
  actorId: string
  actorName: string
  action: ActivityAction
  cardTitle?: string
  fromList?: string
  toList?: string
}
