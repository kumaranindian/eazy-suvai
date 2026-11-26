import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../menu/application/menu_state.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics.dart';

/// Keys, for tests.
abstract final class AnalyticsKeys {
  static const range7 = ValueKey('analytics.range7');
  static const range30 = ValueKey('analytics.range30');
  static const rangeCustom = ValueKey('analytics.rangeCustom');
  static const rangeLabel = ValueKey('analytics.rangeLabel');
  static const upgrade = ValueKey('analytics.upgrade');
  static const tiles = ValueKey('analytics.tiles');
  static const chart = ValueKey('analytics.chart');
  static const topCategories = ValueKey('analytics.topCategories');
  static const topItems = ValueKey('analytics.topItems');
  static const months = ValueKey('analytics.months');
  static const empty = ValueKey('analytics.empty');
  static const notPublished = ValueKey('analytics.notPublished');
  static ValueKey<String> tile(String name) => ValueKey('analytics.tile.$name');
}

/// Owner analytics (M09, FR-071 to FR-075, AC-015).
///
/// - Range chips: 7 days, 30 days, custom (a date-range picker limited to
///   the plan's history). A range beyond the plan shows the upgrade prompt.
/// - Tiles: views, QR visits, share from the QR code, item interest. Two
///   per row on phones, four in a row from 600 px.
/// - A daily line chart (views and QR visits), then the top categories and
///   items (side by side from 1024 px), and monthly totals when the range
///   spans more than one month.
class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  bool _showUpgrade = false;

  void _choose(AnalyticsRangeKind kind, String today, int historyDays) {
    final range = presetRange(kind, today);
    if (!rangeAllowed(range, today, historyDays)) {
      setState(() => _showUpgrade = true);
      return;
    }
    setState(() => _showUpgrade = false);
    ref.read(analyticsRangeChoiceProvider.notifier).set(range);
  }

  Future<void> _custom(
    String today,
    int historyDays,
    AnalyticsRange current,
  ) async {
    final first = dateOfKey(earliestAllowed(today, historyDays));
    final last = dateOfKey(today);
    final initialStart = dateOfKey(current.start).isBefore(first)
        ? first
        : dateOfKey(current.start);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: dateOfKey(current.end),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _showUpgrade = false);
    ref
        .read(analyticsRangeChoiceProvider.notifier)
        .set(
          AnalyticsRange(
            AnalyticsRangeKind.custom,
            keyOfDate(picked.start),
            keyOfDate(picked.end),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final today = ref.watch(analyticsTodayProvider);
    final range = ref.watch(analyticsRangeProvider);
    final historyDays = ref.watch(analyticsHistoryDaysProvider);
    final restaurant = ref.watch(currentRestaurantProvider).value;
    if (today == null || range == null || restaurant == null) {
      return const LoadingState();
    }
    final summary = ref.watch(analyticsSummaryProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFmt = DateFormat.yMMMd(locale);
    final can30 = rangeAllowed(
      presetRange(AnalyticsRangeKind.last30, today),
      today,
      historyDays,
    );
    final breakpoint = Breakpoint.of(context);

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          key: AnalyticsKeys.range7,
          label: Text(l10n.analyticsRange7),
          selected: range.kind == AnalyticsRangeKind.last7,
          onSelected: (_) =>
              _choose(AnalyticsRangeKind.last7, today, historyDays),
        ),
        ChoiceChip(
          key: AnalyticsKeys.range30,
          avatar: can30 ? null : const Icon(Icons.lock_outline, size: 18),
          label: Text(
            can30
                ? l10n.analyticsRange30
                : l10n.analyticsLocked(l10n.analyticsRange30),
          ),
          selected: range.kind == AnalyticsRangeKind.last30,
          onSelected: (_) =>
              _choose(AnalyticsRangeKind.last30, today, historyDays),
        ),
        ChoiceChip(
          key: AnalyticsKeys.rangeCustom,
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(l10n.analyticsRangeCustom),
          selected: range.kind == AnalyticsRangeKind.custom,
          onSelected: (_) => _custom(today, historyDays, range),
        ),
      ],
    );

    final children = <Widget>[
      chips,
      const SizedBox(height: 8),
      Text(
        l10n.analyticsRangeLabel(
          dateFmt.format(dateOfKey(range.start)),
          dateFmt.format(dateOfKey(range.end)),
        ),
        key: AnalyticsKeys.rangeLabel,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      if (_showUpgrade) ...[
        const SizedBox(height: 12),
        _UpgradeCard(historyDays: historyDays),
      ],
      if (restaurant.publishedVersion == null) ...[
        const SizedBox(height: 12),
        _Notice(
          key: AnalyticsKeys.notPublished,
          icon: Icons.info_outline,
          text: l10n.analyticsNotPublished,
        ),
      ],
      const SizedBox(height: 16),
      ...summary.when(
        loading: () => [const SizedBox(height: 240, child: LoadingState())],
        error: (e, _) => [ErrorState(message: core.messageForError(e))],
        data: (s) => s.isEmpty
            ? [
                SizedBox(
                  key: AnalyticsKeys.empty,
                  height: 320,
                  child: EmptyState(
                    icon: Icons.insights_outlined,
                    title: l10n.analyticsEmptyTitle,
                    message: l10n.analyticsEmptyMessage,
                    actionLabel: l10n.analyticsEmptyAction,
                    onAction: () => context.go(Routes.share),
                  ),
                ),
              ]
            : _content(context, l10n, s, breakpoint, locale),
      ),
      const SizedBox(height: 16),
      Text(
        l10n.analyticsPrivacyNote,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: breakpoint.isCompact ? 16 : 24,
        vertical: 16,
      ),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    AppLocalizations l10n,
    AnalyticsSummary s,
    Breakpoint breakpoint,
    String locale,
  ) {
    final number = NumberFormat.decimalPattern(locale);
    final percent = NumberFormat.percentPattern(locale);
    final menu = ref.watch(menuDataProvider).value;
    final names = <String, String>{
      if (menu != null) ...{
        for (final c in [...menu.categories, ...menu.deletedCategories])
          c.id: c.name,
        for (final i in [...menu.items, ...menu.deletedItems]) i.id: i.name,
      },
    };
    final tiles = [
      _Tile(
        key: AnalyticsKeys.tile('views'),
        icon: Icons.visibility_outlined,
        label: l10n.analyticsViews,
        value: number.format(s.views),
      ),
      _Tile(
        key: AnalyticsKeys.tile('qr'),
        icon: Icons.qr_code_2,
        label: l10n.analyticsQrVisits,
        value: number.format(s.qrVisits),
      ),
      _Tile(
        key: AnalyticsKeys.tile('qrShare'),
        icon: Icons.pie_chart_outline,
        label: l10n.analyticsQrShare,
        value: percent.format(s.qrShare),
      ),
      _Tile(
        key: AnalyticsKeys.tile('items'),
        icon: Icons.touch_app_outlined,
        label: l10n.analyticsItemOpens,
        value: number.format(s.itemOpens),
      ),
    ];
    final topCategories = _TopList(
      key: AnalyticsKeys.topCategories,
      title: l10n.analyticsTopCategories,
      entries: [
        for (final r in s.topCategories)
          (names[r.id] ?? l10n.analyticsRemoved, l10n.analyticsTaps(r.count)),
      ],
    );
    final topItems = _TopList(
      key: AnalyticsKeys.topItems,
      title: l10n.analyticsTopItems,
      entries: [
        for (final r in s.topItems)
          (names[r.id] ?? l10n.analyticsRemoved, l10n.analyticsOpens(r.count)),
      ],
    );
    return [
      LayoutBuilder(
        key: AnalyticsKeys.tiles,
        builder: (context, c) {
          final perRow = c.maxWidth >= 560 ? 4 : 2;
          final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final t in tiles) SizedBox(width: w, child: t)],
          );
        },
      ),
      const SizedBox(height: 16),
      _ChartCard(summary: s, locale: locale),
      const SizedBox(height: 16),
      if (breakpoint.isExpanded)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: topCategories),
            const SizedBox(width: 16),
            Expanded(child: topItems),
          ],
        )
      else ...[
        topCategories,
        const SizedBox(height: 16),
        topItems,
      ],
      if (s.months.length > 1) ...[
        const SizedBox(height: 16),
        Card(
          key: AnalyticsKeys.months,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.analyticsMonthly,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final m in s.months)
                  ListTile(
                    contentPadding: EdgeInsetsDirectional.zero,
                    title: Text(
                      DateFormat.yMMMM(
                        locale,
                      ).format(dateOfKey('${m.month}-01')),
                    ),
                    trailing: Text(l10n.analyticsMonthRow(m.views, m.qrVisits)),
                  ),
              ],
            ),
          ),
        ),
      ],
    ];
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Semantics(
        container: true,
        label: '$label: $value',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.headlineSmall),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.summary, required this.locale});

  final AnalyticsSummary summary;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final viewsColor = theme.colorScheme.primary;
    final qrColor = theme.brightness == Brightness.dark
        ? BrandColors.greenOnDark
        : BrandColors.greenText;
    final points = summary.series;
    final peak = math.max(
      4,
      points.fold<int>(0, (m, p) => math.max(m, math.max(p.views, p.qrVisits))),
    );
    // Counts: whole-number grid lines and a "nice" top (8 views -> 10,
    // not 9.2), with ~15% headroom above the peak.
    final yInterval = _niceStep((peak * 1.15).ceil() / 4);
    final maxY = ((peak * 1.15) / yInterval).ceil() * yInterval;
    final count = NumberFormat.decimalPattern(locale);
    final short = DateFormat.MMMd(locale);
    final step = math.max(1, (points.length / 6).ceil());
    LineChartBarData line(List<FlSpot> spots, Color color) => LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 3,
      isCurved: false,
      dotData: FlDotData(show: points.length <= 31),
    );
    return Card(
      key: AnalyticsKeys.chart,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.analyticsChartTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                _Legend(color: viewsColor, label: l10n.analyticsViews),
                _Legend(color: qrColor, label: l10n.analyticsQrVisits),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: l10n.analyticsChartSemantics(
                summary.views,
                summary.qrVisits,
                short.format(dateOfKey(summary.range.start)),
                short.format(dateOfKey(summary.range.end)),
              ),
              excludeSemantics: true,
              child: SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY.toDouble(),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: yInterval.toDouble(),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: yInterval.toDouble(),
                          getTitlesWidget: (value, meta) {
                            if (value != value.roundToDouble()) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                count.format(value.round()),
                                style: theme.textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final i = value.round();
                            if (i < 0 || i >= points.length || i % step != 0) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                short.format(dateOfKey(points[i].date)),
                                style: theme.textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      line([
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].views.toDouble()),
                      ], viewsColor),
                      line([
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].qrVisits.toDouble()),
                      ], qrColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 16, height: 4, color: color),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _TopList extends StatelessWidget {
  const _TopList({super.key, required this.title, required this.entries});

  final String title;
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Text(l10n.analyticsTopEmpty, style: theme.textTheme.bodyMedium)
            else
              for (final (i, (name, count)) in entries.indexed)
                ListTile(
                  contentPadding: EdgeInsetsDirectional.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${i + 1}', style: theme.textTheme.labelMedium),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(count),
                ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.historyDays});

  final int historyDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: AnalyticsKeys.upgrade,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.analyticsUpgradeTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.analyticsUpgradeMessage(historyDays),
              style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: 12),
            AppPrimaryButton(
              label: l10n.analyticsUpgradeAction,
              icon: Icons.workspace_premium_outlined,
              onPressed: () => context.go(Routes.plan),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

/// The smallest of 1, 2, 5, 10, 20, 50, ... that is at least [raw]: a
/// whole-number axis step for count data.
int _niceStep(double raw) {
  var magnitude = 1;
  while (true) {
    for (final m in const [1, 2, 5]) {
      if (m * magnitude >= raw) return m * magnitude;
    }
    magnitude *= 10;
  }
}
