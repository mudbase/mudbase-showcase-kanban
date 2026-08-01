import { Text, View } from "react-native";
import {
  ArrowRightLeft,
  ListPlus,
  ListRestart,
  ListX,
  PlusCircle,
  Trash2,
  type LucideIcon,
} from "lucide-react-native";
import { describeActivity } from "@/lib/activity-text";
import { formatRelativeTime } from "@/lib/format";
import { Avatar } from "@/components/ui/Avatar";
import type { ActivityAction, ActivityEntry } from "@/api/schemas";

const iconByAction: Record<ActivityAction, LucideIcon> = {
  created_card: PlusCircle,
  moved: ArrowRightLeft,
  deleted_card: Trash2,
  created_list: ListPlus,
  renamed_list: ListRestart,
  deleted_list: ListX,
};

/** One row of the activity feed. Mirrors web/src/components/activity/ActivityItem.tsx. */
export function ActivityItem({ entry }: { entry: ActivityEntry }): React.JSX.Element {
  const Icon = iconByAction[entry.action];

  return (
    <View className="flex-row items-start gap-3 py-3">
      <Avatar name={entry.actorName} size="sm" />
      <View className="flex-1 gap-0.5">
        <Text className="text-sm text-foreground">{describeActivity(entry)}</Text>
        <Text className="text-xs text-muted-foreground">{formatRelativeTime(entry.createdAt)}</Text>
      </View>
      <Icon size={16} color="#606876" style={{ marginTop: 2 }} />
    </View>
  );
}
