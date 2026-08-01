import 'package:flutter/material.dart';

import '../../../core/activity_text.dart';
import '../../../core/formatters.dart';
import '../../../models/activity_entry.dart';
import '../../../widgets/initials_avatar.dart';

/// One row in the activity feed - actor avatar, a plain-English description
/// of the action, relative timestamp, and an action-specific icon. Mirrors
/// the reference web app's `ActivityItem.tsx`.
class ActivityTile extends StatelessWidget {
  const ActivityTile({required this.entry, super.key});

  final ActivityEntry entry;

  static const Map<ActivityAction, IconData> _iconByAction = {
    ActivityAction.createdCard: Icons.add_circle_outline,
    ActivityAction.moved: Icons.swap_horiz,
    ActivityAction.deletedCard: Icons.delete_outline,
    ActivityAction.createdList: Icons.playlist_add,
    ActivityAction.renamedList: Icons.edit_outlined,
    ActivityAction.deletedList: Icons.playlist_remove,
    ActivityAction.unknown: Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialsAvatar(name: entry.actorName, radius: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(describeActivity(entry)),
              const SizedBox(height: 2),
              Text(
                formatRelativeTime(entry.createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Icon(
          _iconByAction[entry.action] ?? Icons.info_outline,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
