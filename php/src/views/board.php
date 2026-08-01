<?php
/**
 * @var list<array<string, mixed>> $lists
 * @var array<string, list<array<string, mixed>>> $cardsByListId
 * @var string|null $error
 * @var \App\Http\AppContext $context
 */

use App\Http\Csrf;
use App\Support\Rbac;
use App\View;

$title = null;
$role = $context->role();
$canManageLists = Rbac::canManageLists($role);
$canManageCards = Rbac::canManageCards($role);
$isReadOnly = Rbac::isReadOnly($role);
?>

<div class="board-header">
  <div class="board-header__identity">
    <h1 style="margin:0">Team Board</h1>
  </div>
</div>

<?php if ($isReadOnly): ?>
  <p class="readonly-notice">Read-only — you're signed in as <?= View::escape(Rbac::roleLabel($role)) ?>. Ask an owner or member to make changes.</p>
<?php endif; ?>

<?php if ($error !== null): ?>
  <p class="flash flash--error"><?= View::escape($error) ?></p>
<?php elseif ($lists === []): ?>
  <div class="empty-state">
    <p><?= $canManageLists ? 'No lists yet — add the first column below.' : 'No lists on this board yet.' ?></p>
  </div>
<?php endif; ?>

<div class="board-row">
  <?php foreach ($lists as $list): ?>
    <?php
      $listId = (string) $list['_id'];
      $cardsInList = $cardsByListId[$listId] ?? [];
      $otherLists = array_values(array_filter($lists, static fn (array $l): bool => (string) $l['_id'] !== $listId));
      require __DIR__ . '/partials/list_column.php';
    ?>
  <?php endforeach; ?>

  <?php if ($canManageLists): ?>
    <div class="list-column add-list-column">
      <h3 class="list-column__title">Add a list</h3>
      <form method="post" action="/lists">
        <?= Csrf::field() ?>
        <div class="field" style="margin-bottom:0.5rem">
          <label for="new-list-name" class="sr-only">List name</label>
          <input type="text" id="new-list-name" name="name" maxlength="60" placeholder="e.g. Backlog" required>
        </div>
        <button type="submit" class="btn btn--sm btn--block">Add list</button>
      </form>
    </div>
  <?php endif; ?>
</div>
