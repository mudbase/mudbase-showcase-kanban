import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env_config.dart';
import '../../core/formatters.dart';
import '../../core/mudbase_socket_service.dart';
import '../../core/service_providers.dart';
import '../../data/repository_providers.dart';
import '../../models/activity_entry.dart';
import '../../models/board_card.dart';
import '../../models/board_list.dart';
import '../auth/auth_controller.dart';

/// Holds the whole board (all lists + all cards for the single shared
/// board) as one snapshot - mirrors the reference web app's `BoardView`,
/// which fetches `useBoardLists()`/`useBoardCards()` once each and groups
/// cards by `listId` client-side (`useMemo`) rather than one query per
/// column. This class is that grouping, computed lazily via getters instead
/// of `useMemo` since Dart getters are already only as expensive as calling
/// them.
class BoardState {
  const BoardState({required this.lists, required this.cards});

  final List<BoardList> lists;
  final List<BoardCard> cards;

  List<BoardList> get sortedLists =>
      [...lists]..sort((a, b) => a.position.compareTo(b.position));

  Map<String, List<BoardCard>> get cardsByListId {
    final map = <String, List<BoardCard>>{};
    for (final card in cards) {
      (map[card.listId] ??= <BoardCard>[]).add(card);
    }
    for (final bucket in map.values) {
      bucket.sort((a, b) => a.position.compareTo(b.position));
    }
    return map;
  }

  int nextListPosition() {
    if (lists.isEmpty) return 0;
    return lists.map((l) => l.position).reduce(max) + 1;
  }

  int nextCardPosition(String listId) {
    final inList = cardsByListId[listId] ?? const <BoardCard>[];
    if (inList.isEmpty) return 0;
    return inList.map((c) => c.position).reduce(max) + 1;
  }
}

/// Owns the board's data + every list/card mutation + the realtime
/// subscription that keeps it live. Mirrors the reference web app's
/// `useLists`/`useCards`/`useBoardLive` combined into one controller, since
/// a Flutter screen needs one `AsyncValue` to build against rather than
/// three independent query hooks.
///
/// Every mutation method below: (1) performs its own write(s) via the
/// relevant repository, (2) logs the matching `activity` row per
/// `plan/build-plan.md`'s action table, then (3) calls [refresh] to reload
/// the board - simpler and less failure-prone than patching three
/// differently-shaped local caches by hand, and at demo scale (a handful of
/// lists/cards) a refetch is effectively instant. A realtime event from
/// *another* signed-in user does exactly the same: refetch, not a
/// hand-rolled patch.
class BoardController extends AsyncNotifier<BoardState> {
  void Function()? _unsubscribeCreate;
  void Function()? _unsubscribeUpdate;
  void Function()? _unsubscribeDelete;
  void Function()? _unsubscribeStatus;

  static final Set<String> _collectionIds = {
    EnvConfig.listsCollectionId,
    EnvConfig.cardsCollectionId,
  };

  @override
  Future<BoardState> build() async {
    ref.onDispose(_teardownRealtime);
    final boardState = await _fetchBoard();
    _setupRealtime();
    return boardState;
  }

  Future<BoardState> _fetchBoard() async {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final listRepo = ref.read(listRepositoryProvider);
    final cardRepo = ref.read(cardRepositoryProvider);
    final result = await authNotifier.callAuthorized((token) async {
      final lists = await listRepo.listForBoard(
        token: token,
        boardId: EnvConfig.boardId,
      );
      final cards = await cardRepo.listForBoard(
        token: token,
        boardId: EnvConfig.boardId,
      );
      return (lists: lists, cards: cards);
    });
    return BoardState(lists: result.lists, cards: result.cards);
  }

  /// Reloads the board without flashing a loading spinner over already-
  /// visible content (`RefreshIndicator`/realtime events already communicate
  /// "updating" on their own) - converts a failure into `AsyncError` (so
  /// `AsyncValueView`'s retry button appears) rather than swallowing it.
  Future<void> refresh() async {
    try {
      final boardState = await _fetchBoard();
      state = AsyncData(boardState);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  String _requireActorName() {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) throw StateError('Must be signed in');
    return user.fullName;
  }

  String _requireActorId() {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) throw StateError('Must be signed in');
    return user.id;
  }

  // ─── Lists (owner-only) ─────────────────────────────────────────────────

  Future<void> createList(String name) async {
    final actorId = _requireActorId();
    final actorName = _requireActorName();
    final authNotifier = ref.read(authControllerProvider.notifier);
    final listRepo = ref.read(listRepositoryProvider);
    final activityRepo = ref.read(activityRepositoryProvider);
    final position = state.valueOrNull?.nextListPosition() ?? 0;

    await authNotifier.callAuthorized((token) async {
      await listRepo.create(
        token: token,
        boardId: EnvConfig.boardId,
        name: name,
        position: position,
      );
      await activityRepo.log(
        token: token,
        boardId: EnvConfig.boardId,
        actorId: actorId,
        actorName: actorName,
        action: ActivityAction.createdList,
        toList: name,
      );
    });
    await refresh();
  }

  Future<void> renameList({
    required BoardList list,
    required String newName,
  }) async {
    final actorId = _requireActorId();
    final actorName = _requireActorName();
    final authNotifier = ref.read(authControllerProvider.notifier);
    final listRepo = ref.read(listRepositoryProvider);
    final activityRepo = ref.read(activityRepositoryProvider);

    await authNotifier.callAuthorized((token) async {
      await listRepo.rename(token: token, listId: list.id, newName: newName);
      await activityRepo.log(
        token: token,
        boardId: EnvConfig.boardId,
        actorId: actorId,
        actorName: actorName,
        action: ActivityAction.renamedList,
        fromList: list.name,
        toList: newName,
      );
    });
    await refresh();
  }

  Future<void> reorderList({
    required BoardList list,
    required BoardList neighbor,
  }) async {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final listRepo = ref.read(listRepositoryProvider);
    await authNotifier.callAuthorized(
      (token) => listRepo.reorder(token: token, list: list, neighbor: neighbor),
    );
    await refresh();
  }

  /// Deletes a column and cascades to every card inside it - a list's
  /// cards have nowhere else to live once the column is gone.
  Future<void> deleteList(BoardList list) async {
    final actorId = _requireActorId();
    final actorName = _requireActorName();
    final authNotifier = ref.read(authControllerProvider.notifier);
    final listRepo = ref.read(listRepositoryProvider);
    final cardRepo = ref.read(cardRepositoryProvider);
    final activityRepo = ref.read(activityRepositoryProvider);
    final cardsInList =
        state.valueOrNull?.cardsByListId[list.id] ?? const <BoardCard>[];

    await authNotifier.callAuthorized((token) async {
      await Future.wait(
        cardsInList.map(
          (card) => cardRepo.delete(token: token, cardId: card.id),
        ),
      );
      await listRepo.delete(token: token, listId: list.id);
      await activityRepo.log(
        token: token,
        boardId: EnvConfig.boardId,
        actorId: actorId,
        actorName: actorName,
        action: ActivityAction.deletedList,
        fromList: list.name,
      );
    });
    await refresh();
  }

  // ─── Cards (owner/member) ───────────────────────────────────────────────

  Future<void> createCard({
    required String listId,
    required String listName,
    required String title,
    String? description,
    String? assigneeName,
  }) async {
    final actorId = _requireActorId();
    final actorName = _requireActorName();
    final authNotifier = ref.read(authControllerProvider.notifier);
    final cardRepo = ref.read(cardRepositoryProvider);
    final activityRepo = ref.read(activityRepositoryProvider);
    final position = state.valueOrNull?.nextCardPosition(listId) ?? 0;
    final assignee = _resolveAssignee(assigneeName);

    await authNotifier.callAuthorized((token) async {
      await cardRepo.create(
        token: token,
        boardId: EnvConfig.boardId,
        listId: listId,
        title: title,
        description: description,
        assigneeId: assignee?.id,
        assigneeName: assignee?.name,
        createdById: actorId,
        createdByName: actorName,
        position: position,
      );
      await activityRepo.log(
        token: token,
        boardId: EnvConfig.boardId,
        actorId: actorId,
        actorName: actorName,
        action: ActivityAction.createdCard,
        cardTitle: title,
        toList: listName,
      );
    });
    await refresh();
  }

  Future<void> updateCard({
    required BoardCard card,
    required String title,
    String? description,
    String? assigneeName,
  }) async {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final cardRepo = ref.read(cardRepositoryProvider);
    final assignee = _resolveAssignee(assigneeName);

    await authNotifier.callAuthorized(
      (token) => cardRepo.update(
        token: token,
        cardId: card.id,
        title: title,
        description: description,
        assigneeId: assignee?.id,
        assigneeName: assignee?.name,
      ),
    );
    await refresh();
  }

  Future<void> deleteCard(BoardCard card, String listName) async {
    final actorId = _requireActorId();
    final actorName = _requireActorName();
    final authNotifier = ref.read(authControllerProvider.notifier);
    final cardRepo = ref.read(cardRepositoryProvider);
    final activityRepo = ref.read(activityRepositoryProvider);

    await authNotifier.callAuthorized((token) async {
      await cardRepo.delete(token: token, cardId: card.id);
      await activityRepo.log(
        token: token,
        boardId: EnvConfig.boardId,
        actorId: actorId,
        actorName: actorName,
        action: ActivityAction.deletedCard,
        cardTitle: card.title,
        fromList: listName,
      );
    });
    await refresh();
  }

  /// Moves a card to a different column, appended to the end of it. Every
  /// move writes both `listId` and `position` and appends a `moved`
  /// activity entry, per `plan/build-plan.md`.
  Future<void> moveCardToList({
    required BoardCard card,
    required String fromListName,
    required BoardList toList,
  }) async {
    final actorId = _requireActorId();
    final actorName = _requireActorName();
    final authNotifier = ref.read(authControllerProvider.notifier);
    final cardRepo = ref.read(cardRepositoryProvider);
    final activityRepo = ref.read(activityRepositoryProvider);
    final position = state.valueOrNull?.nextCardPosition(toList.id) ?? 0;

    await authNotifier.callAuthorized((token) async {
      await cardRepo.moveToList(
        token: token,
        cardId: card.id,
        toListId: toList.id,
        newPosition: position,
      );
      await activityRepo.log(
        token: token,
        boardId: EnvConfig.boardId,
        actorId: actorId,
        actorName: actorName,
        action: ActivityAction.moved,
        cardTitle: card.title,
        fromList: fromListName,
        toList: toList.name,
      );
    });
    await refresh();
  }

  /// Reorders a card up/down within its own column by swapping `position`
  /// with the adjacent card. Still logs a `moved` activity entry
  /// (`fromList == toList`) per `plan/build-plan.md`'s "every move…appends
  /// an activity entry" rule.
  Future<void> reorderCardInList({
    required BoardCard card,
    required BoardCard neighbor,
    required String listName,
  }) async {
    final actorId = _requireActorId();
    final actorName = _requireActorName();
    final authNotifier = ref.read(authControllerProvider.notifier);
    final cardRepo = ref.read(cardRepositoryProvider);
    final activityRepo = ref.read(activityRepositoryProvider);

    await authNotifier.callAuthorized((token) async {
      await cardRepo.reorderInList(token: token, card: card, neighbor: neighbor);
      await activityRepo.log(
        token: token,
        boardId: EnvConfig.boardId,
        actorId: actorId,
        actorName: actorName,
        action: ActivityAction.moved,
        cardTitle: card.title,
        fromList: listName,
        toList: listName,
      );
    });
    await refresh();
  }

  ({String id, String name})? _resolveAssignee(String? assigneeName) {
    final trimmed = assigneeName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return (id: pseudoObjectId(trimmed), name: trimmed);
  }

  // ─── Realtime ────────────────────────────────────────────────────────────

  void _setupRealtime() {
    final socket = ref.read(mudbaseSocketServiceProvider);

    void trySubscribe() {
      if (!socket.connected) return;
      for (final collectionId in _collectionIds) {
        socket.emit('subscribe:collection', {
          'projectId': EnvConfig.mudbaseProjectId,
          'collectionId': collectionId,
        });
      }
    }

    trySubscribe();
    _unsubscribeStatus = socket.onStatus((status) {
      if (status == SocketConnectionStatus.connected) trySubscribe();
    });

    void onRowEvent(Map<String, dynamic> event) {
      final collectionId = event['collectionId'] as String?;
      if (collectionId == null || !_collectionIds.contains(collectionId)) {
        return;
      }
      unawaited(refresh());
    }

    _unsubscribeCreate = socket.on('db:create', onRowEvent);
    _unsubscribeUpdate = socket.on('db:update', onRowEvent);
    _unsubscribeDelete = socket.on('db:delete', onRowEvent);
  }

  void _teardownRealtime() {
    final socket = ref.read(mudbaseSocketServiceProvider);
    for (final collectionId in _collectionIds) {
      socket.emit('unsubscribe:collection', {'collectionId': collectionId});
    }
    _unsubscribeCreate?.call();
    _unsubscribeUpdate?.call();
    _unsubscribeDelete?.call();
    _unsubscribeStatus?.call();
  }
}

final boardControllerProvider =
    AsyncNotifierProvider<BoardController, BoardState>(BoardController.new);
