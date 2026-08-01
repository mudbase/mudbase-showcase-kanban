/// Mirrors the web app's `BoardList` (`web/src/types/list.ts`) and the live
/// `lists` collection schema (`boardId`, `name`, `position`) - a board
/// column. Sorted ascending by `position` for column order (see
/// `BoardState.sortedLists`).
class BoardList {
  const BoardList({
    required this.id,
    required this.boardId,
    required this.name,
    required this.position,
  });

  factory BoardList.fromJson(Map<String, dynamic> json) {
    return BoardList(
      id: json['_id'] as String? ?? '',
      boardId: json['boardId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String boardId;
  final String name;
  final int position;
}
