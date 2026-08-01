"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useAuth } from "@/hooks/useAuth"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Separator } from "@/components/ui/separator"

const loginSchema = z.object({
  email: z.string().min(1, "Email is required").email("Enter a valid email address"),
  password: z.string().min(1, "Password is required"),
})

type LoginFormValues = z.infer<typeof loginSchema>

const DEMO_PASSWORD = "KanbanTest123!"
// The `.test` TLD emails originally spec'd for this demo (kanban-owner@example.test etc.) fail
// Mudbase's own login validation live - Joi's default email() check excludes RFC 2606 reserved
// special-use TLDs. These valid-domain accounts are registered under the same owner/member/
// viewer role slugs on the same project - see plan/build-plan.md "Real platform finding".
const DEMO_ACCOUNTS = [
  { role: "Owner", email: "kanban.owner.demo@gmail.com" },
  { role: "Member", email: "kanban.member.demo@gmail.com" },
  { role: "Viewer", email: "kanban.viewer.demo@gmail.com" },
] as const

export function LoginForm(): React.JSX.Element {
  const { login, error, loading, clearError } = useAuth()
  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors },
  } = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "" },
  })

  const onSubmit = async (values: LoginFormValues): Promise<void> => {
    clearError()
    await login(values.email, values.password)
  }

  const quickFill = (email: string): void => {
    clearError()
    setValue("email", email)
    setValue("password", DEMO_PASSWORD)
    void login(email, DEMO_PASSWORD)
  }

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-3 gap-2">
        {DEMO_ACCOUNTS.map((account) => (
          <Button
            key={account.role}
            type="button"
            variant="outline"
            size="sm"
            disabled={loading}
            onClick={() => quickFill(account.email)}
          >
            {account.role}
          </Button>
        ))}
      </div>

      <div className="relative">
        <Separator />
        <span className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 bg-background px-2 text-xs text-muted-foreground">
          or sign in manually
        </span>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            type="email"
            autoComplete="email"
            placeholder="kanban.owner.demo@gmail.com"
            {...register("email")}
          />
          {errors.email && <p className="text-sm text-destructive">{errors.email.message}</p>}
        </div>

        <div className="space-y-2">
          <Label htmlFor="password">Password</Label>
          <Input id="password" type="password" autoComplete="current-password" {...register("password")} />
          {errors.password && <p className="text-sm text-destructive">{errors.password.message}</p>}
        </div>

        {error && <p className="text-sm text-destructive">{error}</p>}

        <Button type="submit" className="w-full" disabled={loading}>
          {loading ? "Signing in…" : "Sign in"}
        </Button>
      </form>
    </div>
  )
}
