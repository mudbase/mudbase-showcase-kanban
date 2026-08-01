import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/board_card.dart';

class CardRepository {
  const CardRepository(this._dataService);

  final MudbaseDataService _dataService;

  /// All cards for the single shared board, ascending by in-column order -
  /// fetched once and grouped client-side by `listId` (see
  /// `BoardState.cardsByListId`), rather than one query per column.
  Future<List<BoardCard>> listForBoard({
    required String token,
    required String boardId,
  }) async {
    final docs = await _dataService.list(
      EnvConfig.cardsCollectionId,
      token: token,
      filter: {'boardId': boardId},
      sort: 'position',
      limit: 500,
    );
    return docs.map(BoardCard.fromJson).toList();
  }

  /// Owner/member: creates a new card at the end of a column.
  Future<BoardCard> create({
    required String token,
    required String boardId,
    required String listId,
    required String title,
    String? description,
    String? assigneeId,
    String? assigneeName,
    required String createdById,
    required String createdByName,
    required int position,
  }) async {
    final doc = await _dataService.create(EnvConfig.cardsCollectionId, {
      'boardId': boardId,
      'listId': listId,
      'title': title,
      'position': position,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (assigneeId != null) 'assigneeId': assigneeId,
      if (assigneeId != null) 'assigneeName': assigneeName,
      'createdById': createdById,
      'createdByName': createdByName,
    }, token: token);
    return BoardCard.fromJson(doc);
  }

  /// Owner/member: edits a card's title/description/assignee in place. Not
  /// itself logged to the activity feed - only creation, movement, and
  /// deletion are (see `plan/build-plan.md`).
  ///
  /// `assigneeId` is validated server-side as an ObjectId reference - an
  /// empty string fails that check the same way an invalid slug would
  /// (`"Invalid ObjectId format for assigneeId"`, confirmed live by the
  /// reference web app's own build plan). `null` is the value that actually
  /// clears it - never send `""` here.
  Future<BoardCard> update({
    required String token,
    required String cardId,
    required String title,
    String? description,
    String? assigneeId,
    String? assigneeName,
  }) async {
    final doc = await _dataService.update(EnvConfig.cardsCollectionId, cardId, {
      'title': title,
      'description': description ?? '',
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
    }, token: token);
    return BoardCard.fromJson(doc);
  }

  /// Owner/member: deletes a card.
  Future<void> delete({required String token, required String cardId}) async {
    await _dataService.delete(EnvConfig.cardsCollectionId, cardId, token: token);
  }

  /// Owner/member: moves a card to a different column, appended to the end
  /// of it.
  Future<BoardCard> moveToList({
    required String token,
    required String cardId,
    required String toListId,
    required int newPosition,
  }) async {
    final doc = await _dataService.update(EnvConfig.cardsCollectionId, cardId, {
      'listId': toListId,
      'position': newPosition,
    }, token: token);
    return BoardCard.fromJson(doc);
  }

  /// Owner/member: reorders a card up/down within its own column by
  /// swapping `position` with the adjacent card.
  Future<void> reorderInList({
    required String token,
    required BoardCard card,
    required BoardCard neighbor,
  }) async {
    await Future.wait([
      _dataService.update(EnvConfig.cardsCollectionId, card.id, {
        'position': neighbor.position,
      }, token: token),
      _dataService.update(EnvConfig.cardsCollectionId, neighbor.id, {
        'position': card.position,
      }, token: token),
    ]);
  }
}
