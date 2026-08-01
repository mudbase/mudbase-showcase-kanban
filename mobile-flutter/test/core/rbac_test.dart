import 'package:mudbase_showcase_kanban/core/rbac.dart';
import 'package:test/test.dart';

void main() {
  group('isAppRole', () {
    test('accepts the three known role slugs', () {
      expect(isAppRole('owner'), isTrue);
      expect(isAppRole('member'), isTrue);
      expect(isAppRole('viewer'), isTrue);
    });

    test('rejects anything else, including null', () {
      expect(isAppRole('admin'), isFalse);
      expect(isAppRole(''), isFalse);
      expect(isAppRole(null), isFalse);
    });
  });

  group('canManageLists', () {
    test('only the owner can manage lists', () {
      expect(canManageLists(AppRole.owner), isTrue);
      expect(canManageLists(AppRole.member), isFalse);
      expect(canManageLists(AppRole.viewer), isFalse);
      expect(canManageLists(null), isFalse);
    });
  });

  group('canManageCards', () {
    test('owner and member can manage cards, viewer cannot', () {
      expect(canManageCards(AppRole.owner), isTrue);
      expect(canManageCards(AppRole.member), isTrue);
      expect(canManageCards(AppRole.viewer), isFalse);
      expect(canManageCards(null), isFalse);
    });
  });

  group('isReadOnly', () {
    test('viewer and no role are read-only; owner/member are not', () {
      expect(isReadOnly(AppRole.viewer), isTrue);
      expect(isReadOnly(null), isTrue);
      expect(isReadOnly(AppRole.owner), isFalse);
      expect(isReadOnly(AppRole.member), isFalse);
    });
  });

  group('roleLabel', () {
    test('produces a human-readable label for every known role', () {
      expect(roleLabel(AppRole.owner), 'Owner');
      expect(roleLabel(AppRole.member), 'Member');
      expect(roleLabel(AppRole.viewer), 'Viewer');
    });

    test('falls back to "Unknown" for anything else', () {
      expect(roleLabel(null), 'Unknown');
      expect(roleLabel('admin'), 'Unknown');
    });
  });
}
