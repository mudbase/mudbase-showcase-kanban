import 'package:intl/intl.dart';

/// Relative + absolute timestamp formatting for the activity feed, and the
/// `pseudoObjectId`/`initials` helpers the card assignee flow needs. Ported
/// directly from the reference web app's `src/lib/utils.ts` (same threshold
/// values, same djb2 hash) so a card assigned "Ben Chen" on the web app and
/// on this app always resolve to the identical `assigneeId`.

/// Mirrors `formatRelativeTime` in `web/src/lib/utils.ts` exactly (`"just
/// now"` under 5s, then `"Ns"`/`"Nm"`/`"Nh"`/`"Nd"`, falling back to a plain
/// medium-style date past a week) - deliberately different thresholds/
/// format than the sibling social app's own `formatRelativeTime` (which
/// uses a `"N unit ago"` phrasing), because this port mirrors its own web
/// reference precisely rather than the other showcase's Flutter port.
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final diffSeconds = now.difference(dateTime).inSeconds;

  if (diffSeconds < 5) return 'just now';
  if (diffSeconds < 60) return '${diffSeconds}s';
  final diffMinutes = now.difference(dateTime).inMinutes;
  if (diffMinutes < 60) return '${diffMinutes}m';
  final diffHours = now.difference(dateTime).inHours;
  if (diffHours < 24) return '${diffHours}h';
  final diffDays = now.difference(dateTime).inDays;
  if (diffDays < 7) return '${diffDays}d';
  return DateFormat.yMMMd().format(dateTime);
}

/// Mirrors `formatDateTime` in `web/src/lib/utils.ts` (medium date + short
/// time). Not currently rendered anywhere in this app's UI, but kept for
/// parity since a future detail view (e.g. a card's "created" timestamp)
/// would want it - same rationale the web app documents for keeping both
/// formatters in one file.
String formatDateTime(DateTime dateTime) {
  return '${DateFormat.yMMMd().format(dateTime)}, ${DateFormat.jm().format(dateTime)}';
}

/// Mirrors `initials` in `web/src/lib/utils.ts` - used for the small
/// assignee/actor avatar chip.
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.isNotEmpty ? parts.first.substring(0, 1) : '';
  final last = parts.length > 1 && parts.last.isNotEmpty
      ? parts.last.substring(0, 1)
      : '';
  return (first + last).toUpperCase();
}

/// djb2, a small deterministic string hash - matches `web/src/lib/utils.ts`
/// bit-for-bit: JS's `(hash * 33) ^ charCode` implicitly performs a ToInt32
/// truncation on the left operand as part of evaluating `^`, then a final
/// `>>> 0` reinterprets the signed 32-bit result as unsigned. Dart's
/// `int.toSigned(32)` / `int.toUnsigned(32)` perform the equivalent
/// bit-width truncation/reinterpretation on Dart's arbitrary-precision
/// integers, so this produces the identical hex digits the web app's
/// `djb2()` does for the same input string.
int _djb2(String value) {
  var hash = 5381;
  for (final codeUnit in value.codeUnits) {
    hash = (hash * 33).toSigned(32) ^ codeUnit;
  }
  return hash.toUnsigned(32);
}

/// There is no `users` collection in this app's data model (see
/// `plan/build-plan.md`), so an assignee is captured as a free-typed name
/// rather than looked up from a directory. The reference web app's own
/// build plan documents a live finding: `cards.assigneeId` is schema-typed
/// as an ObjectId reference, not a free-form string as originally assumed -
/// a plain slug like `"mia-member"` is rejected with `"Invalid ObjectId
/// format for assigneeId"`. This derives a stable, valid-looking 24-hex-char
/// id from the typed name (the same name always maps to the same id) purely
/// so `assigneeId` passes that format check and is never left orphaned from
/// `assigneeName` - it is not a real user lookup key.
String pseudoObjectId(String seed) {
  final trimmed = seed.trim().toLowerCase();
  final buffer = StringBuffer();
  var round = 0;
  while (buffer.length < 24) {
    final hex = _djb2('$trimmed:$round').toRadixString(16).padLeft(8, '0');
    buffer.write(hex);
    round++;
  }
  return buffer.toString().substring(0, 24);
}
