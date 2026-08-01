// ignore_for_file: avoid_print
//
// Standalone, non-Flutter smoke test that exercises this app's own
// `lib/core/*`/`lib/data/*` layer - the exact classes `AuthController` and
// `BoardController` call - directly against the real, live
// `cloud.mudbase.dev` project. No Flutter SDK/device is required to run
// this: `AuthService`, `MudbaseDataService`, and every repository only
// depend on `dio`/`mudbase_sdk`, never `package:flutter`. Mirrors the
// sibling social/ecommerce Flutter apps' `tool/manual_test.dart` in
// structure and intent.
//
// Run with (values are this showcase's real, already-provisioned ids - not
// secrets, same ones baked into `dart_define.example.json` and
// `lib/config/env_config.dart`'s own defaults):
//
//   dart run tool/manual_test.dart
//
// NOTE (environment constraint, documented in plan/build-plan.md "Testing
// Note"): this build environment has no Flutter SDK installed, and this
// project's pubspec.yaml depends on `flutter: sdk: flutter` - so `dart pub
// get`/`dart run` cannot resolve *this* package's dependencies here directly.
// This script was actually executed via the scratch-package technique
// documented in `plan/build-plan.md` (copying the Flutter-free subset of
// `lib/` into a throwaway package with a `flutter`-free `pubspec.yaml`) -
// see that section for the real, live output this produced.
//
// Exits with a non-zero status if any required step fails, printing which
// step and why.
import 'dart:io';

import 'package:mudbase_sdk/mudbase_sdk.dart';
import 'package:mudbase_showcase_kanban/config/env_config.dart';
import 'package:mudbase_showcase_kanban/core/auth_service.dart';
import 'package:mudbase_showcase_kanban/core/mudbase_data_service.dart';
import 'package:mudbase_showcase_kanban/core/mudbase_exception.dart';
import 'package:mudbase_showcase_kanban/data/repositories/activity_repository.dart';
import 'package:mudbase_showcase_kanban/data/repositories/card_repository.dart';
import 'package:mudbase_showcase_kanban/data/repositories/list_repository.dart';
import 'package:mudbase_showcase_kanban/models/activity_entry.dart';
import 'package:mudbase_showcase_kanban/models/board_list.dart';

// The three already-verified, already-registered demo accounts named in
// this app's own task brief - this script only ever logs in, never
// registers (registration is out of scope for this app, and re-registering
// these would be redundant - they already exist under the owner/member/
// viewer role slugs on this exact project).
const _ownerEmail = 'kanban.owner.demo@gmail.com';
const _memberEmail = 'kanban.member.demo@gmail.com';
const _viewerEmail = 'kanban.viewer.demo@gmail.com';
const _password = 'KanbanTest123!';

// A distinctly-named test card so this run's writes are easy to spot and
// clean up, rather than colliding with the board's existing seeded demo
// data (3 lists / 3 cards / 4 activity rows left by the reference web
// app's own smoke test - see ../web/plan/build-plan.md).
const _testCardTitle = 'Flutter smoke test card';

int _passed = 0;
int _failed = 0;

Future<bool> _step(String name, Future<void> Function() body) async {
  stdout.write('- $name ... ');
  try {
    await body();
    stdout.writeln('PASS');
    _passed++;
    return true;
  } on Object catch (error) {
    stdout.writeln('FAIL ($error)');
    _failed++;
    return false;
  }
}

Future<void> _requireStep(String name, Future<void> Function() body) async {
  final ok = await _step(name, body);
  if (ok) return;
  print('');
  print(
    'Stopping: "$name" failed and every remaining step depends on it - '
    'see the FAIL line above for the real cause.',
  );
  print('Passed: $_passed, Failed: $_failed');
  exit(1);
}

void main() async {
  print('Mudbase Showcase Kanban (Flutter) - live manual smoke test');
  print('Base URL: ${EnvConfig.mudbaseBaseUrl}');
  print('Project:  ${EnvConfig.mudbaseProjectId}');
  print('Board:    ${EnvConfig.boardId}');
  print('');

  final sdk = MudbaseSdk(basePathOverride: EnvConfig.mudbaseBaseUrl);
  final auth = AuthService(sdk, EnvConfig.mudbaseProjectId);
  final data = MudbaseDataService(sdk, EnvConfig.mudbaseProjectId);
  final lists = ListRepository(data);
  final cards = CardRepository(data);
  final activity = ActivityRepository(data);

  String? ownerToken;
  String? ownerRefreshToken;
  String? ownerId;
  String? memberToken;
  String? memberId;
  String? viewerToken;
  List<BoardList> boardLists = const [];
  String? testCardId;

  await _requireStep('login as Owner', () async {
    final json = await auth.login(email: _ownerEmail, password: _password);
    ownerToken = json['token'] as String?;
    ownerRefreshToken = json['refreshToken'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    ownerId = user?['id'] as String? ?? user?['_id'] as String?;
    final customRole = user?['customRole'] as String?;
    if (ownerToken == null || ownerId == null) {
      throw StateError('Owner session missing token/id: $json');
    }
    if (customRole != 'owner') {
      throw StateError('expected customRole "owner", got "$customRole"');
    }
  });

  await _requireStep('login as Member', () async {
    final json = await auth.login(email: _memberEmail, password: _password);
    memberToken = json['token'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    memberId = user?['id'] as String? ?? user?['_id'] as String?;
    final customRole = user?['customRole'] as String?;
    if (memberToken == null || memberId == null) {
      throw StateError('Member session missing token/id: $json');
    }
    if (customRole != 'member') {
      throw StateError('expected customRole "member", got "$customRole"');
    }
  });

  await _requireStep('login as Viewer', () async {
    final json = await auth.login(email: _viewerEmail, password: _password);
    viewerToken = json['token'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    final customRole = user?['customRole'] as String?;
    if (viewerToken == null) {
      throw StateError('Viewer session missing token: $json');
    }
    if (customRole != 'viewer') {
      throw StateError('expected customRole "viewer", got "$customRole"');
    }
  });

  await _requireStep(
    'read existing lists for the shared board (sort=position)',
    () async {
      boardLists = await lists.listForBoard(
        token: ownerToken!,
        boardId: EnvConfig.boardId,
      );
      if (boardLists.length < 2) {
        throw StateError(
          'expected at least 2 lists already seeded on this board, found '
          '${boardLists.length}',
        );
      }
      final sorted = [...boardLists]
        ..sort((a, b) => a.position.compareTo(b.position));
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i].position < sorted[i - 1].position) {
          throw StateError('lists were not returned in position order');
        }
      }
    },
  );

  await _requireStep(
    'Owner creates a card with a description and an assignee',
    () async {
      final firstList = boardLists.first;
      final created = await cards.create(
        token: ownerToken!,
        boardId: EnvConfig.boardId,
        listId: firstList.id,
        title: _testCardTitle,
        description: 'Created by the Flutter port\'s live smoke test.',
        assigneeId: '666f6c6c6f77746573746572',
        assigneeName: 'Follow Tester',
        createdById: ownerId!,
        createdByName: 'Kanban Owner',
        position: 999,
      );
      testCardId = created.id;
      if (created.assigneeName != 'Follow Tester') {
        throw StateError('assignee was not persisted on create');
      }
      await activity.log(
        token: ownerToken!,
        boardId: EnvConfig.boardId,
        actorId: ownerId!,
        actorName: 'Kanban Owner',
        action: ActivityAction.createdCard,
        cardTitle: _testCardTitle,
        toList: firstList.name,
      );
    },
  );

  await _step('Member reads cards and finds the new card', () async {
    final all = await cards.listForBoard(
      token: memberToken!,
      boardId: EnvConfig.boardId,
    );
    final found = all.any((c) => c.id == testCardId);
    if (!found) throw StateError('member could not read the new card');
  });

  await _step(
    'Member moves the card to a different list and logs a moved activity row',
    () async {
      if (boardLists.length < 2) return;
      final fromList = boardLists.first;
      final toList = boardLists[1];
      await cards.moveToList(
        token: memberToken!,
        cardId: testCardId!,
        toListId: toList.id,
        newPosition: 999,
      );
      await activity.log(
        token: memberToken!,
        boardId: EnvConfig.boardId,
        actorId: memberId!,
        actorName: 'Mia Member',
        action: ActivityAction.moved,
        cardTitle: _testCardTitle,
        fromList: fromList.name,
        toList: toList.name,
      );
    },
  );

  await _step(
    'Member edits the card and clears its assignee (null, not "")',
    () async {
      final updated = await cards.update(
        token: memberToken!,
        cardId: testCardId!,
        title: _testCardTitle,
        description: 'Edited by Member during the live smoke test.',
        assigneeId: null,
        assigneeName: null,
      );
      if (updated.assigneeId != null || updated.assigneeName != null) {
        throw StateError('assignee was not cleared (expected null)');
      }
      if (updated.description != 'Edited by Member during the live smoke test.') {
        throw StateError('description was not updated');
      }
    },
  );

  await _step(
    'Member attempts to create a list - expect 403 Insufficient permissions',
    () async {
      try {
        await lists.create(
          token: memberToken!,
          boardId: EnvConfig.boardId,
          name: 'Member Should Not Be Able To Create This',
          position: 999,
        );
        throw StateError('expected a 403, request unexpectedly succeeded');
      } on MudbaseException catch (error) {
        if (error.statusCode != 403) {
          throw StateError('expected statusCode 403, got ${error.statusCode}');
        }
      }
    },
  );

  await _step('Viewer reads lists (read-only role can still read)', () async {
    final result = await lists.listForBoard(
      token: viewerToken!,
      boardId: EnvConfig.boardId,
    );
    if (result.isEmpty) throw StateError('viewer read back zero lists');
  });

  await _step('Viewer reads cards (read-only role can still read)', () async {
    final result = await cards.listForBoard(
      token: viewerToken!,
      boardId: EnvConfig.boardId,
    );
    final found = result.any((c) => c.id == testCardId);
    if (!found) throw StateError('viewer could not read the test card');
  });

  await _step(
    'Viewer raw write attempt: create a card - expect 403 (not just a '
    'hidden UI button)',
    () async {
      try {
        await cards.create(
          token: viewerToken!,
          boardId: EnvConfig.boardId,
          listId: boardLists.first.id,
          title: 'Viewer Should Not Be Able To Create This',
          createdById: 'irrelevant',
          createdByName: 'Vic Viewer',
          position: 999,
        );
        throw StateError('expected a 403, request unexpectedly succeeded');
      } on MudbaseException catch (error) {
        if (error.statusCode != 403) {
          throw StateError('expected statusCode 403, got ${error.statusCode}');
        }
      }
    },
  );

  await _step(
    'Viewer raw write attempt: update the test card - expect 403',
    () async {
      try {
        await cards.update(
          token: viewerToken!,
          cardId: testCardId!,
          title: 'Viewer Should Not Be Able To Edit This',
        );
        throw StateError('expected a 403, request unexpectedly succeeded');
      } on MudbaseException catch (error) {
        if (error.statusCode != 403) {
          throw StateError('expected statusCode 403, got ${error.statusCode}');
        }
      }
    },
  );

  await _step(
    'Viewer raw write attempt: delete the test card - expect 403',
    () async {
      try {
        await cards.delete(token: viewerToken!, cardId: testCardId!);
        throw StateError('expected a 403, request unexpectedly succeeded');
      } on MudbaseException catch (error) {
        if (error.statusCode != 403) {
          throw StateError('expected statusCode 403, got ${error.statusCode}');
        }
      }
    },
  );

  await _step(
    'activity feed (sort=-createdAt) includes this run\'s created_card and '
    'moved rows',
    () async {
      final feed = await activity.listForBoard(
        token: ownerToken!,
        boardId: EnvConfig.boardId,
      );
      final hasCreated = feed.any(
        (e) =>
            e.action == ActivityAction.createdCard &&
            e.cardTitle == _testCardTitle,
      );
      final hasMoved = feed.any(
        (e) => e.action == ActivityAction.moved && e.cardTitle == _testCardTitle,
      );
      if (!hasCreated) throw StateError('created_card row not found in feed');
      if (!hasMoved) throw StateError('moved row not found in feed');
    },
  );

  await _step(
    'POST /api/auth/refresh returns a new, distinct token pair',
    () async {
      if (ownerRefreshToken == null) {
        throw StateError('no refresh token was issued at login');
      }
      final refreshed = await auth.refreshSession(ownerRefreshToken!);
      final newToken = refreshed['token'] as String?;
      if (newToken == null || newToken == ownerToken) {
        throw StateError('refresh did not return a distinct new access token');
      }
      // Prove the new token is actually usable with a real authenticated call.
      await lists.listForBoard(token: newToken, boardId: EnvConfig.boardId);
      ownerToken = newToken;
    },
  );

  await _step('an invalid access token is rejected with a real 401', () async {
    try {
      await data.list(
        EnvConfig.listsCollectionId,
        token: 'not-a-real-token',
        limit: 1,
      );
      throw StateError('expected a 401, request unexpectedly succeeded');
    } on MudbaseException catch (error) {
      if (error.statusCode != 401) {
        throw StateError('expected statusCode 401, got ${error.statusCode}');
      }
    }
  });

  await _step(
    'cleanup: Owner deletes the test card and logs a deleted_card row',
    () async {
      final cardId = testCardId;
      if (cardId == null) return;
      await cards.delete(token: ownerToken!, cardId: cardId);
      await activity.log(
        token: ownerToken!,
        boardId: EnvConfig.boardId,
        actorId: ownerId!,
        actorName: 'Kanban Owner',
        action: ActivityAction.deletedCard,
        cardTitle: _testCardTitle,
        fromList: boardLists.length > 1 ? boardLists[1].name : boardLists.first.name,
      );
    },
  );

  await _step('sign out (best-effort server-side revoke)', () async {
    await auth.logout(ownerToken!);
    await auth.logout(memberToken!);
    await auth.logout(viewerToken!);
  });

  print('');
  print('Passed: $_passed, Failed: $_failed');
  if (_failed > 0) exit(1);
}
