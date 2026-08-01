"use client"

import { useState, useCallback } from "react"
import { useRouter } from "next/navigation"
import { useMudbase } from "@/lib/mudbase-provider"
import { MudbaseError, type UserObject, type AppRole } from "@/lib/mudbase"
import { getMudbaseSocket } from "@/lib/mudbase-socket"
import { isAppRole } from "@/lib/rbac"

interface UseAuthReturn {
  user: UserObject | null
  role: AppRole | null
  isAuthenticated: boolean
  loading: boolean
  error: string | null
  login: (email: string, password: string) => Promise<boolean>
  logout: () => Promise<void>
  clearError: () => void
}

export function useAuth(): UseAuthReturn {
  const { client, session, loading: sessionLoading, refreshSession } = useMudbase()
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const login = useCallback(
    async (email: string, password: string): Promise<boolean> => {
      setLoading(true)
      setError(null)
      try {
        await client.login({ email, password })
        await refreshSession()
        router.push("/")
        return true
      } catch (err) {
        setError(err instanceof MudbaseError ? err.message : "Login failed")
        return false
      } finally {
        setLoading(false)
      }
    },
    [client, router, refreshSession],
  )

  const logout = useCallback(async () => {
    setLoading(true)
    try {
      await client.logout()
      // Without this, a socket connected while logged in stays connected authenticated as the
      // now-invalid session indefinitely - refreshSession() only ever calls connect() again on a
      // truthy token, never disconnects on a null one.
      getMudbaseSocket().disconnect()
      await refreshSession()
      router.push("/login")
    } finally {
      setLoading(false)
    }
  }, [client, router, refreshSession])

  const user = session?.user ?? null
  const role = isAppRole(user?.customRole) ? user.customRole : null

  return {
    user,
    role,
    isAuthenticated: !!user,
    loading: loading || sessionLoading,
    error,
    login,
    logout,
    clearError: () => setError(null),
  }
}
