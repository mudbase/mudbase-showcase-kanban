import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/activity_entry.dart';

class ActivityRepository {
  const ActivityRepository(this._dataService);

  final MudbaseDataService _dataService;

  static const int feedLimit = 200;

  /// Reverse-chronological activity feed for the shared board.
  Future<List<ActivityEntry>> listForBoard({
    required String token,
    required String boardId,
  }) async {
    final docs = await _dataService.list(
      EnvConfig.activityCollectionId,
      token: token,
      filter: {'boardId': boardId},
      sort: '-createdAt',
      limit: feedLimit,
    );
    return docs.map(ActivityEntry.fromJson).toList();
  }

  /// Appends one activity row. Every list/card mutation this app performs
  /// calls this immediately after its own write succeeds - see
  /// `BoardController`.
  Future<void> log({
    required String token,
    required String boardId,
    required String actorId,
    required String actorName,
    required ActivityAction action,
    String? cardTitle,
    String? fromList,
    String? toList,
  }) async {
    await _dataService.create(EnvConfig.activityCollectionId, {
      'boardId': boardId,
      'actorId': actorId,
      'actorName': actorName,
      'action': action.wireValue,
      if (cardTitle != null) 'cardTitle': cardTitle,
      if (fromList != null) 'fromList': fromList,
      if (toList != null) 'toList': toList,
    }, token: token);
  }
}
