<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Mudbase\MudbaseApiError;
use App\View;

/**
 * Full reverse-chronological activity feed — mirrors the reference app's `/activity`
 * (ActivityFeed + ActivityItem). Read-only for every signed-in role.
 */
final class ActivityController
{
    private const FEED_LIMIT = 100;

    /** @param array<string, string> $params */
    public function index(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireSignIn('/activity');

        $entries = [];
        $error = null;
        try {
            $result = $ctx->mudbase->listDocuments(
                $ctx->activityCollectionId,
                ['boardId' => $ctx->boardId],
                '-createdAt',
                1,
                self::FEED_LIMIT,
            );
            $entries = $result['data'];
        } catch (MudbaseApiError $e) {
            $error = "Couldn't load the activity feed right now: {$e->getMessage()}";
        }

        View::render('activity', ['entries' => $entries, 'error' => $error]);
    }
}
