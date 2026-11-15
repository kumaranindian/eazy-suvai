import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/admin_api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../router/app_router.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/read_only.dart';

/// Keys, for tests.
abstract final class DashboardKeys {
  static ValueKey<String> tile(String name) => ValueKey('dash.tile.$name');
  static const recent = ValueKey('dash.recent');
  static const recompute = ValueKey('dash.recompute');
  static const metrics = ValueKey('dash.metrics');
  static ValueKey<String> metric(String name) => ValueKey('dash.metric.$name');
}

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(adminApiProvider).call('adminDashboard'),
);

/// The admin dashboard (M11, FR-085): restaurants by status, subscriptions
/// by status, pending upgrade requests, items and menu views, and the
/// latest sign-ups.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final data = ref.watch(dashboardProvider);
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return data.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: core.messageForError(e)),
      data: (d) {
        final s = Map<String, dynamic>.from((d['stats'] as Map?) ?? const {});
        int n(Object? v) => v is num ? v.toInt() : 0;
        Map<String, dynamic> m(String k) =>
            Map<String, dynamic>.from((s[k] as Map?) ?? const {});
        final byStatus = m('restaurantsByStatus');
        final bySub = m('subscriptionsByStatus');
        final tiles = <(String, String, int, IconData, VoidCallback?)>[
          (
            'total',
            l10n.dashRestaurants,
            n(s['restaurants']) - n(byStatus['deleted']),
            Icons.storefront_outlined,
            () => context.go(Routes.restaurants),
          ),
          (
            'active',
            l10n.dashActive,
            n(byStatus['active']),
            Icons.check_circle_outline,
            null,
          ),
          (
            'suspended',
            l10n.dashSuspended,
            n(byStatus['suspended']),
            Icons.pause_circle_outline,
            null,
          ),
          (
            'deactivated',
            l10n.dashDeactivated,
            n(byStatus['deactivated']),
            Icons.block_outlined,
            null,
          ),
          (
            'free',
            l10n.dashFree,
            n(bySub['free']),
            Icons.card_giftcard_outlined,
            null,
          ),
          (
            'paid',
            l10n.dashPaid,
            n(bySub['active']),
            Icons.workspace_premium_outlined,
            null,
          ),
          (
            'grace',
            l10n.dashGrace,
            n(bySub['grace']),
            Icons.hourglass_bottom,
            null,
          ),
          (
            'expired',
            l10n.dashExpired,
            n(s['subscriptionsExpired']),
            Icons.event_busy_outlined,
            null,
          ),
          (
            'pending',
            l10n.dashPending,
            n(d['pendingUpgrades']),
            Icons.upgrade,
            () => context.go(Routes.upgrades),
          ),
          (
            'items',
            l10n.dashItems,
            n(s['totalItems']),
            Icons.restaurant_menu,
            null,
          ),
          (
            'views',
            l10n.dashViews,
            n(s['menuViews']),
            Icons.visibility_outlined,
            null,
          ),
          ('qr', l10n.dashQrVisits, n(s['qrVisits']), Icons.qr_code_2, null),
        ];
        final recent = listOf(d['recentSignups']);
        return AdminPageBody(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final perRow = c.maxWidth >= 1000
                    ? 4
                    : (c.maxWidth >= 560 ? 3 : 2);
                final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final (key, label, value, icon, onTap) in tiles)
                      SizedBox(
                        width: w,
                        child: Card(
                          key: DashboardKeys.tile(key),
                          margin: EdgeInsets.zero,
                          // The label sits on the tappable node itself (M13).
                          child: Semantics(
                            button: onTap != null,
                            label: '$label: ${number.format(value)}',
                            child: InkWell(
                              onTap: onTap,
                              borderRadius: BorderRadius.circular(12),
                              child: ExcludeSemantics(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        icon,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        number.format(value),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall,
                                      ),
                                      Text(label),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _SuccessMetrics(stats: s, number: number),
            AdminSectionCard(
              key: DashboardKeys.recent,
              title: l10n.dashRecent,
              trailing: adminReadOnly(context)
                  ? null
                  : TextButton.icon(
                      key: DashboardKeys.recompute,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.dashRecompute),
                      onPressed: () async {
                        final ok = await runAdminAction(
                          context,
                          () => ref
                              .read(adminApiProvider)
                              .call('recomputePlatformStats'),
                          done: l10n.dashRecomputed,
                        );
                        if (ok) ref.invalidate(dashboardProvider);
                      },
                    ),
              children: [
                if (recent.isEmpty) Text(l10n.dashNoSignups),
                for (final r in recent)
                  ListTile(
                    contentPadding: EdgeInsetsDirectional.zero,
                    title: Text('${r['name']}'),
                    subtitle: Text(
                      '${r['ownerEmail'] ?? ''} · ${r['country'] ?? ''} · ${fmtDate(context, r['createdAt'])}',
                    ),
                    trailing: StatusChip(
                      label: l10n.statusName('${r['status']}'),
                      tone: statusTone('${r['status']}'),
                    ),
                    onTap: () => context.go(Routes.restaurant('${r['id']}')),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// FRD §13 success metrics (M13). Counters come from `stats/platform`
/// (kept by triggers, recounted nightly); rates are worked out here.
class _SuccessMetrics extends StatelessWidget {
  const _SuccessMetrics({required this.stats, required this.number});

  final Map<String, dynamic> stats;
  final NumberFormat number;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = stats;
    int n(Object? v) => v is num ? v.toInt() : 0;
    final byStatus = Map<String, dynamic>.from(
      (s['restaurantsByStatus'] as Map?) ?? const {},
    );
    final registered = n(s['restaurants']);
    final live = registered - n(byStatus['deleted']);
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    )..maximumFractionDigits = 1;
    String rate(int a, int b) => b == 0 ? '–' : percent.format(a / b);
    final median = s['medianMinutesToFirstPublish'];
    final monthly = listOf(s['monthly']);
    final thisMonth = monthly.isEmpty ? null : monthly.first;
    final renewals = n(s['renewals']);
    final rows = <(String, String, String)>[
      (
        'activated',
        l10n.metricActivated,
        '${number.format(n(s['activated']))} (${rate(n(s['activated']), registered)})',
      ),
      (
        'published',
        l10n.metricPublished,
        number.format(n(s['publishedMenus'])),
      ),
      (
        'qrDownloads',
        l10n.metricQrDownloads,
        number.format(n(s['qrDownloads'])),
      ),
      (
        'median',
        l10n.metricMedianPublish,
        median is num ? l10n.metricMinutes(median.toInt()) : '–',
      ),
      (
        'monthViews',
        l10n.metricMonthViews(
          thisMonth == null ? '–' : '${thisMonth['month']}',
        ),
        thisMonth == null
            ? '–'
            : l10n.metricViewsAndQr(
                number.format(n(thisMonth['views'])),
                number.format(n(thisMonth['qrVisits'])),
              ),
      ),
      (
        'conversion',
        l10n.metricConversion,
        '${number.format(n(s['conversions']))} (${rate(n(s['conversions']), registered)})',
      ),
      (
        'renewal',
        l10n.metricRenewal,
        '${number.format(renewals)} (${rate(renewals, renewals + n(s['subscriptionsExpired']))})',
      ),
      (
        'churn',
        l10n.metricChurn,
        rate(n(byStatus['deactivated']) + n(byStatus['deleted']), registered),
      ),
      (
        'avgItems',
        l10n.metricAvgItems,
        live == 0
            ? '–'
            : (NumberFormat.decimalPattern(
                Localizations.localeOf(context).toLanguageTag(),
              )..maximumFractionDigits = 1).format(n(s['totalItems']) / live),
      ),
      ('support', l10n.metricSupport, l10n.metricSupportOutside),
    ];
    return AdminSectionCard(
      key: DashboardKeys.metrics,
      title: l10n.metricsTitle,
      children: [
        for (final (key, label, value) in rows)
          Padding(
            key: DashboardKeys.metric(key),
            padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              children: [
                Text(label),
                Text(value, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
      ],
    );
  }
}
