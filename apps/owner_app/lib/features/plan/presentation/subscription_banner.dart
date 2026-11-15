import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../publishing/presentation/publish_dialog.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../data/plan_repository.dart';

/// Keys, for tests.
abstract final class SubscriptionBannerKeys {
  static const grace = ValueKey('banner.grace');
  static const expiring = ValueKey('banner.expiring');
  static const overLimit = ValueKey('banner.overLimit');
  static const restored = ValueKey('banner.restored');
}

/// Plan banners for the dashboard and the plan page (M10):
/// - grace period: renew (FR-100 step 2);
/// - expiry within 14 days (FR-100 step 1, dashboard reminder);
/// - content hidden over the limit (FR-101): manage;
/// - hidden content restored after an upgrade: publish (FR-101).
class SubscriptionBanners extends ConsumerWidget {
  const SubscriptionBanners({super.key, this.showManage = true});

  /// False on the plan page itself (it has the link already).
  final bool showManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final r = ref.watch(currentRestaurantProvider).value;
    if (r == null) return const SizedBox.shrink();
    final now = ref.watch(planClockProvider)();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFmt = DateFormat.yMMMd(locale);
    final sub = r.subscription;
    final plan = sub.planId == 'pro' ? 'Pro' : sub.planId;
    final hiddenCount = r.planNotice?.limitsApplied == true
        ? r.planNotice!.hiddenItems + r.planNotice!.hiddenCategories
        : 0;
    final banners = <Widget>[
      if (sub.status == SubscriptionStatus.grace && sub.graceEndsAt != null)
        _Banner(
          key: SubscriptionBannerKeys.grace,
          icon: Icons.warning_amber_rounded,
          tone: _Tone.warning,
          text: l10n.bannerGrace(
            plan,
            dateFmt.format(TimeService().toZone(sub.graceEndsAt!, r.timezone)),
          ),
          action: l10n.bannerRenew,
          onAction: () => context.go(Routes.plan),
        )
      else if (sub.expiresSoon(now))
        _Banner(
          key: SubscriptionBannerKeys.expiring,
          icon: Icons.event_outlined,
          tone: _Tone.info,
          text: l10n.bannerExpiring(
            plan,
            Subscription.daysUntil(sub.expiresAt!, now),
            dateFmt.format(TimeService().toZone(sub.expiresAt!, r.timezone)),
          ),
          action: l10n.bannerRenew,
          onAction: () => context.go(Routes.plan),
        ),
      if (hiddenCount > 0)
        _Banner(
          key: SubscriptionBannerKeys.overLimit,
          icon: Icons.visibility_off_outlined,
          tone: _Tone.info,
          text: l10n.bannerOverLimit(hiddenCount),
          action: showManage ? l10n.bannerManage : null,
          onAction: () => context.go(Routes.planHidden),
        ),
      if (r.planNotice?.restoredContent == true && r.hasUnpublishedChanges)
        _Banner(
          key: SubscriptionBannerKeys.restored,
          icon: Icons.restore,
          tone: _Tone.info,
          text: l10n.bannerRestored,
          action: l10n.bannerPublish,
          onAction: () => showPublishDialog(context),
        ),
    ];
    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in banners)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 12),
            child: b,
          ),
      ],
    );
  }
}

enum _Tone { info, warning }

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.tone,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final _Tone tone;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = tone == _Tone.warning
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final fg = tone == _Tone.warning
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: TextStyle(color: fg)),
              ),
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: fg,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(action!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
