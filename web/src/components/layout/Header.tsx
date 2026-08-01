"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { LogOut, LayoutGrid, ListTree } from "lucide-react"
import { useAuth } from "@/hooks/useAuth"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { roleLabel } from "@/lib/rbac"
import { cn } from "@/lib/utils"

const roleBadgeVariant = {
  owner: "default",
  member: "secondary",
  viewer: "outline",
} as const

export function Header(): React.JSX.Element {
  const { user, role, isAuthenticated, logout } = useAuth()
  const pathname = usePathname()

  return (
    <header className="sticky top-0 z-40 border-b border-border bg-background/95 backdrop-blur">
      <div className="container flex h-16 items-center justify-between">
        <div className="flex items-center gap-6">
          <Link href="/" className="font-display text-xl font-semibold tracking-tight">
            Mudbase Kanban
          </Link>

          {isAuthenticated && (
            <nav className="flex items-center gap-1">
              <Button
                asChild
                variant="ghost"
                size="sm"
                className={cn(pathname === "/" && "bg-accent text-accent-foreground")}
              >
                <Link href="/">
                  <LayoutGrid className="mr-2 h-4 w-4" />
                  Board
                </Link>
              </Button>
              <Button
                asChild
                variant="ghost"
                size="sm"
                className={cn(pathname === "/activity" && "bg-accent text-accent-foreground")}
              >
                <Link href="/activity">
                  <ListTree className="mr-2 h-4 w-4" />
                  Activity
                </Link>
              </Button>
            </nav>
          )}
        </div>

        <div className="flex items-center gap-3">
          {isAuthenticated && user && role && (
            <div className="flex items-center gap-2">
              <span className="hidden text-sm text-muted-foreground sm:inline">
                {user.firstName} {user.lastName}
              </span>
              <Badge variant={roleBadgeVariant[role]}>{roleLabel(role)}</Badge>
            </div>
          )}

          {isAuthenticated && (
            <Button variant="outline" size="sm" onClick={() => void logout()}>
              <LogOut className="mr-2 h-4 w-4" />
              Sign out
            </Button>
          )}
        </div>
      </div>
    </header>
  )
}
