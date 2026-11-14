import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/dev/presentation/media_test_page.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

const _logo = {
  'path': 'restaurants/rest_1/images/abcdefghij0123456789/original.png',
  'status': 'ready',
  'contentType': 'image/png',
  'width': 512,
  'height': 512,
  'renditions': {
    'w320': 'restaurants/rest_1/images/abcdefghij0123456789/w320.webp',
    'w640': 'restaurants/rest_1/images/abcdefghij0123456789/w640.webp',
    'w1280': 'restaurants/rest_1/images/abcdefghij0123456789/w1280.webp',
  },
};

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('M02 dev media page at ${width.toInt()} px', (tester) async {
      final resolver = FakeStorageImageResolver();
      final app = await pumpOwnerApp(
        tester,
        width: width,
        signedIn: verifiedOwner(),
        overrides: [
          storageImageResolverProvider.overrideWithValue(resolver),
          devRestaurantDocProvider.overrideWith(
            (ref, rid) => Stream.value({
              'name': 'Spice Garden',
              'logo': _logo,
              'cover': {
                'path': 'restaurants/rest_1/images/x/original.jpg',
                'status': 'rejected',
                'reason': 'too-small',
              },
            }),
          ),
        ],
      );
      await app.go(Routes.devMedia);

      expect(find.text('Image upload test'), findsOneWidget);
      expect(find.text('Logo'), findsOneWidget);
      expect(find.text('Cover image'), findsOneWidget);
      expect(find.text('Replace'), findsNWidgets(2));
      expect(find.text('Add image'), findsNothing);
      expect(
        find.text('Remove'),
        findsNothing,
        reason: 'no client writes before M03',
      );
      expect(resolver.resolved, [endsWith('/w320.webp')]);
      expect(find.byType(ImagePickerField), findsNWidgets(2));
      expect(find.textContaining('at least 1200 × 400 px'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await app.dispose();
    });
  }
}
