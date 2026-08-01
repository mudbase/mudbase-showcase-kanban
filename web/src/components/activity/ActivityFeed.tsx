"use client"

import { useActivityFeed } from "@/hooks/useActivity"
import { useBoardLive } from "@/hooks/useBoardLive"
import { ActivityItem } from "@/components/activity/ActivityItem"
import { Card, CardContent } from "@/components/ui/card"

export function ActivityFeed(): React.JSX.Element {
  const { data, isLoading, isError } = useActivityFeed()
  useBoardLive(!isLoading)

  const entries = data?.data ?? []

  if (isLoading) {
    return <div className="flex h-40 items-center justify-center text-sm text-muted-foreground">Loading activity…</div>
  }

  if (isError) {
    return (
      <div className="flex h-40 items-center justify-center text-sm text-destructive">
        Failed to load activity. Try refreshing the page.
      </div>
    )
  }

  if (entries.length === 0) {
    return (
      <Card>
        <CardContent className="p-6 text-center text-sm text-muted-foreground">
          No activity yet — actions on the board will show up here.
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardContent className="p-6">
        <ul className="divide-y divide-border">
          {entries.map((entry) => (
            <ActivityItem key={entry._id} entry={entry} />
          ))}
        </ul>
      </CardContent>
    </Card>
  )
}
