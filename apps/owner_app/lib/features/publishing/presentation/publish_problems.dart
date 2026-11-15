import 'package:core/core.dart';
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../domain/publish_models.dart';

/// The owner-facing sentence for a publish problem (FR-066).
String problemMessage(
  PublishProblem p,
  AppLocalizations l10n,
  CoreLocalizations core,
) {
  final name = (p.name == null || p.name!.isEmpty)
      ? l10n.problemUnnamedItem
      : p.name!;
  int detail(String key) => p.details[key] is int ? p.details[key]! as int : 0;
  return switch (p.code) {
    PublishProblemCode.emailNotVerified => l10n.problemEmailNotVerified,
    PublishProblemCode.menuEmpty => l10n.problemMenuEmpty,
    PublishProblemCode.pricesNeedReview => l10n.problemPrices,
    PublishProblemCode.snapshotTooLarge => l10n.problemTooLarge,
    PublishProblemCode.limitExceeded =>
      p.details['limit'] == 'categories'
          ? l10n.problemLimitCategories(detail('count'), detail('max'))
          : l10n.problemLimitItems(detail('count'), detail('max')),
    PublishProblemCode.missingField ||
    PublishProblemCode.invalidField => switch ((p.target, p.field)) {
      (ProblemTarget.restaurant, 'name') => l10n.problemRestaurantName,
      (ProblemTarget.restaurant, 'currency') => l10n.problemCurrency,
      (ProblemTarget.restaurant, 'timezone') => l10n.problemTimezone,
      (ProblemTarget.restaurant, final String f)
          when f.startsWith('openingHours.') =>
        l10n.problemHours(_dayLabel(f.substring(13), core)),
      (ProblemTarget.category, _) => l10n.problemCategoryName,
      (ProblemTarget.item, 'name') => l10n.problemItemName,
      (ProblemTarget.item, 'priceMinor') => l10n.problemItemPrice(name),
      (ProblemTarget.item, 'dietaryLabelId') =>
        p.code == PublishProblemCode.invalidField
            ? l10n.problemItemLabelGone(name)
            : l10n.problemItemLabel(name),
      _ => l10n.problemUnknown,
    },
    PublishProblemCode.unknown => l10n.problemUnknown,
  };
}

String _dayLabel(String key, CoreLocalizations core) {
  for (final d in Weekday.values) {
    if (d.key == key) return d.label(core);
  }
  return key;
}

/// Where "Fix" leads. A category opens its items; on wide layouts the
/// caller selects it in the menu manager instead ([categoryId]).
({String route, String? categoryId}) fixRouteFor(PublishProblem p) {
  final field = p.field ?? '';
  return switch (p.code) {
    PublishProblemCode.emailNotVerified => (
      route: Routes.verifyEmail,
      categoryId: null,
    ),
    PublishProblemCode.missingField ||
    PublishProblemCode.invalidField => switch (p.target) {
      ProblemTarget.restaurant when field.startsWith('openingHours') => (
        route: Routes.hours,
        categoryId: null,
      ),
      ProblemTarget.restaurant
          when field == 'currency' || field == 'timezone' =>
        (route: Routes.regional, categoryId: null),
      ProblemTarget.restaurant => (route: Routes.profile, categoryId: null),
      ProblemTarget.category when p.id != null => (
        route: Routes.menuCategory(p.id!),
        categoryId: p.id,
      ),
      ProblemTarget.item when p.id != null => (
        route: Routes.menuItem(p.id!),
        categoryId: null,
      ),
      _ => (route: Routes.menu, categoryId: null),
    },
    _ => (route: Routes.menu, categoryId: null),
  };
}

/// Keys used by tests.
abstract final class PublishKeys {
  static const bar = ValueKey('publish.bar');
  static const barPreview = ValueKey('publish.bar.preview');
  static const barPublish = ValueKey('publish.bar.publish');
  static const dialog = ValueKey('publish.dialog');
  static const confirm = ValueKey('publish.confirm');
  static const pricesReviewed = ValueKey('publish.pricesReviewed');
  static const problems = ValueKey('publish.problems');
  static const summary = ValueKey('publish.summary');
  static const previewPhone = ValueKey('preview.phone');
  static const previewDesktop = ValueKey('preview.desktop');
  static const previewToggle = ValueKey('preview.toggle');
  static const previewPublish = ValueKey('preview.publish');
  static const discard = ValueKey('versions.discard');
  static const restoreReplace = ValueKey('versions.restore.replace');
  static const restoreConfirm = ValueKey('versions.restore.confirm');
  static ValueKey<String> fix(int index) => ValueKey('publish.fix.$index');
  static ValueKey<String> version(int n) => ValueKey('versions.$n');
  static ValueKey<String> restore(int n) => ValueKey('versions.$n.restore');
}
