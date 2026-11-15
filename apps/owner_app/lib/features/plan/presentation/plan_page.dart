import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../data/plan_repository.dart';
import 'subscription_banner.dart';

/// Keys, for tests.
abstract final class PlanKeys {
  static const current = ValueKey('plan.current');
  static const usageItems = ValueKey('plan.usage.items');
  static const usageCategories = ValueKey('plan.usage.categories');
  static const compare = ValueKey('plan.compare');
  static const pending = ValueKey('plan.pending');
  static const manageHidden = ValueKey('plan.manageHidden');
  static const switchToFree = ValueKey('plan.switchToFree');
  static const billingMonthly = ValueKey('plan.billing.monthly');
  static const billingAnnual = ValueKey('plan.billing.annual');
  static const send = ValueKey('plan.send');
  static ValueKey<String> planCard(String id) => ValueKey('plan.card.$id');
  static ValueKey<String> request(String id) => ValueKey('plan.request.$id');
}

/// Plan and billing (M10, FR-076 to FR-083, FR-106, §5.5).
///
/// Compact: banners, the current plan with usage bars, then the plans as
/// stacked cards. Expanded (≥ 1024 px): current plan and usage left, the
/// plans side by side right. Upgrades are requested here and activated by
/// an admin after an offline payment.
class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key});

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  bool _sending = false;

  Future<void> _request(Restaurant r, PlanInfo plan) async {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final billing = await showDialog<String>(
      context: context,
      builder: (context) => _RequestDialog(plan: plan),
    );
    if (billing == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(planRepositoryProvider)
          .requestUpgrade(r.id, plan.id, billing);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.planRequestSent)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(core.messageForError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final restaurant = ref.watch(currentRestaurantProvider);
    final plans = ref.watch(plansProvider).value ?? fallbackPlans;
    final breakpoint = Breakpoint.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.planTitle)),
      body: restaurant.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: core.messageForError(e)),
        data: (r) {
          if (r == null) return ErrorState(message: core.errorNotFound);
          final left = [
            const SubscriptionBanners(showManage: false),
            _CurrentPlan(restaurant: r, plans: plans),
          ];
          final compare = _Compare(
            restaurant: r,
            plans: plans,
            sending: _sending,
            onRequest: (p) => _request(r, p),
          );
          final padding = EdgeInsetsDirectional.symmetric(
            horizontal: breakpoint.isCompact ? 16 : 24,
            vertical: 16,
          );
          if (!breakpoint.isExpanded) {
            // A short page: built in full, so every part exists for screen readers.
            return SingleChildScrollView(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...left, const SizedBox(height: 16), compare],
              ),
            );
          }
          return SingleChildScrollView(
            padding: padding,
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: left,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: compare),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String planName(List<PlanInfo> plans, String id) =>
    plans.where((p) => p.id == id).firstOrNull?.name ??
    (id == 'pro'
        ? 'Pro'
        : id == 'free'
        ? 'Free'
        : id);

class _CurrentPlan extends ConsumerWidget {
  const _CurrentPlan({required this.restaurant, required this.plans});

  final Restaurant restaurant;
  final List<PlanInfo> plans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = restaurant;
    final sub = r.subscription;
    final f = r.planFeatures;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String date(DateTime d) =>
        DateFormat.yMMMd(locale).format(TimeService().toZone(d, r.timezone));
    final name = planName(plans, r.planId);
    final status = switch (sub.status) {
      SubscriptionStatus.free => l10n.planFreeForever(name),
      SubscriptionStatus.active =>
        sub.expiresAt == null
            ? name
            : l10n.planActiveUntil(name, date(sub.expiresAt!)),
      SubscriptionStatus.grace => l10n.planGraceUntil(
        name,
        sub.expiresAt == null ? '' : date(sub.expiresAt!),
        sub.graceEndsAt == null ? '' : date(sub.graceEndsAt!),
      ),
    };
    String max(int? m) => isUnlimited(m) ? l10n.planUnlimited : '$m';
    double ratio(int count, int? m) =>
        isUnlimited(m) || m == 0 ? 0 : (count / m!).clamp(0, 1).toDouble();
    Widget usage(Key key, String label, int count, int? m) {
      final over = !isUnlimited(m) && count > m!;
      return Padding(
        key: key,
        padding: const EdgeInsetsDirectional.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Semantics(
              label: label,
              child: LinearProgressIndicator(
                value: isUnlimited(m) ? 0 : ratio(count, m),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: over ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
      );
    }

    final hidden = r.planNotice?.limitsApplied == true || r.overLimit;
    return Card(
      key: PlanKeys.current,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.planCurrent, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(status, style: theme.textTheme.bodyLarge),
            if (r.pendingUpgradeRequestId != null) ...[
              const SizedBox(height: 8),
              Row(
                key: PlanKeys.pending,
                children: [
                  const Icon(Icons.hourglass_top, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.planRequestPending)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(l10n.planUsage, style: theme.textTheme.titleSmall),
            usage(
              PlanKeys.usageItems,
              l10n.planUsageItems(r.itemCount, max(f.maxItems)),
              r.itemCount,
              f.maxItems,
            ),
            usage(
              PlanKeys.usageCategories,
              l10n.planUsageCategories(r.categoryCount, max(f.maxCategories)),
              r.categoryCount,
              f.maxCategories,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hidden)
                  AppSecondaryButton(
                    key: PlanKeys.manageHidden,
                    label: l10n.planManageHidden,
                    icon: Icons.visibility_outlined,
                    onPressed: () => context.go(Routes.planHidden),
                  ),
                if (sub.isPaid)
                  TextButton(
                    key: PlanKeys.switchToFree,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () =>
                        context.go('${Routes.planHidden}?downgrade=1'),
                    child: Text(l10n.planSwitchToFree),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Compare extends StatelessWidget {
  const _Compare({
    required this.restaurant,
    required this.plans,
    required this.sending,
    required this.onRequest,
  });

  final Restaurant restaurant;
  final List<PlanInfo> plans;
  final bool sending;
  final void Function(PlanInfo) onRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final breakpoint = Breakpoint.of(context);
    final cards = [
      for (final p in plans)
        _PlanCard(
          key: PlanKeys.planCard(p.id),
          plan: p,
          current: p.id == restaurant.planId,
          pending: restaurant.pendingUpgradeRequestId != null,
          paid: restaurant.subscription.isPaid,
          sending: sending,
          currency: restaurant.currency,
          onRequest: () => onRequest(p),
        ),
    ];
    return Column(
      key: PlanKeys.compare,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.planCompare, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (breakpoint.isCompact) ...[
          for (final c in cards)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              child: c,
            ),
        ] else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in cards.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: c),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.plan,
    required this.current,
    required this.pending,
    required this.paid,
    required this.sending,
    required this.currency,
    required this.onRequest,
  });

  final PlanInfo plan;
  final bool current;
  final bool pending;
  final bool paid;
  final bool sending;
  final String currency;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final f = plan.features;
    final rows = <(IconData, String)>[
      (Icons.restaurant_menu, l10n.planFeatureItems(f.maxItems ?? 0)),
      (
        Icons.category_outlined,
        isUnlimited(f.maxCategories)
            ? l10n.planFeatureCategoriesUnlimited
            : l10n.planFeatureCategories(f.maxCategories!),
      ),
      (
        Icons.palette_outlined,
        f.premiumThemes
            ? l10n.planFeatureThemesAll
            : l10n.planFeatureThemesBasic,
      ),
      (Icons.insights_outlined, l10n.planFeatureAnalytics(f.analyticsDays)),
      (
        Icons.qr_code_2,
        f.qrLogo ? l10n.planFeatureQrLogo : l10n.planFeatureNoQrLogo,
      ),
      (
        Icons.badge_outlined,
        f.removeBranding
            ? l10n.planFeatureNoBranding
            : l10n.planFeatureBranding,
      ),
    ];
    final prices = plan.prices[currency] ?? const {};
    String? price(String period) {
      final minor = prices[period];
      if (minor == null) return null;
      final money = Money(
        minor,
        currency,
      ).format(locale: Localizations.localeOf(context).toLanguageTag());
      return l10n.planPrice(
        money,
        period == 'annual' ? l10n.planBillingAnnual : l10n.planBillingMonthly,
      );
    }

    final priceLines = [
      for (final b in plan.billing)
        if (price(b) case final p?) p,
    ];
    return Card.outlined(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: current
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: current ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(plan.name, style: theme.textTheme.titleLarge),
                if (current)
                  Chip(
                    label: Text(l10n.planCurrentBadge),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (!plan.isFree) ...[
              const SizedBox(height: 4),
              Text(
                priceLines.isEmpty
                    ? l10n.planPriceOnRequest
                    : priceLines.join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            for (final (icon, text) in rows)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(text)),
                  ],
                ),
              ),
            if (!plan.isFree && !(current && paid)) ...[
              const SizedBox(height: 12),
              AppPrimaryButton(
                key: PlanKeys.request(plan.id),
                label: l10n.planRequest(plan.name),
                icon: Icons.workspace_premium_outlined,
                expand: true,
                loading: sending,
                onPressed: pending ? null : onRequest,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.plan});

  final PlanInfo plan;

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  String _billing = 'annual';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final billing = widget.plan.billing.isEmpty
        ? const ['monthly', 'annual']
        : widget.plan.billing;
    return AlertDialog(
      title: Text(l10n.planRequestTitle(widget.plan.name)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.planRequestBody(widget.plan.name)),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                if (billing.contains('monthly'))
                  ButtonSegment(
                    value: 'monthly',
                    label: Text(
                      l10n.planBillingMonthly,
                      key: PlanKeys.billingMonthly,
                    ),
                  ),
                if (billing.contains('annual'))
                  ButtonSegment(
                    value: 'annual',
                    label: Text(
                      l10n.planBillingAnnual,
                      key: PlanKeys.billingAnnual,
                    ),
                  ),
              ],
              selected: {_billing},
              onSelectionChanged: (s) => setState(() => _billing = s.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: PlanKeys.send,
          onPressed: () => Navigator.of(context).pop(_billing),
          child: Text(l10n.planRequestSend),
        ),
      ],
    );
  }
}
