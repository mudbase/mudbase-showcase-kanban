<?php
/**
 * @var list<array<string, mixed>> $entries
 * @var string|null $error
 */

use App\Support\ActivityText;
use App\Support\TimeFormat;
use App\View;

$title = 'Activity';
?>

<h1>Activity</h1>
<p class="muted" style="max-width:40rem">Every list and card change on this board, newest first.</p>

<?php if ($error !== null): ?>
  <p class="flash flash--error"><?= View::escape($error) ?></p>
<?php elseif ($entries === []): ?>
  <div class="empty-state">
    <p>No activity yet — create a list or card to get started.</p>
  </div>
<?php else: ?>
  <ul class="activity-list">
    <?php foreach ($entries as $entry): ?>
      <li class="activity-item">
        <span><?= View::escape(ActivityText::describe($entry)) ?></span>
        <span class="activity-item__time"><?= View::escape(TimeFormat::relative(is_string($entry['createdAt'] ?? null) ? $entry['createdAt'] : null)) ?></span>
      </li>
    <?php endforeach; ?>
  </ul>
<?php endif; ?>
