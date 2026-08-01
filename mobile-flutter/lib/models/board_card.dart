/// Mirrors the web app's `BoardCard` (`web/src/types/card.ts`) and the live
/// `cards` collection schema (`boardId`, `listId`, `title`, `description?`,
/// `position`, `assigneeId?`, `assigneeName?`, `createdById`,
/// `createdByName`).
///
/// `assigneeId`/`assigneeName` being `null` is a real, distinct state (an
/// explicitly-cleared assignee - see `CardRepository.update`) from them
/// being absent on a card that never had one - both surface as `null` here
/// since Dart doesn't distinguish "key missing" from "key present with a
/// JSON `null`" once decoded into a `Map`, which is fine: this app never
/// needs to tell those two apart, only whether an assignee is currently set.
class BoardCard {
  const BoardCard({
    required this.id,
    required this.boardId,
    required this.listId,
    required this.title,
    this.description,
    required this.position,
    this.assigneeId,
    this.assigneeName,
    required this.createdById,
    required this.createdByName,
  });

  factory BoardCard.fromJson(Map<String, dynamic> json) {
    return BoardCard(
      id: json['_id'] as String? ?? '',
      boardId: json['boardId'] as String? ?? '',
      listId: json['listId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
      assigneeId: json['assigneeId'] as String?,
      assigneeName: json['assigneeName'] as String?,
      createdById: json['createdById'] as String? ?? '',
      createdByName: json['createdByName'] as String? ?? '',
    );
  }

  final String id;
  final String boardId;
  final String listId;
  final String title;
  final String? description;
  final int position;
  final String? assigneeId;
  final String? assigneeName;
  final String createdById;
  final String createdByName;
}
