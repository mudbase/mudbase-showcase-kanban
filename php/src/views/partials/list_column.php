<?php
/**
 * Rendered once per list from board.php, in the same variable scope (plain `require`, no
 * template engine — see src/View.php). Expects, in addition to the variables already in scope
 * there ($context, $canManageLists, $canManageCards):
 *
 * @var array<string, mixed> $list
 * @var string $listId
 * @var list<array<string, mixed>> $cardsInList
 * @var list<array<string, mixed>> $otherLists
 */

use App\Http\Csrf;
use App\View;

$listName = (string) ($list['name'] ?? '');
?>
<div class="list-column">
  <div class="list-column__header">
    <h3 class="list-column__title"><?= View::escape($listName) ?></h3>
    <span class="list-column__count"><?= count($cardsInList) ?></span>
  </div>

  <?php if ($canManageLists): ?>
    <div class="list-column__controls">
      <form method="post" action="/lists/<?= urlencode($listId) ?>/move">
        <?= Csrf::field() ?>
        <input type="hidden" name="direction" value="left">
        <button type="submit" class="btn btn--outline btn--xs" aria-label="Move list left">&#9664;</button>
      </form>
      <form method="post" action="/lists/<?= urlencode($listId) ?>/move">
        <?= Csrf::field() ?>
        <input type="hidden" name="direction" value="right">
        <button type="submit" class="btn btn--outline btn--xs" aria-label="Move list right">&#9654;</button>
      </form>
      <details class="inline-edit">
        <summary>Rename</summary>
        <div class="card">
          <form method="post" action="/lists/<?= urlencode($listId) ?>/rename">
            <?= Csrf::field() ?>
            <div class="field" style="margin-bottom:0.5rem">
              <input type="text" name="newName" maxlength="60" value="<?= View::escape($listName) ?>" required>
            </div>
            <button type="submit" class="btn btn--xs">Save name</button>
          </form>
        </div>
      </details>
      <form method="post" action="/lists/<?= urlencode($listId) ?>/delete">
        <?= Csrf::field() ?>
        <button type="submit" class="btn btn--destructive btn--xs">Delete list</button>
      </form>
    </div>
  <?php endif; ?>

  <div class="card-list">
    <?php foreach ($cardsInList as $card): ?>
      <?php require __DIR__ . '/card_item.php'; ?>
    <?php endforeach; ?>
  </div>

  <?php if ($canManageCards): ?>
    <details class="inline-edit">
      <summary>+ Add card</summary>
      <div class="card">
        <form method="post" action="/cards">
          <?= Csrf::field() ?>
          <input type="hidden" name="listId" value="<?= View::escape($listId) ?>">
          <div class="field" style="margin-bottom:0.5rem">
            <label class="sr-only" for="title-<?= View::escape($listId) ?>">Card title</label>
            <input type="text" id="title-<?= View::escape($listId) ?>" name="title" maxlength="120" placeholder="Card title" required>
          </div>
          <div class="field" style="margin-bottom:0.5rem">
            <label class="sr-only" for="description-<?= View::escape($listId) ?>">Description</label>
            <textarea id="description-<?= View::escape($listId) ?>" name="description" maxlength="2000" placeholder="Description (optional)"></textarea>
          </div>
          <div class="field" style="margin-bottom:0.5rem">
            <label class="sr-only" for="assignee-<?= View::escape($listId) ?>">Assignee</label>
            <input type="text" id="assignee-<?= View::escape($listId) ?>" name="assigneeName" maxlength="80" placeholder="Assignee name (optional)">
          </div>
          <button type="submit" class="btn btn--sm btn--block">Add card</button>
        </form>
      </div>
    </details>
  <?php endif; ?>
</div>
