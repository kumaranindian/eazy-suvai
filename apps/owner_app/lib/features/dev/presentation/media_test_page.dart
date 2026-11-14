import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';

/// The signed-in owner's restaurant document, live.
/// Overridden in tests.
final devRestaurantDocProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>(
      (ref, rid) => FirebaseFirestore.instance
          .doc('restaurants/$rid')
          .snapshots()
          .map((s) => s.data()),
    );

/// Developer page (not in prod builds) to try the M02 image pipeline by
/// hand before M03 adds the logo and cover to the profile screen:
/// `/dev/media`. Uploads go to the real `logo` and `cover` fields.
///
/// No Remove button: owners cannot write the restaurant document until M03.
class MediaTestPage extends ConsumerWidget {
  const MediaTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rid = ref.watch(authSessionProvider).value?.restaurantId;

    final Widget body;
    if (rid == null) {
      body = const LoadingState();
    } else {
      final doc = ref.watch(devRestaurantDocProvider(rid));
      body = doc.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: CoreLocalizations.of(context).messageForError(e),
          onRetry: () => ref.invalidate(devRestaurantDocProvider(rid)),
        ),
        data: (data) => ListView(
          padding: const EdgeInsetsDirectional.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.devMediaIntro),
                    const SizedBox(height: 24),
                    ImagePickerField(
                      purpose: ImagePurpose.logo,
                      restaurantId: rid,
                      targetPath: 'restaurants/$rid',
                      label: l10n.devMediaLogo,
                      value: ImageObject.fromMap(data?['logo']),
                    ),
                    const SizedBox(height: 32),
                    ImagePickerField(
                      purpose: ImagePurpose.cover,
                      restaurantId: rid,
                      targetPath: 'restaurants/$rid',
                      label: l10n.devMediaCover,
                      value: ImageObject.fromMap(data?['cover']),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devMediaTitle)),
      body: body,
    );
  }
}
