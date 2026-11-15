import 'package:flutter/material.dart';
import 'package:owner_app/features/publishing/data/publishing_repository.dart';
import 'package:owner_app/features/publishing/domain/publish_models.dart';

/// In-memory publishing callables. Set [nextCheck] for the dry run; a
/// publish with blocking problems throws `publish-blocked` like the server.
class FakePublishingRepository implements PublishingRepository {
  FakePublishingRepository({PublishCheck? check})
    : nextCheck =
          check ??
          const PublishCheck(
            problems: [],
            summary: ChangeSummary(
              firstPublish: true,
              categories: ChangeLists(added: [ChangeRef('c1', 'Starters')]),
              items: ChangeLists(
                added: [ChangeRef('i1', 'Idli'), ChangeRef('i2', 'Vada')],
              ),
            ),
          );

  PublishCheck nextCheck;
  final checks = <String>[];
  final publishes = <bool>[];
  final rollbacks = <(int, bool)>[];
  int discards = 0;
  int previews = 0;

  /// Thrown once by the next publish (for example `publish-blocked`).
  Object? nextPublishError;

  /// Called after a publish, rollback or discard with the new version, so a
  /// test can update the fake restaurant like the server would.
  void Function(int version)? onPublished;

  String html = '<html><body>Spice Garden preview</body></html>';

  @override
  Future<PublishCheck> check(String restaurantId) async {
    checks.add(restaurantId);
    return nextCheck;
  }

  @override
  Future<PublishOutcome> publish(
    String restaurantId, {
    bool pricesReviewed = false,
  }) async {
    publishes.add(pricesReviewed);
    final e = nextPublishError;
    if (e != null) {
      nextPublishError = null;
      throw e;
    }
    final v = (nextCheck.currentVersion ?? 0) + 1;
    onPublished?.call(v);
    return PublishOutcome(version: v, summary: nextCheck.summary);
  }

  @override
  Future<PublishOutcome> rollback(
    String restaurantId,
    int version, {
    bool replaceDraft = true,
  }) async {
    rollbacks.add((version, replaceDraft));
    final v = (nextCheck.currentVersion ?? 0) + 1;
    onPublished?.call(v);
    return PublishOutcome(version: v, summary: const ChangeSummary());
  }

  @override
  Future<int> discardDraft(String restaurantId) async {
    discards++;
    return nextCheck.currentVersion ?? 1;
  }

  @override
  Future<MenuPreview> preview(String restaurantId) async {
    previews++;
    return MenuPreview(html: html, problems: nextCheck.problems);
  }
}

/// Stands in for the iframe / web view, which widget tests cannot host.
Widget fakeMenuHtmlView(String html, String label) => Semantics(
  label: label,
  child: ColoredBox(
    color: Colors.white,
    child: Text('HTML ${html.length}', key: const ValueKey('fake.html')),
  ),
);
