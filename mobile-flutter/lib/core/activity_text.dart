import '../models/activity_entry.dart';

/// Renders one activity row as a plain, readable sentence for the feed.
/// Mirrors `describeActivity` in `web/src/lib/activity-text.ts` verbatim,
/// with one addition: an `ActivityAction.unknown` arm for forward
/// compatibility with a server-sent `action` value this client doesn't
/// recognize yet (the TS version's `switch` has a `default` arm for the
/// same defensive reason, even though its union type is nominally
/// exhaustive).
String describeActivity(ActivityEntry entry) {
  final who = entry.actorName.isNotEmpty ? entry.actorName : 'Someone';
  return switch (entry.action) {
    ActivityAction.createdCard =>
      '$who created card "${entry.cardTitle ?? "Untitled"}" in ${entry.toList ?? "a list"}',
    ActivityAction.moved => _describeMoved(who, entry),
    ActivityAction.deletedCard =>
      '$who deleted card "${entry.cardTitle ?? "Untitled"}" from ${entry.fromList ?? "a list"}',
    ActivityAction.createdList =>
      '$who created list "${entry.toList ?? "Untitled"}"',
    ActivityAction.renamedList =>
      '$who renamed list "${entry.fromList ?? "?"}" to "${entry.toList ?? "?"}"',
    ActivityAction.deletedList =>
      '$who deleted list "${entry.fromList ?? "Untitled"}"',
    ActivityAction.unknown => '$who did something on the board',
  };
}

String _describeMoved(String who, ActivityEntry entry) {
  final fromList = entry.fromList;
  final toList = entry.toList;
  if (fromList != null && toList != null && fromList == toList) {
    return '$who reordered "${entry.cardTitle ?? "a card"}" within $toList';
  }
  return '$who moved "${entry.cardTitle ?? "a card"}" from ${fromList ?? "?"} to ${toList ?? "?"}';
}
