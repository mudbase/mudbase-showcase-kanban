import 'package:mudbase_showcase_kanban/core/formatters.dart';
import 'package:test/test.dart';

void main() {
  group('formatRelativeTime', () {
    test('reports a timestamp under 5 seconds ago as "just now"', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 2))),
        'just now',
      );
    });

    test('reports seconds ago between 5s and 60s', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 30))),
        '30s',
      );
    });

    test('reports minutes ago', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5))),
        '5m',
      );
    });

    test('reports hours ago', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3))),
        '3h',
      );
    });

    test('reports days ago for anything under a week', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 4))),
        '4d',
      );
    });

    test('falls back to a medium date once older than a week', () {
      final now = DateTime.now();
      final eightDaysAgo = now.subtract(const Duration(days: 8));
      final formatted = formatRelativeTime(eightDaysAgo);
      expect(formatted, isNot(contains('d')));
      expect(formatted.length, greaterThan(4));
    });
  });

  group('initials', () {
    test('takes the first letter of the first and last word', () {
      expect(initials('Ben Chen'), 'BC');
    });

    test('handles a single-word name', () {
      expect(initials('Cher'), 'C');
    });

    test('collapses extra internal whitespace', () {
      expect(initials('  Mia   Member  '), 'MM');
    });

    test('returns "?" for an empty or whitespace-only name', () {
      expect(initials(''), '?');
      expect(initials('   '), '?');
    });
  });

  group('pseudoObjectId', () {
    test('always returns exactly 24 lowercase hex characters', () {
      final id = pseudoObjectId('Ben Chen');
      expect(id.length, 24);
      expect(RegExp(r'^[0-9a-f]{24}$').hasMatch(id), isTrue);
    });

    test('is deterministic for the same name', () {
      expect(pseudoObjectId('Ben Chen'), pseudoObjectId('Ben Chen'));
    });

    test('is case- and whitespace-insensitive, matching the web app', () {
      expect(pseudoObjectId('Ben Chen'), pseudoObjectId('  ben chen  '));
      expect(pseudoObjectId('BEN CHEN'), pseudoObjectId('ben chen'));
    });

    test('produces different ids for different names', () {
      expect(pseudoObjectId('Ben Chen'), isNot(pseudoObjectId('Mia Member')));
    });
  });
}
