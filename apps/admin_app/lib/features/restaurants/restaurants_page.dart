import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/admin_api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../router/app_router.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/read_only.dart';

/// Keys, for tests.
abstract final class RestaurantsKeys {
  static const search = ValueKey('restaurants.search');
  static const status = ValueKey('restaurants.status');
  static const plan = ValueKey('restaurants.plan');
  static const country = ValueKey('restaurants.country');
  static const dates = ValueKey('restaurants.dates');
  static const table = ValueKey('restaurants.table');
  static const next = ValueKey('restaurants.next');
  static const previous = ValueKey('restaurants.previous');
  static const empty = ValueKey('restaurants.empty');
  static ValueKey<String> row(String id) => ValueKey('restaurants.row.$id');
}

/// Search text, filters and the page cursor (M11, FR-086).
@immutable
class RestaurantQuery {
  const RestaurantQuery({
    this.text = '',
    this.status,
    this.planId,
    this.country,
    this.from,
    this.to,
    this.cursors = const [],
  });

  final String text;
  final String? status;
  final String? planId;
  final String? country;

  /// `yyyy-MM-dd`.
  final String? from;
  final String? to;

  /// Cursors of the pages before this one (the last is this page's cursor).
  final List<String> cursors;

  RestaurantQuery copyWith({
    String? text,
    ValueGetter<String?>? status,
    ValueGetter<String?>? planId,
    ValueGetter<String?>? country,
    ValueGetter<String?>? from,
    ValueGetter<String?>? to,
    List<String>? cursors,
  }) => RestaurantQuery(
    text: text ?? this.text,
    status: status != null ? status() : this.status,
    planId: planId != null ? planId() : this.planId,
    country: country != null ? country() : this.country,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
    // Any filter change starts again from the first page.
    cursors: cursors ?? const [],
  );

  Map<String, Object?> toCall() => {
    if (text.trim().isNotEmpty) 'query': text.trim(),
    'status': ?status,
    'planId': ?planId,
    'country': ?country,
    'createdFrom': ?from,
    'createdTo': ?to,
    'pageSize': 25,
    if (cursors.isNotEmpty) 'cursor': cursors.last,
  };

  @override
  bool operator ==(Object other) =>
      other is RestaurantQuery &&
      other.text == text &&
      other.status == status &&
      other.planId == planId &&
      other.country == country &&
      other.from == from &&
      other.to == to &&
      listEquals(other.cursors, cursors);

  @override
  int get hashCode => Object.hash(
    text,
    status,
    planId,
    country,
    from,
    to,
    Object.hashAll(cursors),
  );
}

class RestaurantQueryNotifier extends Notifier<RestaurantQuery> {
  @override
  RestaurantQuery build() => const RestaurantQuery();

  // ignore: use_setters_to_change_properties
  void set(RestaurantQuery q) => state = q;
}

final restaurantQueryProvider =
    NotifierProvider<RestaurantQueryNotifier, RestaurantQuery>(
      RestaurantQueryNotifier.new,
    );

final restaurantPageProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) {
    final q = ref.watch(restaurantQueryProvider);
    return ref
        .watch(adminApiProvider)
        .call('adminSearchRestaurants', q.toCall());
  },
);

const _countries = ['IN', 'AE', 'KW', 'SA', 'QA', 'BH', 'OM', 'US'];

/// Restaurants (M11, FR-086): search by name, slug, email or mobile;
/// filter by status, plan, country and registration date; 25 per page.
/// A table from 600 px, cards below. A row opens the detail page.
class RestaurantsPage extends ConsumerStatefulWidget {
  const RestaurantsPage({super.key});

  @override
  ConsumerState<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends ConsumerState<RestaurantsPage> {
  late final _search = TextEditingController(
    text: ref.read(restaurantQueryProvider).text,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(RestaurantQuery q) =>
      ref.read(restaurantQueryProvider.notifier).set(q);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final q = ref.watch(restaurantQueryProvider);
    final page = ref.watch(restaurantPageProvider);
    final readOnly = adminReadOnly(context);

    Widget dropdown(
      Key key,
      String label,
      String? value,
      List<(String, String)> options,
      ValueChanged<String?> onChanged,
    ) => SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        key: key,
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: null, child: Text(l10n.filterAny)),
          for (final (v, t) in options)
            DropdownMenuItem(value: v, child: Text(t)),
        ],
        onChanged: onChanged,
      ),
    );

    final filters = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            key: RestaurantsKeys.search,
            controller: _search,
            decoration: InputDecoration(
              labelText: l10n.searchRestaurants,
              prefixIcon: const Icon(Icons.search),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (t) => _update(q.copyWith(text: t)),
          ),
        ),
        dropdown(
          RestaurantsKeys.status,
          l10n.filterStatus,
          q.status,
          [
            for (final s in ['active', 'suspended', 'deactivated', 'deleted'])
              (s, l10n.statusName(s)),
          ],
          (v) => _update(q.copyWith(status: () => v)),
        ),
        dropdown(
          RestaurantsKeys.plan,
          l10n.filterPlan,
          q.planId,
          const [('free', 'Free'), ('pro', 'Pro')],
          (v) => _update(q.copyWith(planId: () => v)),
        ),
        dropdown(
          RestaurantsKeys.country,
          l10n.filterCountry,
          q.country,
          [for (final c in _countries) (c, c)],
          (v) => _update(q.copyWith(country: () => v)),
        ),
        OutlinedButton.icon(
          key: RestaurantsKeys.dates,
          icon: const Icon(Icons.date_range),
          label: Text(
            q.from == null ? l10n.filterDates : '${q.from} – ${q.to}',
          ),
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime.utc(2025),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            String iso(DateTime d) =>
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            _update(
              q.copyWith(
                from: () => picked == null ? null : iso(picked.start),
                to: () => picked == null ? null : iso(picked.end),
              ),
            );
          },
        ),
      ],
    );

    return AdminPageBody(
      children: [
        filters,
        const SizedBox(height: 16),
        page.when(
          loading: () => const SizedBox(height: 240, child: LoadingState()),
          error: (e, _) => ErrorState(message: core.messageForError(e)),
          data: (p) {
            final rows = listOf(p['rows']);
            final next = p['nextCursor'] as String?;
            if (rows.isEmpty) {
              return SizedBox(
                key: RestaurantsKeys.empty,
                height: 240,
                child: EmptyState(
                  icon: Icons.search_off,
                  title: l10n.noRestaurants,
                ),
              );
            }
            final pager = Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(l10n.pageNumber(q.cursors.length + 1)),
                const SizedBox(width: 8),
                IconButton(
                  key: RestaurantsKeys.previous,
                  tooltip: l10n.previousPage,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: q.cursors.isEmpty
                      ? null
                      : () => _update(
                          q.copyWith(
                            cursors: q.cursors.sublist(0, q.cursors.length - 1),
                          ),
                        ),
                ),
                IconButton(
                  key: RestaurantsKeys.next,
                  tooltip: l10n.nextPage,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: next == null
                      ? null
                      : () =>
                            _update(q.copyWith(cursors: [...q.cursors, next])),
                ),
              ],
            );
            if (readOnly) {
              return Column(
                children: [
                  for (final r in rows)
                    Card(
                      key: RestaurantsKeys.row('${r['id']}'),
                      child: ListTile(
                        title: Text('${r['name']}'),
                        subtitle: Text(
                          '${r['slug']} · ${r['ownerEmail'] ?? ''}\n${r['country'] ?? ''} · ${r['planId']} · ${fmtDate(context, r['createdAt'])}',
                        ),
                        isThreeLine: true,
                        trailing: StatusChip(
                          label: l10n.statusName('${r['status']}'),
                          tone: statusTone('${r['status']}'),
                        ),
                        onTap: () =>
                            context.go(Routes.restaurant('${r['id']}')),
                      ),
                    ),
                  pager,
                ],
              );
            }
            return Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      key: RestaurantsKeys.table,
                      showCheckboxColumn: false,
                      columns: [
                        DataColumn(label: Text(l10n.colRestaurant)),
                        DataColumn(label: Text(l10n.colSlug)),
                        DataColumn(label: Text(l10n.colContact)),
                        DataColumn(label: Text(l10n.colCountry)),
                        DataColumn(label: Text(l10n.colStatus)),
                        DataColumn(label: Text(l10n.colPlan)),
                        DataColumn(label: Text(l10n.colItems), numeric: true),
                        DataColumn(label: Text(l10n.colRegistered)),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            key: RestaurantsKeys.row('${r['id']}'),
                            onSelectChanged: (_) =>
                                context.go(Routes.restaurant('${r['id']}')),
                            cells: [
                              DataCell(Text('${r['name']}')),
                              DataCell(Text('${r['slug']}')),
                              DataCell(
                                Text(
                                  '${r['ownerEmail'] ?? ''}\n${r['ownerMobile'] ?? ''}',
                                ),
                              ),
                              DataCell(Text('${r['country'] ?? ''}')),
                              DataCell(
                                StatusChip(
                                  label: l10n.statusName('${r['status']}'),
                                  tone: statusTone('${r['status']}'),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${r['planId']} (${r['subscriptionStatus']})',
                                ),
                              ),
                              DataCell(Text('${r['items']}')),
                              DataCell(Text(fmtDate(context, r['createdAt']))),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.all(8),
                    child: pager,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
