import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../restaurant/data/restaurant_repository.dart';
import '../domain/publish_models.dart';

/// Publishing, rollback, discard and the draft preview (M06). Everything
/// goes through callables: the server checks the account, the plan limits
/// and the content (BR-011).
abstract class PublishingRepository {
  /// Dry run: every problem and the change summary, nothing written.
  Future<PublishCheck> check(String restaurantId);

  /// Publishes the draft. Throws `publish-blocked` with the problems.
  Future<PublishOutcome> publish(
    String restaurantId, {
    bool pricesReviewed = false,
  });

  /// Publishes version [version] again as a new version; with
  /// [replaceDraft] the draft becomes that version too.
  Future<PublishOutcome> rollback(
    String restaurantId,
    int version, {
    bool replaceDraft = true,
  });

  /// Replaces the draft with the live version. Returns its number.
  Future<int> discardDraft(String restaurantId);

  /// The draft rendered by the public menu renderer (`noindex`), with the
  /// problems a publish would report.
  Future<MenuPreview> preview(String restaurantId);
}

/// The draft preview: the page and what still blocks publishing.
class MenuPreview {
  const MenuPreview({required this.html, this.problems = const []});

  final String html;
  final List<PublishProblem> problems;

  /// Problems that need a fix elsewhere (not the price checkbox).
  List<PublishProblem> get blocking =>
      problems.where((p) => !p.isPriceReview).toList();
}

class CallablePublishingRepository implements PublishingRepository {
  const CallablePublishingRepository();

  Future<Map<Object?, Object?>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    final result = await regionalFunctions
        .httpsCallable(name)
        .call<Map<Object?, Object?>>(data);
    return result.data;
  }

  @override
  Future<PublishCheck> check(String restaurantId) async => PublishCheck.fromMap(
    await _call('publishMenu', {'restaurantId': restaurantId, 'dryRun': true}),
  );

  @override
  Future<PublishOutcome> publish(
    String restaurantId, {
    bool pricesReviewed = false,
  }) async => PublishOutcome.fromMap(
    await _call('publishMenu', {
      'restaurantId': restaurantId,
      if (pricesReviewed) 'pricesReviewed': true,
    }),
  );

  @override
  Future<PublishOutcome> rollback(
    String restaurantId,
    int version, {
    bool replaceDraft = true,
  }) async => PublishOutcome.fromMap(
    await _call('rollbackMenu', {
      'restaurantId': restaurantId,
      'version': version,
      'replaceDraft': replaceDraft,
    }),
  );

  @override
  Future<int> discardDraft(String restaurantId) async =>
      (await _call('discardDraft', {'restaurantId': restaurantId}))['version']!
          as int;

  @override
  Future<MenuPreview> preview(String restaurantId) async {
    final m = await _call('previewMenu', {'restaurantId': restaurantId});
    return MenuPreview(
      html: m['html']! as String,
      problems: PublishProblem.listFrom(m['problems']),
    );
  }
}

final publishingRepositoryProvider = Provider<PublishingRepository>(
  (ref) => const CallablePublishingRepository(),
);

/// The draft preview. Refreshed by invalidating it.
final menuPreviewProvider = FutureProvider.autoDispose<MenuPreview>((
  ref,
) async {
  final rid = ref.watch(currentRestaurantIdProvider);
  if (rid == null) throw StateError('No restaurant');
  return ref.watch(publishingRepositoryProvider).preview(rid);
});
