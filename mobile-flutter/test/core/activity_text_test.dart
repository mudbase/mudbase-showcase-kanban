import 'package:mudbase_showcase_kanban/core/activity_text.dart';
import 'package:mudbase_showcase_kanban/models/activity_entry.dart';
import 'package:test/test.dart';

void main() {
  ActivityEntry entry({
    required ActivityAction action,
    String actorName = 'Kanban Owner',
    String? cardTitle,
    String? fromList,
    String? toList,
  }) {
    return ActivityEntry(
      id: 'a1',
      boardId: 'b1',
      actorId: 'u1',
      actorName: actorName,
      action: action,
      cardTitle: cardTitle,
      fromList: fromList,
      toList: toList,
      createdAt: DateTime.now(),
    );
  }

  group('describeActivity', () {
    test('created_card names the card and destination list', () {
      final text = describeActivity(
        entry(
          action: ActivityAction.createdCard,
          cardTitle: 'Write onboarding docs',
          toList: 'To Do',
        ),
      );
      expect(
        text,
        'Kanban Owner created card "Write onboarding docs" in To Do',
      );
    });

    test('moved across two different lists names both', () {
      final text = describeActivity(
        entry(
          action: ActivityAction.moved,
          cardTitle: 'Fix login bug',
          fromList: 'To Do',
          toList: 'In Progress',
        ),
      );
      expect(
        text,
        'Kanban Owner moved "Fix login bug" from To Do to In Progress',
      );
    });

    test('moved within the same list reads as a reorder', () {
      final text = describeActivity(
        entry(
          action: ActivityAction.moved,
          cardTitle: 'Fix login bug',
          fromList: 'To Do',
          toList: 'To Do',
        ),
      );
      expect(text, 'Kanban Owner reordered "Fix login bug" within To Do');
    });

    test('deleted_card names the card and its former list', () {
      final text = describeActivity(
        entry(
          action: ActivityAction.deletedCard,
          cardTitle: 'Old task',
          fromList: 'Done',
        ),
      );
      expect(text, 'Kanban Owner deleted card "Old task" from Done');
    });

    test('created_list names the new list', () {
      final text = describeActivity(
        entry(action: ActivityAction.createdList, toList: 'Blocked'),
      );
      expect(text, 'Kanban Owner created list "Blocked"');
    });

    test('renamed_list names both the old and new name', () {
      final text = describeActivity(
        entry(
          action: ActivityAction.renamedList,
          fromList: 'Doing',
          toList: 'In Progress',
        ),
      );
      expect(text, 'Kanban Owner renamed list "Doing" to "In Progress"');
    });

    test('deleted_list names the removed list', () {
      final text = describeActivity(
        entry(action: ActivityAction.deletedList, fromList: 'Backlog'),
      );
      expect(text, 'Kanban Owner deleted list "Backlog"');
    });

    test('falls back to "Someone" when actorName is blank', () {
      final text = describeActivity(
        entry(
          action: ActivityAction.createdList,
          actorName: '',
          toList: 'Blocked',
        ),
      );
      expect(text, 'Someone created list "Blocked"');
    });

    test('unknown action produces a generic sentence rather than throwing', () {
      final text = describeActivity(entry(action: ActivityAction.unknown));
      expect(text, 'Kanban Owner did something on the board');
    });
  });
}
