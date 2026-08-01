import 'package:mudbase_showcase_kanban/models/mudbase_user.dart';
import 'package:test/test.dart';

void main() {
  group('MudbaseUser.fromJson', () {
    test('parses every field including customRole', () {
      final user = MudbaseUser.fromJson({
        'id': 'user_1',
        'email': 'kanban.owner.demo@gmail.com',
        'firstName': 'Kanban',
        'lastName': 'Owner',
        'customRole': 'owner',
        'emailVerified': true,
      });

      expect(user.id, 'user_1');
      expect(user.email, 'kanban.owner.demo@gmail.com');
      expect(user.firstName, 'Kanban');
      expect(user.lastName, 'Owner');
      expect(user.customRole, 'owner');
      expect(user.emailVerified, isTrue);
    });

    test('falls back to _id when id is absent', () {
      final user = MudbaseUser.fromJson({'_id': 'user_2'});
      expect(user.id, 'user_2');
    });

    test('customRole is null when absent (no role assigned yet)', () {
      final user = MudbaseUser.fromJson({'id': 'user_3'});
      expect(user.customRole, isNull);
    });
  });

  group('MudbaseUser.fullName', () {
    test('joins first and last name', () {
      const user = MudbaseUser(
        id: '1',
        email: 'a@b.com',
        firstName: 'Mia',
        lastName: 'Member',
        customRole: 'member',
        emailVerified: true,
      );
      expect(user.fullName, 'Mia Member');
    });

    test('falls back to email when both names are blank', () {
      const user = MudbaseUser(
        id: '1',
        email: 'vic.viewer@example.com',
        firstName: '',
        lastName: '',
        customRole: 'viewer',
        emailVerified: true,
      );
      expect(user.fullName, 'vic.viewer@example.com');
    });
  });
}
