import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env_config.dart';
import '../../core/mudbase_socket_service.dart';
import '../../core/service_providers.dart';
import '../../data/repository_providers.dart';
import '../../models/activity_entry.dart';
import '../auth/auth_controller.dart';

/// Owns the reverse-chronological activity feed + its own realtime
/// subscription (the `activity` collection only - separate from
/// `BoardController`'s `lists`/`cards` subscription, since the two screens
/// are independent and each only needs to stay live for what it renders).
/// Mirrors the reference web app's `useActivityFeed` + `useBoardLive`.
class ActivityFeedController extends AsyncNotifier<List<ActivityEntry>> {
  void Function()? _unsubscribeCreate;
  void Function()? _unsubscribeStatus;

  @override
  Future<List<ActivityEntry>> build() async {
    ref.onDispose(_teardownRealtime);
    final entries = await _fetch();
    _setupRealtime();
    return entries;
  }

  Future<List<ActivityEntry>> _fetch() async {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final repository = ref.read(activityRepositoryProvider);
    return authNotifier.callAuthorized(
      (token) =>
          repository.listForBoard(token: token, boardId: EnvConfig.boardId),
    );
  }

  Future<void> refresh() async {
    try {
      final entries = await _fetch();
      state = AsyncData(entries);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void _setupRealtime() {
    final socket = ref.read(mudbaseSocketServiceProvider);
    const collectionId = EnvConfig.activityCollectionId;

    void trySubscribe() {
      if (!socket.connected) return;
      socket.emit('subscribe:collection', {
        'projectId': EnvConfig.mudbaseProjectId,
        'collectionId': collectionId,
      });
    }

    trySubscribe();
    _unsubscribeStatus = socket.onStatus((status) {
      if (status == SocketConnectionStatus.connected) trySubscribe();
    });

    _unsubscribeCreate = socket.on('db:create', (event) {
      if (event['collectionId'] != collectionId) return;
      unawaited(refresh());
    });
  }

  void _teardownRealtime() {
    final socket = ref.read(mudbaseSocketServiceProvider);
    socket.emit('unsubscribe:collection', {
      'collectionId': EnvConfig.activityCollectionId,
    });
    _unsubscribeCreate?.call();
    _unsubscribeStatus?.call();
  }
}

final activityFeedControllerProvider =
    AsyncNotifierProvider<ActivityFeedController, List<ActivityEntry>>(
      ActivityFeedController.new,
    );
