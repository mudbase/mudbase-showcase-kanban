"use client"

import { useEffect } from "react"
import { useRouter } from "next/navigation"
import { useAuth } from "@/hooks/useAuth"

/** Wraps any page that requires a signed-in session (every page except /login - this app has
 * no anonymous/guest read, see plan/build-plan.md). Redirects to /login once loading settles
 * with no session, rather than flashing protected content first. */
export function AuthGate({ children }: { children: React.ReactNode }): React.JSX.Element | null {
  const { isAuthenticated, loading } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (!loading && !isAuthenticated) {
      router.replace("/login")
    }
  }, [loading, isAuthenticated, router])

  if (loading) {
    return (
      <div className="flex h-[60vh] items-center justify-center text-sm text-muted-foreground">
        Loading board…
      </div>
    )
  }

  if (!isAuthenticated) {
    return null
  }

  return <>{children}</>
}
