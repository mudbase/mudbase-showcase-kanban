<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Http\Csrf;
use App\Http\Flash;
use App\Http\Response;
use App\Mudbase\MudbaseApiError;
use App\Support\PseudoId;
use App\View;

/**
 * The board itself — lists (columns) and cards, mirroring the reference app's `/` (BoardView +
 * ListColumn + CardItem + AddListForm + MoveCardControl). List management is owner-only; card
 * management is owner/member; every role can read. See plan/build-plan.md "RBAC Matrix".
 *
 * Deliberately does NOT pre-check role before attempting a write (no
 * `if (!Rbac::canManageLists($ctx->role())) { ...403... }` guard anywhere below) — every mutating
 * method just calls the same MudbaseClient write a permitted role would use and lets Mudbase's own
 * collection permissions return the real 403 if the signed-in role isn't allowed. That is the
 * actual security boundary (verified live — see plan/build-plan.md); `src/Support/Rbac.php` is
 * used only in the views to hide/disable controls, never here.
 */
final class BoardController
{
    private const MAX_LIST_NAME_LENGTH = 60;
    private const MAX_CARD_TITLE_LENGTH = 120;
    private const MAX_CARD_DESCRIPTION_LENGTH = 2000;

    /** @param array<string, string> $params */
    public function index(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireSignIn('/');

        $error = null;
        $lists = [];
        $cardsByListId = [];
        try {
            $lists = $this->loadLists($ctx);
            $cards = $this->loadCards($ctx);
            foreach ($cards as $card) {
                $listId = (string) ($card['listId'] ?? '');
                $cardsByListId[$listId] ??= [];
                $cardsByListId[$listId][] = $card;
            }
        } catch (MudbaseApiError $e) {
            $error = "Couldn't load the board right now: {$e->getMessage()}";
        }

        View::render('board', [
            'lists' => $lists,
            'cardsByListId' => $cardsByListId,
            'error' => $error,
        ]);
    }

    /** @param array<string, string> $params */
    public function createList(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireSignIn('/');
        $this->requireCsrf('/');

        $name = trim((string) ($_POST['name'] ?? ''));
        if ($name === '') {
            Flash::set('error', 'List name is required.');
            Response::redirect('/');
        }
        if (mb_strlen($name) > self::MAX_LIST_NAME_LENGTH) {
            Flash::set('error', 'Keep the list name under ' . self::MAX_LIST_NAME_LENGTH . ' characters.');
            Response::redirect('/');
        }

        $actor = $this->actorFields($ctx);

        try {
            $lists = $this->loadLists($ctx);
            $ctx->mudbase->createDocument($ctx->listsCollectionId, [
                'boardId' => $ctx->boardId,
                'name' => $name,
                'position' => count($lists),
            ]);
            $ctx->mudbase->createDocument($ctx->activityCollectionId, [
                'boardId' => $ctx->boardId,
                'actorId' => $actor['actorId'],
                'actorName' => $actor['actorName'],
                'action' => 'created_list',
                'toList' => $name,
            ]);
        } catch (MudbaseApiError $e) {
            $this->flashWriteError($e, 'manage lists');
            Response::redirect('/');
        }

        Response::redirect('/');
    }

    /** @param array{id: string} $params */
    public function renameList(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireSignIn('/');
        $this->requireCsrf('/');

        $listId = $params['id'];
        $newName = trim((string) ($_POST['newName'] ?? ''));
        if ($newName === '') {
            Flash::set('error', 'List name is required.');
            Response::redirect('/');
        }
        if (mb_strlen($newName) > self::MAX_LIST_NAME_LENGTH) {
            Flash::set('error', 'Keep the list name under ' . self::MAX_LIST_NAME_LENGTH . ' characters.');
            Response::redirect('/');
        }

        $actor = $this->actorFields($ctx);

        try {
            $existing = $ctx->mudbase->getDocument($ctx->listsCollectionId, $listId);
            $oldName = (string) ($existing['name'] ?? '');
            $ctx->mudbase->updateDocument($ctx->listsCollectionId, $listId, ['name' => $newName]);
            $ctx->mudbase->createDocument($ctx->activityCollectionId, [
                'boardId' => $ctx->boardId,
                'actorId' => $actor['actorId'],
                'actorName' => $actor['actorName'],
                'action' => 'renamed_list',
                'fromList' => $oldName,
                'toList' => $newName,
            ]);
        } catch (MudbaseApiError $e) {
            $this->flashWriteError($e, 'manage lists');
            Response::redirect('/');
        }

        Response::redirect('/');
    }

    /** @param array{id: string} $params */
    public function deleteList(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireSignIn('/');
        $this->requireCsrf('/');

        $listId = $params['id'];
        $actor = $this->actorFields($ctx);

        try {
            $existing = $ctx->mudbase->getDocument($ctx->listsCollectionId, $listId);
            $name = (string) ($existing['name'] ?? '');

            // A list's cards have nowhere else to live once the column is gone - there is no
            // "uncategorized" list to fall back to, so every card in it is deleted first, same as
            // the reference app's useDeleteList. Best-effort in the same sense that reference
            // implementation is: if this fails partway through, some cards may already be gone
            // while the list itself remains - a re-attempt of the delete is safe (idempotent per
            // remaining row) and is the same risk profile the reference web app accepts.
            $cardsResult = $ctx->mudbase->listDocuments(
                $ctx->cardsCollectionId,
                ['boardId' => $ctx->boardId, 'listId' => $listId],
                'position',
                1,
                100,
            );
            foreach ($cardsResult['data'] as $card) {
                $ctx->mudbase->deleteDocument($ctx->cardsCollectionId, (string) $card['_id']);
            }

            $ctx->mudbase->deleteDocument($ctx->listsCollectionId, $listId);
            $ctx->mudbase->createDocument($ctx->activityCollectionId, [
                'boardId' => $ctx->boardId,
                'actorId' => $actor['actorId'],
                'actorName' => $actor['actorName'],
                'action' => 'deleted_list',
                'fromList' => $name,
            ]);
        } catch (MudbaseApiError $e) {
            $this->flashWriteError($e, 'manage lists');
            Response::redirect('/');
        }

        Response::redirect('/');
    }

    /** @param array{id: string} $params */
    public function moveList(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireSignIn('/');
        $this->requireCsrf('/');

        $listId = $params['id'];
        $direction = (string) ($_POST['direction'] ?? '');
        if ($direction !== 'left' && $direction !== 'right') {
            Flash::set('error', 'Invalid move request.');
            Response::redirect('/');
        }

        try {
            $lists = $this->loadLists($ctx);
            $index = $this->indexOfId($lists, $listId);
            if ($index === null) {
                Flash::set('error', 'That list no longer exists.');
                Response::redirect('/');
            }

            $neighborIndex = $direction === 'left' ? $index - 1 : $index + 1;
            if ($neighborIndex < 0 || $neighborIndex >= count($lists)) {
                Flash::set('error', $direction === 'left' ? 'Already the first list.' : 'Already the last list.');
                Response::redirect('/');
            }

            $list = $lists[$index];
            $neighbor = $lists[$neighborIndex];

            $ctx->mudbase->updateDocument($ctx->listsCollectionId, (string) $list['_id'], ['position' => $neighbor['position']]);
            $ctx->mudbase->updateDocument($ctx->listsCollectionId, (string) $neighbor['_id'], ['position' => $list['position']]);
        } catch (MudbaseApiError $e) {
            $this->flashWriteError($e, 'manage lists');
            Response::redirect('/');
        }

        Response::redirect('/');
    }

    /** @param array<string, string> $params */
    public function createCard(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireSignIn('/');
        $this->requireCsrf('/');

        $listId = trim((string) ($_POST['listId'] ?? ''));
        $title = trim((string) ($_POST['title'] ?? ''));
        $description = trim((string) ($_POST['description'] ?? ''));
        $assigneeName = trim((string) ($_POST['assigneeName'] ?? ''));

        if ($listId === '') {
            Flash::set('error', 'Choose a list for this card.');
            Response::redirect('/');
        }
        if ($title === '') {
            Flash::set('error', 'Card title is required.');
            Response::redirect('/');
        }
        if (mb_strlen($title) > self::MAX_CARD_TITLE_LENGTH) {
            Flash::set('error', 'Keep the card title under ' . self::MAX_CARD_TITLE_LENGTH . ' characters.');
            Response::redirect('/');
        }
        if (mb_strlen($description) > self::MAX_CARD_DESCRIPTION_LENGTH) {
            Flash::set('error', 'Keep the description under ' . self::MAX_CARD_DESCRIPTION_LENGTH . ' characters.');
            Response::redirect('/');
        }

        $actor = $this->actorFields($ctx);

        try {
            $listNames = $this->listNameMap($ctx);
            $listName = $listNames[$listId] ?? null;
            if ($listName === null) {
                Flash::set('error', 'That list no longer exists.');
                Response::redirect('/');
            }

            $cardsInList = $ctx->mudbase->listDocuments(
                $ctx->cardsCollectionId,
                ['boardId' => $ctx->boardId, 'listId' => $listId],
                'position',
                1,
                100,
            );

            $fields = [
                'boardId' => $ctx->boardId,
                'listId' => $listId,
                'title' => $title,
                'position' => count($cardsInList['data']),
                'createdById' => $actor['actorId'],
                'createdByName' => $actor['actorName'],
            ];
            if ($description !== '') {
                $fields['description'] = $description;
            }
            if ($assigneeName !== '') {
                $fields['assigneeId'] = PseudoId::pseudoObjectId($assigneeName);
                $fields['assigneeName'] = $assigneeName;
            }

            $ctx->mudbase->createDocument($ctx->cardsCollectionId, $fields);
            $ctx->mudbase->createDocument($ctx->activityCollectionId, [
                'boardId' => $ctx->boardId,
                'actorId' => $actor['actorId'],
                'actorName' => $actor['actorName'],
                'action' => 'created_card',
                'cardTitle' => $title,
                'toList' => $listName,
            ]);
        } catch (MudbaseApiError $e) {
            $this->flashWriteError($e, 'add cards');
            Response::redirect('/');
        }

        Response::redirect('/');
    }

    /** @param array{id: string} $params */
    public function editCard(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireSignIn('/');
        $this->requireCsrf('/');

        $cardId = $params['id'];
        $title = trim((string) ($_POST['title'] ?? ''));
        $description = trim((string) ($_POST['description'] ?? ''));
        $assigneeName = trim((string) ($_POST['assigneeName'] ?? ''));

        if ($title === '') {
            Flash::set('error', 'Card title is required.');
            Response::redirect('/');
        }
        if (mb_strlen($title) > self::MAX_CARD_TITLE_LENGTH) {
            Flash::set('error', 'Keep the card title under ' . self::MAX_CARD_TITLE_LENGTH . ' characters.');
            Response::redirect('/');
        }
        if (mb_strlen($description) > self::MAX_CARD_DESCRIPTION_LENGTH) {
            Flash::set('error', 'Keep the description under ' . self::MAX_CARD_DESCRIPTION_LENGTH . ' characters.');
            Response::redirect('/');
        }

        try {
            // `assigneeId` is validated server-side as an ObjectId reference (verified live by the
            // reference web app - see its build-plan.md). An empty string fails that check the
            // same way an invalid slug would; `null` is the value that actually clears it - never
            // send "" here. `description` has no such constraint, so an empty string is fine.
            $ctx->mudbase->updateDocument($ctx->cardsCollectionId, $cardId, [
                'title' => $title,
                'description' => $description,
                'assigneeId' => $assigneeName !== '' ? PseudoId::pseudoObjectId($assigneeName) : null,
                'assigneeName' => $assigneeName !== '' ? $assigneeName : null,
            ]);
        } catch (MudbaseApiError $e) {
            $this->flashWriteError($e, 'edit cards');
            Response::redirect('/');
        }

        Response::redirect('/');
    }

    /** @param array{id: string} $params */
    public function deleteCard(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireSignIn('/');
        $this->requireCsrf('/');

        $cardId = $params['id'];
        $actor = $this->actorFields($ctx);

        try {
            $card = $ctx->mudbase->getDocument($ctx->cardsCollectionId, $cardId);
            $listNames = $this->listNameMap($ctx);
            $listName = $listNames[(string) ($card['listId'] ?? '')] ?? 'a list';

            $ctx->mudbase->deleteDocument($ctx->cardsCollectionId, $cardId);
            $ctx->mudbase->createDocument($ctx->activityCollectionId, [
                'boardId' => $ctx->boardId,
                'actorId' => $actor['actorId'],
                'actorName' => $actor['actorName'],
                'action' => 'deleted_card',
                'cardTitle' => (string) ($card['title'] ?? 'Untitled'),
                'fromList' => $listName,
            ]);
        } catch (MudbaseApiError $e) {
            $this->flashWriteError($e, 'delete cards');
            Response::redirect('/');
        }

        Response::redirect('/');
    }

    /**
     * Handles both forms of card movement the reference app's MoveCardControl offers: a
     * cross-list move (`toListId` present, appended to the end of the target column) or a
     * same-list reorder (`direction` = up/down, position swap with the adjacent card). Every move
     * writes `listId`+`position` and appends a `moved` activity entry, per the task spec - a
     * same-list reorder logs it with `fromList === toList`.
     *
     * @param array{id: string} $params
     */
    public function moveCard(array $params): void
    {
        $ctx = AppContext::current();
        $ctx->requireSignIn('/');
        $this->requireCsrf('/');

        $cardId = $params['id'];
        $toListId = trim((string) ($_POST['toListId'] ?? ''));
        $direction = (string) ($_POST['direction'] ?? '');
        $actor = $this->actorFields($ctx);

        try {
            $card = $ctx->mudbase->getDocument($ctx->cardsCollectionId, $cardId);
            $currentListId = (string) ($card['listId'] ?? '');
            $cardTitle = (string) ($card['title'] ?? 'Untitled');

            if ($toListId !== '') {
                $this->moveCardToList($ctx, $cardId, $currentListId, $toListId, $cardTitle, $actor);
            } elseif ($direction === 'up' || $direction === 'down') {
                $this->reorderCardInList($ctx, $card, $cardId, $currentListId, $direction, $cardTitle, $actor);
            } else {
                Flash::set('error', 'Invalid move request.');
                Response::redirect('/');
            }
        } catch (MudbaseApiError $e) {
            $this->flashWriteError($e, 'move cards');
            Response::redirect('/');
        }

        Response::redirect('/');
    }

    /**
     * @param array{actorId: string, actorName: string} $actor
     */
    private function moveCardToList(
        AppContext $ctx,
        string $cardId,
        string $currentListId,
        string $toListId,
        string $cardTitle,
        array $actor,
    ): void {
        if ($toListId === $currentListId) {
            Flash::set('error', 'That card is already in that list.');
            Response::redirect('/');
        }

        $listNames = $this->listNameMap($ctx);
        $fromListName = $listNames[$currentListId] ?? '?';
        $toListName = $listNames[$toListId] ?? null;
        if ($toListName === null) {
            Flash::set('error', 'That list no longer exists.');
            Response::redirect('/');
        }

        $targetCards = $ctx->mudbase->listDocuments(
            $ctx->cardsCollectionId,
            ['boardId' => $ctx->boardId, 'listId' => $toListId],
            'position',
            1,
            100,
        );
        $newPosition = count($targetCards['data']);

        $ctx->mudbase->updateDocument($ctx->cardsCollectionId, $cardId, [
            'listId' => $toListId,
            'position' => $newPosition,
        ]);
        $ctx->mudbase->createDocument($ctx->activityCollectionId, [
            'boardId' => $ctx->boardId,
            'actorId' => $actor['actorId'],
            'actorName' => $actor['actorName'],
            'action' => 'moved',
            'cardTitle' => $cardTitle,
            'fromList' => $fromListName,
            'toList' => $toListName,
        ]);
    }

    /**
     * @param array<string, mixed> $card
     * @param array{actorId: string, actorName: string} $actor
     */
    private function reorderCardInList(
        AppContext $ctx,
        array $card,
        string $cardId,
        string $currentListId,
        string $direction,
        string $cardTitle,
        array $actor,
    ): void {
        $siblings = $ctx->mudbase->listDocuments(
            $ctx->cardsCollectionId,
            ['boardId' => $ctx->boardId, 'listId' => $currentListId],
            'position',
            1,
            100,
        )['data'];

        $index = $this->indexOfId($siblings, $cardId);
        if ($index === null) {
            Flash::set('error', 'That card no longer exists.');
            Response::redirect('/');
        }

        $neighborIndex = $direction === 'up' ? $index - 1 : $index + 1;
        if ($neighborIndex < 0 || $neighborIndex >= count($siblings)) {
            Flash::set('error', $direction === 'up' ? 'Already at the top of this list.' : 'Already at the bottom of this list.');
            Response::redirect('/');
        }

        $neighbor = $siblings[$neighborIndex];
        $listNames = $this->listNameMap($ctx);
        $listName = $listNames[$currentListId] ?? '?';

        $ctx->mudbase->updateDocument($ctx->cardsCollectionId, $cardId, ['position' => $neighbor['position']]);
        $ctx->mudbase->updateDocument($ctx->cardsCollectionId, (string) $neighbor['_id'], ['position' => $card['position']]);
        $ctx->mudbase->createDocument($ctx->activityCollectionId, [
            'boardId' => $ctx->boardId,
            'actorId' => $actor['actorId'],
            'actorName' => $actor['actorName'],
            'action' => 'moved',
            'cardTitle' => $cardTitle,
            'fromList' => $listName,
            'toList' => $listName,
        ]);
    }

    /** @return list<array<string, mixed>> */
    private function loadLists(AppContext $ctx): array
    {
        return $ctx->mudbase->listDocuments($ctx->listsCollectionId, ['boardId' => $ctx->boardId], 'position', 1, 100)['data'];
    }

    /** @return list<array<string, mixed>> */
    private function loadCards(AppContext $ctx): array
    {
        return $ctx->mudbase->listDocuments($ctx->cardsCollectionId, ['boardId' => $ctx->boardId], 'position', 1, 100)['data'];
    }

    /** @return array<string, string> map of listId => list name */
    private function listNameMap(AppContext $ctx): array
    {
        $map = [];
        foreach ($this->loadLists($ctx) as $list) {
            $map[(string) $list['_id']] = (string) ($list['name'] ?? '');
        }
        return $map;
    }

    /** @param list<array<string, mixed>> $items */
    private function indexOfId(array $items, string $id): ?int
    {
        foreach ($items as $index => $item) {
            if ((string) ($item['_id'] ?? '') === $id) {
                return $index;
            }
        }
        return null;
    }

    /** @return array{actorId: string, actorName: string} */
    private function actorFields(AppContext $ctx): array
    {
        $actorId = $ctx->userId();
        if ($actorId === null) {
            throw new \RuntimeException('Must be signed in');
        }
        return ['actorId' => $actorId, 'actorName' => $ctx->displayName() ?? 'Member'];
    }

    /** Surfaces a real 403 from Mudbase's own collection permissions as a clear, non-technical flash message. */
    private function flashWriteError(MudbaseApiError $e, string $capability): void
    {
        Flash::set(
            'error',
            $e->isForbidden()
                ? "You don't have permission to {$capability}."
                : "That didn't work: {$e->getMessage()}",
        );
    }

    private function requireCsrf(string $fallbackRedirect): void
    {
        if (!Csrf::verify($_POST['_csrf'] ?? null)) {
            Flash::set('error', 'Your session expired — please try again.');
            Response::redirect($fallbackRedirect);
        }
    }
}
