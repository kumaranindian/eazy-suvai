import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

Restaurant restaurant(Map<String, dynamic> extra) => Restaurant.fromMap('r1', {
  'name': 'Spice Garden',
  'country': 'IN',
  'currency': 'INR',
  'timezone': 'Asia/Kolkata',
  ...extra,
});

void main() {
  group('Restaurant.hasUnpublishedChanges (M06)', () {
    final at = DateTime.utc(2026, 11, 14, 10);

    test('everything is unpublished before the first publish', () {
      expect(restaurant({}).hasUnpublishedChanges, isTrue);
    });

    test('compares draftUpdatedAt with publishedDraftAt', () {
      final base = {
        'publishedVersion': 3,
        'publishedDraftAt': Timestamp.fromDate(at),
      };
      expect(
        restaurant({
          ...base,
          'draftUpdatedAt': Timestamp.fromDate(at),
        }).hasUnpublishedChanges,
        isFalse,
      );
      expect(
        restaurant({
          ...base,
          'draftUpdatedAt': Timestamp.fromDate(
            at.subtract(const Duration(minutes: 1)),
          ),
        }).hasUnpublishedChanges,
        isFalse,
      );
      expect(
        restaurant({
          ...base,
          'draftUpdatedAt': Timestamp.fromDate(
            at.add(const Duration(milliseconds: 1)),
          ),
        }).hasUnpublishedChanges,
        isTrue,
      );
    });

    test(
      'a rollback that kept the draft (publishedDraftAt null) is unpublished',
      () {
        expect(
          restaurant({
            'publishedVersion': 4,
            'publishedDraftAt': null,
          }).hasUnpublishedChanges,
          isTrue,
        );
      },
    );
  });

  group('MenuVersionEntry', () {
    test('reads versionHistory newest first and skips bad entries', () {
      final r = restaurant({
        'versionHistory': [
          {
            'n': 1,
            'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 13)),
            'publishedBy': 'u1',
            'summary': {'added': 5, 'changed': 0, 'removed': 0},
          },
          'junk',
          {
            'n': 2,
            'rollbackOf': 1,
            'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 14)),
            'publishedBy': 'u1',
            'summary': {
              'added': 0,
              'changed': 2,
              'removed': 1,
              'themeChanged': true,
            },
          },
        ],
      });
      final h = r.versionHistory;
      expect(h.map((v) => v.n), [2, 1]);
      expect(h.first.isRollback, isTrue);
      expect(h.first.rollbackOf, 1);
      expect(h.first.changed, 2);
      expect(h.first.removed, 1);
      expect(h.first.themeChanged, isTrue);
      expect(h.last.added, 5);
      expect(h.last.isRollback, isFalse);
      expect(h.last.publishedAt.toUtc(), DateTime.utc(2026, 11, 13));
    });

    test('missing history is empty', () {
      expect(restaurant({}).versionHistory, isEmpty);
      expect(MenuVersionEntry.listFrom('x'), isEmpty);
    });
  });
}
