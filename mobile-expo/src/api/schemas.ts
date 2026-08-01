import { z } from "zod";

/**
 * Runtime validation for every Mudbase response shape this app touches.
 *
 * The generated `mudbase-sdk`'s auth response models (e.g.
 * `LoginLocalUser200ResponseUser`) omit `customRole` even though the live API
 * includes it on every project-scoped session response (this app's entire
 * RBAC gating depends on it) — the same gap the sibling
 * `mudbase-showcase-social/mobile-expo` port's `schemas.ts` documents against
 * the same generated SDK. Likewise `DataResponse`/`DataListResponse` type
 * their `data` field as bare `object`. Rather than casting past the generated
 * types with `as`, every SDK response is widened to `unknown` (always
 * assignable, no cast needed) and parsed through one of these schemas
 * instead.
 */

// ─── Auth / User ────────────────────────────────────────────────────────────

/** Role slugs this project's multi-role auth is configured with — see plan/build-plan.md. */
export const appRoleSchema = z.enum(["owner", "member", "viewer"]);
export type AppRole = z.infer<typeof appRoleSchema>;

export const mudbaseUserSchema = z.object({
  id: z.string(),
  email: z.string(),
  firstName: z.string(),
  lastName: z.string(),
  customRole: z.string().nullable().optional(),
  emailVerified: z.boolean().optional(),
});
export type MudbaseUser = z.infer<typeof mudbaseUserSchema>;

export const authResultSchema = z.object({
  message: z.string().optional(),
  token: z.string().optional(),
  refreshToken: z.string().optional(),
  expiresIn: z.number().optional(),
  requireVerification: z.boolean().optional(),
  user: mudbaseUserSchema.optional(),
});
export type AuthResult = z.infer<typeof authResultSchema>;

// ─── Documents (Collections) ───────────────────────────────────────────────

export const documentBaseSchema = z.object({
  _id: z.string(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export const boardListSchema = documentBaseSchema.extend({
  boardId: z.string(),
  name: z.string(),
  position: z.number(),
});
export type BoardList = z.infer<typeof boardListSchema>;

export const boardCardSchema = documentBaseSchema.extend({
  boardId: z.string(),
  listId: z.string(),
  title: z.string(),
  description: z.string().nullable().optional(),
  position: z.number(),
  // `null` is a real, valid state here (an explicitly-cleared assignee — see useUpdateCard),
  // distinct from `undefined` (the field was never set on creation).
  assigneeId: z.string().nullable().optional(),
  assigneeName: z.string().nullable().optional(),
  createdById: z.string(),
  createdByName: z.string(),
});
export type BoardCard = z.infer<typeof boardCardSchema>;

export const activityActionSchema = z.enum([
  "created_card",
  "moved",
  "deleted_card",
  "created_list",
  "renamed_list",
  "deleted_list",
]);
export type ActivityAction = z.infer<typeof activityActionSchema>;

export const activityEntrySchema = documentBaseSchema.extend({
  boardId: z.string(),
  actorId: z.string(),
  actorName: z.string(),
  action: activityActionSchema,
  cardTitle: z.string().optional(),
  fromList: z.string().optional(),
  toList: z.string().optional(),
});
export type ActivityEntry = z.infer<typeof activityEntrySchema>;
