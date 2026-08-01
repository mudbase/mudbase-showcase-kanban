import { AuthGate } from "@/components/auth/AuthGate"
import { ActivityFeed } from "@/components/activity/ActivityFeed"

export default function ActivityPage(): React.JSX.Element {
  return (
    <div className="container max-w-2xl space-y-6 py-8">
      <h1 className="text-2xl font-semibold tracking-tight">Activity</h1>
      <AuthGate>
        <ActivityFeed />
      </AuthGate>
    </div>
  )
}
