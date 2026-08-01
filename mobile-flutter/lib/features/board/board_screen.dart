import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rbac.dart';
import '../../models/board_card.dart';
import '../../models/board_list.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/role_badge.dart';
import '../auth/auth_controller.dart';
import 'board_controller.dart';
import 'widgets/add_list_sheet.dart';
import 'widgets/list_column.dart';

/// The board: header (title, role badge, sign-out, read-only notice for
/// viewers), a horizontally scrollable row of [ListColumn]s, and an
/// owner-only floating action button to add a list. Mirrors the reference
/// web app's `page.tsx` + `BoardView.tsx`.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardState = ref.watch(boardControllerProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;
    final role = user?.customRole;
    final manageLists = canManageLists(role);
    final manageCards = canManageCards(role);
    final readOnly = isReadOnly(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Board'),
        actions: [
          if (role != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: RoleBadge(role: role)),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (readOnly) _ReadOnlyBanner(roleLabel: roleLabel(role)),
          Expanded(
            child: AsyncValueView<BoardState>(
              value: boardState,
              onRetry: () => ref.invalidate(boardControllerProvider),
              data: (context, state) => _BoardBody(
                state: state,
                manageLists: manageLists,
                manageCards: manageCards,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: manageLists
          ? FloatingActionButton.extended(
              onPressed: () => showAddListSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add list'),
            )
          : null,
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner({required this.roleLabel});

  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        "Read-only — you're signed in as $roleLabel",
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _BoardBody extends StatelessWidget {
  const _BoardBody({
    required this.state,
    required this.manageLists,
    required this.manageCards,
  });

  final BoardState state;
  final bool manageLists;
  final bool manageCards;

  @override
  Widget build(BuildContext context) {
    final lists = state.sortedLists;
    final cardsByListId = state.cardsByListId;

    if (lists.isEmpty) {
      return const EmptyState(
        icon: Icons.view_column_outlined,
        message: 'The board has no lists yet.',
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: lists.length,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final list = lists[index];
        final cardsInList = cardsByListId[list.id] ?? const <BoardCard>[];
        final otherLists = <BoardList>[
          for (final other in lists)
            if (other.id != list.id) other,
        ];
        return ListColumn(
          list: list,
          cards: cardsInList,
          otherLists: otherLists,
          prevList: index > 0 ? lists[index - 1] : null,
          nextList: index < lists.length - 1 ? lists[index + 1] : null,
          canManageLists: manageLists,
          canManageCards: manageCards,
        );
      },
    );
  }
}
