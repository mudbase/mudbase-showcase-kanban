<?php
/**
 * Rendered once per card from list_column.php, in the same variable scope. Expects, in addition
 * to the variables already in scope there ($listId, $otherLists, $canManageCards, $context):
 *
 * @var array<string, mixed> $card
 */

use App\Http\Csrf;
use App\Support\TimeFormat;
use App\View;

$cardId = (string) $card['_id'];
$cardTitle = (string) ($card['title'] ?? '');
$description = is_string($card['description'] ?? null) ? $card['description'] : '';
$assigneeName = is_string($card['assigneeName'] ?? null) ? $card['assigneeName'] : null;
$createdByName = is_string($card['createdByName'] ?? null) ? $card['createdByName'] : 'Someone';
$createdAt = is_string($card['createdAt'] ?? null) ? $card['createdAt'] : null;
?>
<div class="card-item">
  <p class="card-item__title"><?= View::escape($cardTitle) ?></p>
  <?php if ($description !== ''): ?>
    <p class="card-item__description"><?= View::escape($description) ?></p>
  <?php endif; ?>

  <div class="card-item__meta">
    <span>Added by <?= View::escape($createdByName) ?> · <?= View::escape(TimeFormat::relative($createdAt)) ?></span>
    <?php if ($assigneeName !== null): ?>
      <span class="assignee-chip"><?= View::escape($assigneeName) ?></span>
    <?php endif; ?>
  </div>

  <?php if ($canManageCards): ?>
    <div class="card-item__controls">
      <form method="post" action="/cards/<?= urlencode($cardId) ?>/move">
        <?= Csrf::field() ?>
        <input type="hidden" name="direction" value="up">
        <button type="submit" class="btn btn--outline btn--xs" aria-label="Move card up">&#9650;</button>
      </form>
      <form method="post" action="/cards/<?= urlencode($cardId) ?>/move">
        <?= Csrf::field() ?>
        <input type="hidden" name="direction" value="down">
        <button type="submit" class="btn btn--outline btn--xs" aria-label="Move card down">&#9660;</button>
      </form>
      <form method="post" action="/cards/<?= urlencode($cardId) ?>/delete">
        <?= Csrf::field() ?>
        <button type="submit" class="btn btn--destructive btn--xs">Delete</button>
      </form>

      <?php if ($otherLists !== []): ?>
        <form method="post" action="/cards/<?= urlencode($cardId) ?>/move" class="card-item__move-form">
          <?= Csrf::field() ?>
          <label class="sr-only" for="move-to-<?= View::escape($cardId) ?>">Move to list</label>
          <select id="move-to-<?= View::escape($cardId) ?>" name="toListId">
            <?php foreach ($otherLists as $other): ?>
              <option value="<?= View::escape((string) $other['_id']) ?>"><?= View::escape((string) ($other['name'] ?? '')) ?></option>
            <?php endforeach; ?>
          </select>
          <button type="submit" class="btn btn--outline btn--xs">Move</button>
        </form>
      <?php endif; ?>

      <details class="inline-edit" style="width:100%">
        <summary>Edit</summary>
        <div class="card">
          <form method="post" action="/cards/<?= urlencode($cardId) ?>/edit">
            <?= Csrf::field() ?>
            <div class="field" style="margin-bottom:0.5rem">
              <label class="sr-only" for="edit-title-<?= View::escape($cardId) ?>">Title</label>
              <input type="text" id="edit-title-<?= View::escape($cardId) ?>" name="title" maxlength="120" value="<?= View::escape($cardTitle) ?>" required>
            </div>
            <div class="field" style="margin-bottom:0.5rem">
              <label class="sr-only" for="edit-description-<?= View::escape($cardId) ?>">Description</label>
              <textarea id="edit-description-<?= View::escape($cardId) ?>" name="description" maxlength="2000" placeholder="Description (optional)"><?= View::escape($description) ?></textarea>
            </div>
            <div class="field" style="margin-bottom:0.5rem">
              <label class="sr-only" for="edit-assignee-<?= View::escape($cardId) ?>">Assignee</label>
              <input type="text" id="edit-assignee-<?= View::escape($cardId) ?>" name="assigneeName" maxlength="80" placeholder="Assignee name (optional)" value="<?= View::escape($assigneeName ?? '') ?>">
            </div>
            <button type="submit" class="btn btn--xs">Save card</button>
          </form>
        </div>
      </details>
    </div>
  <?php endif; ?>
</div>
