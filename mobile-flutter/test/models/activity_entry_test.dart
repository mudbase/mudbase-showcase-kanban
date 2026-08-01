import 'package:mudbase_showcase_kanban/models/activity_entry.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> baseJson() => {
    '_id': 'activity_1',
    'boardId': '6a6d4072d07caabbbdfc5d3c',
    'actorId': 'user_1',
    'actorName': 'Kanban Owner',
    'action': 'created_card',
    'cardTitle': 'Write onboarding docs',
    'toList': 'To Do',
    'createdAt': '2026-08-01T00:00:00.000Z',
    'updatedAt': '2026-08-01T00:00:00.000Z',
  };

  group('ActivityAction.fromWire', () {
    test('maps every known wire value to its enum case', () {
      expect(ActivityAction.fromWire('created_card'), ActivityAction.createdCard);
      expect(ActivityAction.fromWire('moved'), ActivityAction.moved);
      expect(ActivityAction.fromWire('deleted_card'), ActivityAction.deletedCard);
      expect(ActivityAction.fromWire('created_list'), ActivityAction.createdList);
      expect(ActivityAction.fromWire('renamed_list'), ActivityAction.renamedList);
      expect(ActivityAction.fromWire('deleted_list'), ActivityAction.deletedList);
    });

    test('falls back to unknown for an unrecognized or missing value', () {
      expect(ActivityAction.fromWire('something_new'), ActivityAction.unknown);
      expect(ActivityAction.fromWire(null), ActivityAction.unknown);
    });

    test('wireValue round-trips every known action', () {
      for (final action in ActivityAction.values) {
        if (action == ActivityAction.unknown) continue;
        expect(ActivityAction.fromWire(action.wireValue), action);
      }
    });
  });

  group('ActivityEntry.fromJson', () {
    test('parses every field from a well-formed created_card row', () {
      final entry = ActivityEntry.fromJson(baseJson());

      expect(entry.id, 'activity_1');
      expect(entry.boardId, '6a6d4072d07caabbbdfc5d3c');
      expect(entry.actorId, 'user_1');
      expect(entry.actorName, 'Kanban Owner');
      expect(entry.action, ActivityAction.createdCard);
      expect(entry.cardTitle, 'Write onboarding docs');
      expect(entry.toList, 'To Do');
      expect(entry.fromList, isNull);
      expect(entry.createdAt, DateTime.parse('2026-08-01T00:00:00.000Z'));
    });

    test('parses a moved row with both fromList and toList', () {
      final json = baseJson()
        ..['action'] = 'moved'
        ..['fromList'] = 'To Do'
        ..['toList'] = 'In Progress';
      final entry = ActivityEntry.fromJson(json);
      expect(entry.action, ActivityAction.moved);
      expect(entry.fromList, 'To Do');
      expect(entry.toList, 'In Progress');
    });

    test(
      'falls back to "now" for an unparseable createdAt rather than throwing',
      () {
        final json = baseJson()..['createdAt'] = 'not-a-date';
        final before = DateTime.now();
        final entry = ActivityEntry.fromJson(json);
        expect(
          entry.createdAt.isAfter(before.subtract(const Duration(seconds: 5))),
          isTrue,
        );
      },
    );
  });
}
