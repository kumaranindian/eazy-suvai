import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/widgets.dart' show Locale;

void main() {
  group('OpeningHours (FR-011)', () {
    test('round-trips the stored form', () {
      final wire = {
        'mon': '07:00-11:00,12:00-15:00,18:00-23:30',
        'tue': '',
        'wed': '18:00-02:00',
        'thu': '00:00-00:00',
        'fri': '09:00-22:00',
        'sat': '09:00-22:00',
        'sun': '',
      };
      final h = OpeningHours.fromWire(wire)!;
      expect(h[Weekday.mon], hasLength(3));
      expect(h.isClosed(Weekday.tue), isTrue);
      expect(h[Weekday.wed].single.isOvernight, isTrue);
      expect(h[Weekday.thu].single.isAllDay, isTrue);
      expect(h.toWire(), wire);
      expect(h.isValid, isTrue);
    });

    test('missing days are closed; non-maps are null; junk slots dropped', () {
      expect(OpeningHours.fromWire(null), isNull);
      expect(OpeningHours.fromWire('x'), isNull);
      final h = OpeningHours.fromWire({'mon': '09:00-10:00,junk', 'tue': 5})!;
      expect(h[Weekday.mon], [const TimeSlot(540, 600)]);
      expect(h.isClosed(Weekday.tue), isTrue);
      expect(h.isClosed(Weekday.sun), isTrue);
    });

    test('validates a day', () {
      HoursIssue? check(String day) => OpeningHours.validateDay(
        OpeningHours.fromWire({'mon': day})![Weekday.mon],
      );
      expect(check('09:00-12:00,13:00-17:00,18:00-02:00'), isNull);
      expect(
        check('09:00-12:00,12:00-17:00'),
        isNull,
        reason: 'touching is fine',
      );
      expect(check('18:00-00:00'), isNull, reason: 'closing at midnight');
      expect(check('09:00-09:00'), HoursIssue.sameTime);
      expect(check('09:00-12:00,11:00-15:00'), HoursIssue.overlap);
      expect(check('13:00-15:00,09:00-12:00'), HoursIssue.overlap);
      expect(check('22:00-02:00,09:00-12:00'), HoursIssue.overnightNotLast);
      expect(check('00:00-00:00,09:00-12:00'), HoursIssue.overlap);
      expect(
        OpeningHours.validateDay(const [
          TimeSlot(60, 120),
          TimeSlot(180, 240),
          TimeSlot(300, 360),
          TimeSlot(420, 480),
        ]),
        HoursIssue.tooManySlots,
      );
    });

    test('template is every day 09:00–22:00', () {
      final t = OpeningHours.template();
      expect(t.toWire().values.toSet(), {'09:00-22:00'});
    });

    test('formatHhMm and parseHhMm', () {
      expect(formatHhMm(0), '00:00');
      expect(formatHhMm(23 * 60 + 59), '23:59');
      expect(parseHhMm('07:05'), 425);
      expect(parseHhMm('24:00'), isNull);
      expect(parseHhMm('7:05'), isNull);
    });
  });

  group('Restaurant.fromMap', () {
    test('reads the M01 document and the profile fields', () {
      final r = Restaurant.fromMap('rest_1', {
        'name': 'Spice Garden',
        'businessType': 'cafe',
        'country': 'IN',
        'currency': 'INR',
        'timezone': 'Asia/Kolkata',
        'contact': {
          'city': 'Chennai',
          'phone': '+914423456789',
          'social': {'instagram': 'https://instagram.com/sg', 'tiktok': 'x'},
        },
        'visibility': {'email': false, 'phone': true},
        'slug': 'spice-garden',
        'qrCode': 'ABCDEFGH',
        'counts': {'categories': 2, 'items': 9},
        'publishedVersion': 3,
        'pricesNeedReview': true,
        'setupCompletedAt': Timestamp.fromMillisecondsSinceEpoch(1000),
      });
      expect(r.businessType, BusinessType.cafe);
      expect(r.contact.city, 'Chennai');
      expect(r.contact.social, {
        SocialNetwork.instagram: 'https://instagram.com/sg',
      });
      expect(r.visibility.isShown(VisibleField.email), isFalse);
      expect(
        r.visibility.isShown(VisibleField.hours),
        isTrue,
        reason: 'missing = shown',
      );
      expect(r.categoryCount, 2);
      expect(r.itemCount, 9);
      expect(r.isPublished, isTrue);
      expect(r.pricesNeedReview, isTrue);
      expect(r.openingHours, isNull);
      expect(r.setupCompletedAt, isNotNull);
    });

    test('ContactInfo.toMap leaves out empty values', () {
      const c = ContactInfo(
        phone: '',
        email: ' a@b.co ',
        city: 'Chennai',
        social: {SocialNetwork.x: ''},
      );
      expect(c.toMap(), {'email': 'a@b.co', 'city': 'Chennai'});
      expect(const ContactInfo().toMap(), isEmpty);
    });

    test('PublicVisibility stores every flag', () {
      final v = const PublicVisibility().withField(
        VisibleField.social,
        shown: false,
      );
      expect(v.toMap(), {
        'phone': true,
        'email': true,
        'address': true,
        'hours': true,
        'social': false,
        'unavailableItems': true,
      });
      expect(v.withField(VisibleField.social, shown: true).hidden, isEmpty);
    });

    test('unavailable items are shown unless turned off (FR-043)', () {
      expect(
        const PublicVisibility().isShown(VisibleField.unavailableItems),
        isTrue,
      );
      final off = PublicVisibility.fromMap({'unavailableItems': false});
      expect(off.isShown(VisibleField.unavailableItems), isFalse);
      expect(VisibleField.unavailableItems.isHeaderDetail, isFalse);
    });
  });

  group('SetupChecklist', () {
    const base = Restaurant(
      id: 'r',
      name: 'Spice',
      country: 'IN',
      currency: 'INR',
      timezone: 'Asia/Kolkata',
    );

    test('a new restaurant has nothing done', () {
      final c = SetupChecklist.of(base);
      expect(c.doneCount, 0);
      expect(c.next, SetupStep.profile);
    });

    test('profile completeness needs description, contact and location', () {
      final r = base.copyWith(
        businessType: () => BusinessType.restaurant,
        description: 'Dosas',
        contact: const ContactInfo(phone: '+914423456789'),
      );
      expect(SetupChecklist.isProfileComplete(r), isFalse);
      final done = r.copyWith(
        contact: const ContactInfo(phone: '+914423456789', city: 'Chennai'),
      );
      expect(SetupChecklist.isProfileComplete(done), isTrue);
      expect(SetupChecklist.of(done).next, SetupStep.logo);
    });
  });

  group('SlugRules (FR-092)', () {
    test('format and reserved words', () {
      expect(SlugRules.check('spice-garden'), isNull);
      expect(SlugRules.check(' Spice-Garden '), isNull);
      expect(SlugRules.check('ab'), AppErrorCode.slugInvalid);
      expect(SlugRules.check('a--b'), AppErrorCode.slugInvalid);
      expect(SlugRules.check('-abc'), AppErrorCode.slugInvalid);
      expect(SlugRules.check('x' * 61), AppErrorCode.slugInvalid);
      expect(SlugRules.check('admin'), AppErrorCode.slugReserved);
    });
  });

  group('Validators (FR-011)', () {
    final l10n = lookupCoreLocalizations(const Locale('en'));

    test('optional phone by country', () {
      expect(Validators.optionalPhone(l10n, '', 'IN'), isNull);
      expect(
        Validators.optionalPhone(l10n, '044 2345 6789', 'IN'),
        isNull,
        reason: 'landline',
      );
      expect(Validators.optionalPhone(l10n, '98765 43210', 'IN'), isNull);
      expect(Validators.optionalPhone(l10n, '12345', 'IN'), isNotNull);
      expect(Validators.optionalPhone(l10n, '50 123 4567', 'AE'), isNull);
      expect(Validators.optionalPhone(l10n, '98765 43210', 'AE'), isNotNull);
    });

    test('website must be https', () {
      expect(
        Validators.normalizeHttpsUrl('spicegarden.in'),
        'https://spicegarden.in',
      );
      expect(
        Validators.normalizeHttpsUrl('https://spicegarden.in/menu?x=1'),
        'https://spicegarden.in/menu?x=1',
      );
      expect(Validators.normalizeHttpsUrl('http://spicegarden.in'), isNull);
      expect(Validators.normalizeHttpsUrl('javascript:alert(1)'), isNull);
      expect(Validators.normalizeHttpsUrl('not a url'), isNull);
      expect(Validators.normalizeHttpsUrl('localhost'), isNull);
      expect(
        Validators.optionalHttpsUrl(l10n, 'http://a.com'),
        l10n.validationHttps,
      );
      expect(Validators.optionalHttpsUrl(l10n, 'https://a.com'), isNull);
      expect(
        Validators.normalizeHttpsUrl('https://a.com/x|y'),
        'https://a.com/x%7Cy',
      );
    });

    test('social links accept handles and the right hosts only', () {
      expect(
        Validators.normalizeSocialLink('instagram', '@spice.garden'),
        'https://instagram.com/spice.garden',
      );
      expect(
        Validators.normalizeSocialLink('instagram', 'spicegarden'),
        'https://instagram.com/spicegarden',
      );
      expect(
        Validators.normalizeSocialLink(
          'instagram',
          'https://www.instagram.com/sg/',
        ),
        'https://www.instagram.com/sg/',
      );
      expect(
        Validators.normalizeSocialLink('instagram', 'http://instagram.com/sg'),
        'https://instagram.com/sg',
      );
      expect(
        Validators.normalizeSocialLink('instagram', 'https://evil.example/sg'),
        isNull,
      );
      expect(Validators.normalizeSocialLink('x', '@sg'), 'https://x.com/sg');
      expect(
        Validators.normalizeSocialLink('x', 'twitter.com/sg'),
        'https://twitter.com/sg',
      );
      expect(
        Validators.normalizeSocialLink('youtube', '@sg'),
        'https://youtube.com/@sg',
      );
      expect(
        Validators.normalizeSocialLink(
          'googleMaps',
          'https://maps.app.goo.gl/abc',
        ),
        'https://maps.app.goo.gl/abc',
      );
      expect(
        Validators.normalizeSocialLink(
          'googleMaps',
          'https://www.google.com/maps/place/x',
        ),
        isNotNull,
      );
      expect(
        Validators.normalizeSocialLink(
          'googleMaps',
          'https://www.google.com/search?q=x',
        ),
        isNull,
      );
      expect(Validators.normalizeSocialLink('googleMaps', '@sg'), isNull);
    });

    test('postal code by country', () {
      final india = Countries.india.address;
      expect(Validators.optionalPostalCode(l10n, '600017', india), isNull);
      expect(
        Validators.optionalPostalCode(l10n, '60001', india),
        'Enter a valid PIN code.',
      );
      expect(Countries.byCode('AE')!.address.hasPostalCode, isFalse);
      final us = Countries.byCode('US')!.address;
      expect(Validators.optionalPostalCode(l10n, '10001-1234', us), isNull);
      expect(
        Validators.optionalPostalCode(l10n, 'ABCDE', us),
        'Enter a valid ZIP code.',
      );
    });

    test('every country default zone is a valid IANA zone', () {
      for (final c in Countries.all) {
        for (final z in c.suggestedTimezones) {
          expect(TimeService.isValidZone(z), isTrue, reason: z);
        }
      }
    });
  });
}
