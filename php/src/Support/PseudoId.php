<?php

declare(strict_types=1);

namespace App\Support;

/**
 * There is no `users` collection in this app's data model (see plan/build-plan.md), so an
 * assignee is captured as a free-typed name rather than looked up from a directory. Verified live
 * against the real project (see the reference web app's build-plan.md "Live smoke test results"):
 * `cards.assigneeId` is schema-typed as an ObjectId reference, not a free-form string as
 * originally assumed — a plain slug like "mia-member" is rejected with "Invalid ObjectId format
 * for assigneeId". This derives a stable, valid-looking 24-hex-char id from the typed name (the
 * same name always maps to the same id) purely so `assigneeId` passes that format check and is
 * never left orphaned from `assigneeName` — it is not a real user lookup key. A PHP port of the
 * reference app's `pseudoObjectId()` (src/lib/utils.ts), using the same djb2 string hash.
 */
final class PseudoId
{
    private const UINT32_MODULUS = 4294967296; // 2^32
    private const INT32_MAX = 2147483648; // 2^31

    public static function pseudoObjectId(string $seed): string
    {
        $trimmed = strtolower(trim($seed));
        $hex = '';
        $round = 0;
        while (strlen($hex) < 24) {
            $hex .= str_pad(dechex(self::djb2("{$trimmed}:{$round}")), 8, '0', STR_PAD_LEFT);
            $round++;
        }
        return substr($hex, 0, 24);
    }

    /** Mirrors the reference app's `djb2()`, including its JS Int32 bitwise-op wraparound. */
    private static function djb2(string $str): int
    {
        $hash = 5381;
        $length = strlen($str);
        for ($i = 0; $i < $length; $i++) {
            $hash = self::toInt32($hash * 33) ^ ord($str[$i]);
        }
        return $hash < 0 ? $hash + self::UINT32_MODULUS : $hash;
    }

    /** Wraps an arbitrary integer into JS's signed Int32 range, the same way `x | 0` / bitwise ops would. */
    private static function toInt32(int $n): int
    {
        $n %= self::UINT32_MODULUS;
        if ($n >= self::INT32_MAX) {
            $n -= self::UINT32_MODULUS;
        } elseif ($n < -self::INT32_MAX) {
            $n += self::UINT32_MODULUS;
        }
        return $n;
    }
}
