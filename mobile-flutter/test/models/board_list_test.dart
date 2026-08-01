import 'package:mudbase_showcase_kanban/models/board_list.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> baseJson() => {
    '_id': 'list_1',
    'boardId': '6a6d4072d07caabbbdfc5d3c',
    'name': 'To Do',
    'position': 0,
    'createdAt': '2026-08-01T00:00:00.000Z',
    'updatedAt': '2026-08-01T00:00:00.000Z',
  };

  group('BoardList.fromJson', () {
    test('parses every field from a well-formed document', () {
      final list = BoardList.fromJson(baseJson());

      expect(list.id, 'list_1');
      expect(list.boardId, '6a6d4072d07caabbbdfc5d3c');
      expect(list.name, 'To Do');
      expect(list.position, 0);
    });

    test('defaults position to 0 when absent', () {
      final json = baseJson()..remove('position');
      final list = BoardList.fromJson(json);
      expect(list.position, 0);
    });

    test('accepts a double-typed position from JSON numbers', () {
      final json = baseJson()..['position'] = 2.0;
      final list = BoardList.fromJson(json);
      expect(list.position, 2);
    });

    test('defaults name to an empty string when missing', () {
      final json = baseJson()..remove('name');
      final list = BoardList.fromJson(json);
      expect(list.name, '');
    });
  });
}
