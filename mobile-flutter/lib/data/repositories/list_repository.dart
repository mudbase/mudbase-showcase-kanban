import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/board_list.dart';

class ListRepository {
  const ListRepository(this._dataService);

  final MudbaseDataService _dataService;

  /// All lists for the single shared board, ascending by column order.
  Future<List<BoardList>> listForBoard({
    required String token,
    required String boardId,
  }) async {
    final docs = await _dataService.list(
      EnvConfig.listsCollectionId,
      token: token,
      filter: {'boardId': boardId},
      sort: 'position',
      limit: 200,
    );
    return docs.map(BoardList.fromJson).toList();
  }

  /// Owner-only: creates a new column at the end of the board.
  Future<BoardList> create({
    required String token,
    required String boardId,
    required String name,
    required int position,
  }) async {
    final doc = await _dataService.create(EnvConfig.listsCollectionId, {
      'boardId': boardId,
      'name': name,
      'position': position,
    }, token: token);
    return BoardList.fromJson(doc);
  }

  /// Owner-only: renames a column.
  Future<BoardList> rename({
    required String token,
    required String listId,
    required String newName,
  }) async {
    final doc = await _dataService.update(EnvConfig.listsCollectionId, listId, {
      'name': newName,
    }, token: token);
    return BoardList.fromJson(doc);
  }

  /// Owner-only: swaps this list's position with an adjacent one
  /// (left/right reorder).
  Future<void> reorder({
    required String token,
    required BoardList list,
    required BoardList neighbor,
  }) async {
    await Future.wait([
      _dataService.update(EnvConfig.listsCollectionId, list.id, {
        'position': neighbor.position,
      }, token: token),
      _dataService.update(EnvConfig.listsCollectionId, neighbor.id, {
        'position': list.position,
      }, token: token),
    ]);
  }

  /// Owner-only: deletes a column. The caller (`BoardController.deleteList`)
  /// is responsible for cascading card deletion first - a list's cards have
  /// nowhere else to live once the column is gone, there's no
  /// "uncategorized" list to fall back to.
  Future<void> delete({required String token, required String listId}) async {
    await _dataService.delete(EnvConfig.listsCollectionId, listId, token: token);
  }
}
