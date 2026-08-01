import { PlusCircle, ArrowRightLeft, Trash2, ListPlus, ListRestart, ListX } from "lucide-react"
import { describeActivity } from "@/lib/activity-text"
import { formatRelativeTime } from "@/lib/utils"
import { Avatar } from "@/components/ui/avatar"
import type { ActivityEntry } from "@/types/activity"

const iconByAction: Record<ActivityEntry["action"], React.ComponentType<{ className?: string }>> = {
  created_card: PlusCircle,
  moved: ArrowRightLeft,
  deleted_card: Trash2,
  created_list: ListPlus,
  renamed_list: ListRestart,
  deleted_list: ListX,
}

export function ActivityItem({ entry }: { entry: ActivityEntry }): React.JSX.Element {
  const Icon = iconByAction[entry.action]

  return (
    <li className="flex items-start gap-3 py-3">
      <Avatar name={entry.actorName} size="sm" />
      <div className="flex-1 space-y-0.5">
        <p className="text-sm">{describeActivity(entry)}</p>
        <p className="text-xs text-muted-foreground">{formatRelativeTime(entry.createdAt)}</p>
      </div>
      <Icon className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />
    </li>
  )
}
