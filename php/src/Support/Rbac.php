<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Client-side mirror of the RBAC matrix Mudbase's own collection permissions already enforce
 * server-side (see plan/build-plan.md). Used purely to hide/disable controls a role cannot use
 * and to show a clear reason why — it is NOT the security boundary. A raw request bypassing this
 * app's views is still rejected by the platform; see the smoke test in build-plan.md. A
 * line-for-line PHP port of the reference app's `src/lib/rbac.ts`.
 */
final class Rbac
{
    public static function canManageLists(?string $role): bool
    {
        return $role === 'owner';
    }

    public static function canManageCards(?string $role): bool
    {
        return $role === 'owner' || $role === 'member';
    }

    public static function isReadOnly(?string $role): bool
    {
        return $role === 'viewer' || $role === null;
    }

    public static function roleLabel(?string $role): string
    {
        return match ($role) {
            'owner' => 'Owner',
            'member' => 'Member',
            'viewer' => 'Viewer',
            default => 'Unknown',
        };
    }
}
