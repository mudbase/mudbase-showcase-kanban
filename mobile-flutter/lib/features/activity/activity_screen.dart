import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/activity_entry.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import 'activity_controller.dart';
import 'widgets/activity_tile.dart';

/// Full reverse-chronological activity feed, updating live. Mirrors the
/// reference web app's `/activity` page + `ActivityFeed.tsx`.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(activityFeedControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(activityFeedControllerProvider.notifier).refresh(),
        child: AsyncValueView<List<ActivityEntry>>(
          value: feedState,
          onRetry: () => ref.invalidate(activityFeedControllerProvider),
          data: (context, entries) {
            if (entries.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.history,
                    message:
                        'No activity yet — actions on the board will show up here.',
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) => ActivityTile(entry: entries[index]),
            );
          },
        ),
      ),
    );
  }
}
