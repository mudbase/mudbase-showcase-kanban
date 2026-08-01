<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Renders one activity row as a plain, readable sentence for the feed. A line-for-line PHP port
 * of the reference app's `describeActivity` (src/lib/activity-text.ts).
 */
final class ActivityText
{
    /** @param array<string, mixed> $entry */
    public static function describe(array $entry): string
    {
        $who = is_string($entry['actorName'] ?? null) && $entry['actorName'] !== '' ? $entry['actorName'] : 'Someone';
        $action = is_string($entry['action'] ?? null) ? $entry['action'] : '';
        $cardTitle = is_string($entry['cardTitle'] ?? null) ? $entry['cardTitle'] : null;
        $fromList = is_string($entry['fromList'] ?? null) ? $entry['fromList'] : null;
        $toList = is_string($entry['toList'] ?? null) ? $entry['toList'] : null;

        return match ($action) {
            'created_card' => "{$who} created card \"" . ($cardTitle ?? 'Untitled') . '" in ' . ($toList ?? 'a list'),
            'moved' => ($fromList !== null && $toList !== null && $fromList === $toList)
                ? "{$who} reordered \"" . ($cardTitle ?? 'a card') . "\" within {$toList}"
                : "{$who} moved \"" . ($cardTitle ?? 'a card') . '" from ' . ($fromList ?? '?') . ' to ' . ($toList ?? '?'),
            'deleted_card' => "{$who} deleted card \"" . ($cardTitle ?? 'Untitled') . '" from ' . ($fromList ?? 'a list'),
            'created_list' => "{$who} created list \"" . ($toList ?? 'Untitled') . '"',
            'renamed_list' => "{$who} renamed list \"" . ($fromList ?? '?') . '" to "' . ($toList ?? '?') . '"',
            'deleted_list' => "{$who} deleted list \"" . ($fromList ?? 'Untitled') . '"',
            default => "{$who} did something on the board",
        };
    }
}
