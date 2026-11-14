import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';

/// Keys used by tests.
abstract final class MenuKeys {
  static const addCategory = ValueKey('menu.addCategory');
  static const addItem = ValueKey('menu.addItem');
  static const recentlyDeleted = ValueKey('menu.recentlyDeleted');
  static const allItems = ValueKey('menu.allItems');
  static const search = ValueKey('menu.search');
  static const filterSoldOut = ValueKey('menu.filter.soldOut');
  static const filterFeatured = ValueKey('menu.filter.featured');
  static const categoryPane = ValueKey('menu.pane.categories');
  static const itemPane = ValueKey('menu.pane.items');
  static const editorPane = ValueKey('menu.pane.editor');
  static const bulkBar = ValueKey('menu.bulk');
  static const bulkAvailable = ValueKey('menu.bulk.available');
  static const bulkSoldOut = ValueKey('menu.bulk.soldOut');
  static const bulkMove = ValueKey('menu.bulk.move');
  static const bulkDelete = ValueKey('menu.bulk.delete');
  static const bulkSelectAll = ValueKey('menu.bulk.selectAll');
  static const upgrade = ValueKey('menu.limit.upgrade');

  static ValueKey<String> category(String id) => ValueKey('menu.category.$id');
  static ValueKey<String> categoryActive(String id) =>
      ValueKey('menu.category.$id.active');
  static ValueKey<String> categoryMenu(String id) =>
      ValueKey('menu.category.$id.more');
  static ValueKey<String> item(String id) => ValueKey('menu.item.$id');
  static ValueKey<String> itemAvailable(String id) =>
      ValueKey('menu.item.$id.available');
  static ValueKey<String> itemSelect(String id) =>
      ValueKey('menu.item.$id.select');
  static ValueKey<String> itemMenu(String id) => ValueKey('menu.item.$id.more');
  static ValueKey<String> restore(String id) => ValueKey('menu.restore.$id');
}

/// The plan limit details of a `limit-reached` error, if [error] is one.
({String limit, int? max})? planLimitOf(Object error) {
  if (error is! FirebaseFunctionsException) return null;
  if (appErrorCodeOfFunctions(error) != AppErrorCode.limitReached) return null;
  final d = error.details;
  final limit = d is Map && d['limit'] is String
      ? d['limit'] as String
      : 'items';
  final max = d is Map && d['max'] is int ? d['max'] as int : null;
  return (limit: limit, max: max);
}

/// Tells the owner a plan limit stopped them, with an "Upgrade" button
/// (BR-011). M10 replaces the upgrade screen.
Future<void> showPlanLimitDialog(
  BuildContext context, {
  required String limit,
  int? max,
}) {
  final l10n = AppLocalizations.of(context);
  final message = switch ((limit, max)) {
    ('categories', final int m) => l10n.menuLimitCategories(m),
    ('items', final int m) => l10n.menuLimitItems(m),
    _ => l10n.menuLimitGeneric,
  };
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.workspace_premium_outlined),
      title: Text(l10n.menuLimitTitle),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.actionNotNow),
        ),
        FilledButton(
          key: MenuKeys.upgrade,
          onPressed: () {
            // Close this prompt and any dialog or sheet below it.
            Navigator.of(
              dialogContext,
              rootNavigator: true,
            ).popUntil((route) => route is! PopupRoute);
            GoRouter.of(context).go(Routes.plan);
          },
          child: Text(l10n.actionUpgrade),
        ),
      ],
    ),
  );
}

/// Runs a menu write and reports the outcome: a plan-limit dialog for
/// `limit-reached`, otherwise a snack bar with the localized error.
/// [success] is shown when it works, with an Undo button if [onUndo] is set.
/// Returns whether it worked.
Future<bool> runMenuAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
  Future<void> Function()? onUndo,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final core = CoreLocalizations.of(context);
  final l10n = AppLocalizations.of(context);
  // Floating and narrow on wide layouts, so it never covers the editor
  // pane's Save bar.
  final wide = !Breakpoint.of(context).isCompact;
  SnackBar bar(String text, {SnackBarAction? action}) => SnackBar(
    content: Text(text),
    action: action,
    behavior: SnackBarBehavior.floating,
    width: wide ? 400 : null,
  );
  try {
    await action();
  } catch (e) {
    final limit = planLimitOf(e);
    if (limit != null && context.mounted) {
      await showPlanLimitDialog(context, limit: limit.limit, max: limit.max);
    } else {
      messenger
        ?..clearSnackBars()
        ..showSnackBar(bar(core.messageForError(e)));
    }
    return false;
  }
  if (success != null) {
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      bar(
        success,
        action: onUndo == null
            ? null
            : SnackBarAction(
                label: l10n.actionUndo,
                onPressed: () async {
                  try {
                    await onUndo();
                  } catch (e) {
                    messenger.showSnackBar(bar(core.messageForError(e)));
                  }
                },
              ),
      ),
    );
  }
  return true;
}

/// "Restore within {n} days" for a deleted category or item.
String daysLeftLabel(AppLocalizations l10n, DateTime? restoreUntil) {
  if (restoreUntil == null) return '';
  final left = restoreUntil.difference(DateTime.now()).inHours / 24;
  return l10n.menuDeletedDaysLeft(left.ceil().clamp(0, 30));
}
