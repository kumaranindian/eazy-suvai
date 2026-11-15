import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/read_only.dart';

/// Keys, for tests.
abstract final class AuditKeys {
  static const actor = ValueKey('audit.actor');
  static const action = ValueKey('audit.action');
  static const restaurant = ValueKey('audit.restaurant');
  static const dates = ValueKey('audit.dates');
  static const apply = ValueKey('audit.apply');
  static const table = ValueKey('audit.table');
  static const next = ValueKey('audit.next');
  static const detail = ValueKey('audit.detail');
  static ValueKey<String> row(String id) => ValueKey('audit.row.$id');
}

@immutable
class AuditQuery {
  const AuditQuery({
    this.actorUid,
    this.action,
    this.restaurantId,
    this.from,
    this.to,
    this.cursors = const [],
  });

  final String? actorUid;
  final String? action;
  final String? restaurantId;
  final String? from;
  final String? to;
  final List<String> cursors;

  Map<String, Object?> toCall() => {
    'actorUid': ?actorUid,
    'action': ?action,
    'restaurantId': ?restaurantId,
    'from': ?from,
    'to': ?to,
    'pageSize': 50,
    if (cursors.isNotEmpty) 'cursor': cursors.last,
  };

  AuditQuery withCursors(List<String> c) => AuditQuery(
    actorUid: actorUid,
    action: action,
    restaurantId: restaurantId,
    from: from,
    to: to,
    cursors: c,
  );

  @override
  bool operator ==(Object other) =>
      other is AuditQuery &&
      other.actorUid == actorUid &&
      other.action == action &&
      other.restaurantId == restaurantId &&
      other.from == from &&
      other.to == to &&
      listEquals(other.cursors, cursors);

  @override
  int get hashCode => Object.hash(
    actorUid,
    action,
    restaurantId,
    from,
    to,
    Object.hashAll(cursors),
  );
}

class AuditQueryNotifier extends Notifier<AuditQuery> {
  @override
  AuditQuery build() => const AuditQuery();

  // ignore: use_setters_to_change_properties
  void set(AuditQuery q) => state = q;
}

final auditQueryProvider = NotifierProvider<AuditQueryNotifier, AuditQuery>(
  AuditQueryNotifier.new,
);

final auditPageProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref
      .watch(adminApiProvider)
      .call('adminListAuditLogs', ref.watch(auditQueryProvider).toCall()),
);

/// Audit log (M12, FR-090, BR-014): filters by actor, action, restaurant and
/// dates; a table from 600 px (cards below); a detail drawer with the full
/// entry. Read-only for everyone (nobody edits the log).
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key, this.restaurantId});

  /// Pre-filter (from a restaurant's activity card).
  final String? restaurantId;

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  final _actor = TextEditingController();
  final _action = TextEditingController();
  late final _restaurant = TextEditingController(
    text: widget.restaurantId ?? '',
  );
  DateTimeRange? _dates;

  @override
  void initState() {
    super.initState();
    if (widget.restaurantId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
    }
  }

  @override
  void dispose() {
    for (final c in [_actor, _action, _restaurant]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();
  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _apply() => ref
      .read(auditQueryProvider.notifier)
      .set(
        AuditQuery(
          actorUid: _v(_actor),
          action: _v(_action),
          restaurantId: _v(_restaurant),
          from: _dates == null ? null : _iso(_dates!.start),
          to: _dates == null ? null : _iso(_dates!.end),
        ),
      );

  void _open(Map<String, dynamic> e) {
    final body = _AuditDetail(entry: e);
    if (Breakpoint.of(context).isExpanded) {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).closeButtonLabel,
        pageBuilder: (context, _, _) => Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Material(
            elevation: 8,
            child: SizedBox(width: 440, height: double.infinity, child: body),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: body),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final q = ref.watch(auditQueryProvider);
    final page = ref.watch(auditPageProvider);
    final readOnly = adminReadOnly(context);
    Widget field(Key key, TextEditingController c, String label) => SizedBox(
      width: 220,
      child: TextField(
        key: key,
        controller: c,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (_) => _apply(),
      ),
    );
    return AdminPageBody(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            field(AuditKeys.actor, _actor, l10n.auditActor),
            field(AuditKeys.action, _action, l10n.auditAction),
            field(AuditKeys.restaurant, _restaurant, l10n.auditRestaurant),
            OutlinedButton.icon(
              key: AuditKeys.dates,
              icon: const Icon(Icons.date_range),
              label: Text(
                _dates == null
                    ? l10n.filterDates
                    : '${_iso(_dates!.start)} – ${_iso(_dates!.end)}',
              ),
              onPressed: () async {
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.utc(2025),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                setState(() => _dates = r);
              },
            ),
            FilledButton.icon(
              key: AuditKeys.apply,
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(l10n.auditApply),
              onPressed: _apply,
            ),
          ],
        ),
        const SizedBox(height: 16),
        page.when(
          loading: () => const SizedBox(height: 200, child: LoadingState()),
          error: (e, _) => ErrorState(message: core.messageForError(e)),
          data: (p) {
            final entries = listOf(p['entries']);
            final next = p['nextCursor'] as String?;
            if (entries.isEmpty) {
              return SizedBox(
                height: 200,
                child: EmptyState(icon: Icons.history, title: l10n.auditEmpty),
              );
            }
            final pager = Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(l10n.pageNumber(q.cursors.length + 1)),
                IconButton(
                  tooltip: l10n.previousPage,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: q.cursors.isEmpty
                      ? null
                      : () => ref
                            .read(auditQueryProvider.notifier)
                            .set(
                              q.withCursors(
                                q.cursors.sublist(0, q.cursors.length - 1),
                              ),
                            ),
                ),
                IconButton(
                  key: AuditKeys.next,
                  tooltip: l10n.nextPage,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: next == null
                      ? null
                      : () => ref
                            .read(auditQueryProvider.notifier)
                            .set(q.withCursors([...q.cursors, next])),
                ),
              ],
            );
            if (readOnly) {
              return Column(
                children: [
                  for (final e in entries)
                    Card(
                      key: AuditKeys.row('${e['id']}'),
                      child: ListTile(
                        title: Text('${e['action']}'),
                        subtitle: Text(
                          '${fmtDate(context, e['at'], time: true)} · ${e['actorRole']} · ${e['restaurantId'] ?? e['target']}',
                        ),
                        onTap: () => _open(e),
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
                      key: AuditKeys.table,
                      showCheckboxColumn: false,
                      columns: [
                        DataColumn(label: Text(l10n.auditTime)),
                        DataColumn(label: Text(l10n.auditAction)),
                        DataColumn(label: Text(l10n.auditActor)),
                        DataColumn(label: Text(l10n.auditRestaurant)),
                        DataColumn(label: Text(l10n.fieldReason)),
                      ],
                      rows: [
                        for (final e in entries)
                          DataRow(
                            key: AuditKeys.row('${e['id']}'),
                            onSelectChanged: (_) => _open(e),
                            cells: [
                              DataCell(
                                Text(fmtDate(context, e['at'], time: true)),
                              ),
                              DataCell(Text('${e['action']}')),
                              DataCell(
                                Text('${e['actorRole']} · ${e['actorUid']}'),
                              ),
                              DataCell(Text('${e['restaurantId'] ?? '–'}')),
                              DataCell(
                                SizedBox(
                                  width: 240,
                                  child: Text(
                                    '${e['reason'] ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
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

class _AuditDetail extends StatelessWidget {
  const _AuditDetail({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget row(String label, Object? value) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          SelectableText('${value ?? '–'}'),
        ],
      ),
    );
    return SafeArea(
      key: AuditKeys.detail,
      child: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${entry['action']}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          row(l10n.auditTime, fmtDate(context, entry['at'], time: true)),
          row(l10n.auditActor, '${entry['actorRole']} · ${entry['actorUid']}'),
          row(l10n.auditRestaurant, entry['restaurantId']),
          row(l10n.auditTarget, entry['target']),
          row(l10n.fieldReason, entry['reason']),
          if (entry['anonymized'] == true)
            row(l10n.auditAnonymized, l10n.auditAnonymizedHelp),
          Text(l10n.auditDetails, style: theme.textTheme.bodySmall),
          SelectableText(
            const JsonEncoder.withIndent(
              '  ',
            ).convert(entry['details'] ?? const {}),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
