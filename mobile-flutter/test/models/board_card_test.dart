import 'package:mudbase_showcase_kanban/models/board_card.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> baseJson() => {
    '_id': 'card_1',
    'boardId': '6a6d4072d07caabbbdfc5d3c',
    'listId': 'list_1',
    'title': 'Write onboarding docs',
    'description': 'Cover the setup steps',
    'position': 0,
    'assigneeId': '6d69612d626368656e00000',
    'assigneeName': 'Ben Chen',
    'createdById': 'user_1',
    'createdByName': 'Kanban Owner',
    'createdAt': '2026-08-01T00:00:00.000Z',
    'updatedAt': '2026-08-01T00:00:00.000Z',
  };

  group('BoardCard.fromJson', () {
    test('parses every field from a well-formed document', () {
      final card = BoardCard.fromJson(baseJson());

      expect(card.id, 'card_1');
      expect(card.boardId, '6a6d4072d07caabbbdfc5d3c');
      expect(card.listId, 'list_1');
      expect(card.title, 'Write onboarding docs');
      expect(card.description, 'Cover the setup steps');
      expect(card.position, 0);
      expect(card.assigneeId, '6d69612d626368656e00000');
      expect(card.assigneeName, 'Ben Chen');
      expect(card.createdById, 'user_1');
      expect(card.createdByName, 'Kanban Owner');
    });

    test('treats a missing description as null (no description set)', () {
      final json = baseJson()..remove('description');
      final card = BoardCard.fromJson(json);
      expect(card.description, isNull);
    });

    test(
      'treats a missing assigneeId/assigneeName as null (never assigned)',
      () {
        final json = baseJson()
          ..remove('assigneeId')
          ..remove('assigneeName');
        final card = BoardCard.fromJson(json);
        expect(card.assigneeId, isNull);
        expect(card.assigneeName, isNull);
      },
    );

    test(
      'treats an explicit JSON null assigneeId/assigneeName the same as '
      'missing (an explicitly-cleared assignee)',
      () {
        final json = baseJson()
          ..['assigneeId'] = null
          ..['assigneeName'] = null;
        final card = BoardCard.fromJson(json);
        expect(card.assigneeId, isNull);
        expect(card.assigneeName, isNull);
      },
    );

    test('defaults position to 0 when absent', () {
      final json = baseJson()..remove('position');
      final card = BoardCard.fromJson(json);
      expect(card.position, 0);
    });
  });
}
