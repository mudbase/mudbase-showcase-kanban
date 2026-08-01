/// Mirrors the web app's `ActivityAction` union (`web/src/types/activity.ts`)
/// as a Dart `enum` (idiomatic per this project's Dart pattern rules -
/// sealed/enum types with exhaustive `switch`, rather than a raw string
/// field). `unknown` is not written by this app but exists so parsing a
/// server row with an action value this client doesn't recognize yet fails
/// soft (see `ActivityEntry.fromJson`) instead of throwing.
enum ActivityAction {
  createdCard,
  moved,
  deletedCard,
  createdList,
  renamedList,
  deletedList,
  unknown;

  static ActivityAction fromWire(String? value) {
    return switch (value) {
      'created_card' => ActivityAction.createdCard,
      'moved' => ActivityAction.moved,
      'deleted_card' => ActivityAction.deletedCard,
      'created_list' => ActivityAction.createdList,
      'renamed_list' => ActivityAction.renamedList,
      'deleted_list' => ActivityAction.deletedList,
      _ => ActivityAction.unknown,
    };
  }

  String get wireValue {
    return switch (this) {
      ActivityAction.createdCard => 'created_card',
      ActivityAction.moved => 'moved',
      ActivityAction.deletedCard => 'deleted_card',
      ActivityAction.createdList => 'created_list',
      ActivityAction.renamedList => 'renamed_list',
      ActivityAction.deletedList => 'deleted_list',
      ActivityAction.unknown => 'unknown',
    };
  }
}

/// Mirrors the web app's `ActivityEntry` (`web/src/types/activity.ts`) and
/// the live `activity` collection schema (`boardId`, `actorId`, `actorName`,
/// `action`, `cardTitle?`, `fromList?`, `toList?`). Fetched
/// `sort: "-createdAt"` for the reverse-chronological feed - see
/// `ActivityRepository.listForBoard`.
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.boardId,
    required this.actorId,
    required this.actorName,
    required this.action,
    this.cardTitle,
    this.fromList,
    this.toList,
    required this.createdAt,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      id: json['_id'] as String? ?? '',
      boardId: json['boardId'] as String? ?? '',
      actorId: json['actorId'] as String? ?? '',
      actorName: json['actorName'] as String? ?? '',
      action: ActivityAction.fromWire(json['action'] as String?),
      cardTitle: json['cardTitle'] as String?,
      fromList: json['fromList'] as String?,
      toList: json['toList'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String boardId;
  final String actorId;
  final String actorName;
  final ActivityAction action;
  final String? cardTitle;
  final String? fromList;
  final String? toList;
  final DateTime createdAt;
}
