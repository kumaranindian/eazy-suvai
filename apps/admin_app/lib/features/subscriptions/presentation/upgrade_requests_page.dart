import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/admin_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/read_only.dart';

/// Keys, for tests.
abstract final class UpgradeKeys {
  static const table = ValueKey('upgrades.table');
  static const empty = ValueKey('upgrades.empty');
  static const status = ValueKey('upgrades.status');
  static ValueKey<String> record(String id) => ValueKey('upgrades.record.$id');
  static ValueKey<String> decline(String id) =>
      ValueKey('upgrades.decline.$id');
  static const amount = ValueKey('payment.amount');
  static const reference = ValueKey('payment.reference');
  static const method = ValueKey('payment.method');
  static const startAt = ValueKey('payment.startAt');
  static const endAt = ValueKey('payment.endAt');
  static const submit = ValueKey('payment.submit');
  static const reason = ValueKey('decline.reason');
  static const declineSubmit = ValueKey('decline.submit');
}

/// The request status shown (M10).
class UpgradeStatusChoice extends Notifier<String> {
  @override
  String build() => 'pending';

  // ignore: use_setters_to_change_properties
  void set(String value) => state = value;
}

final upgradeStatusProvider = NotifierProvider<UpgradeStatusChoice, String>(
  UpgradeStatusChoice.new,
);

/// `adminListUpgradeRequests` for the chosen status.
final upgradeRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final status = ref.watch(upgradeStatusProvider);
      final r = await ref.watch(adminApiProvider).call(
        'adminListUpgradeRequests',
        {'status': status},
      );
      return listOf(r['requests']);
    });

const paymentMethods = [
  'bank-transfer',
  'upi',
  'cash',
  'cheque',
  'card',
  'other',
];

/// Upgrade requests (M10, FR-106, §5.5, AC-030): the queue of owner
/// requests, "Record payment" (activates the plan) and "Decline". A table
/// from 600 px; read-only cards below.
class UpgradeRequestsPage extends ConsumerWidget {
  const UpgradeRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final status = ref.watch(upgradeStatusProvider);
    final requests = ref.watch(upgradeRequestsProvider);
    final readOnly = adminReadOnly(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String date(Object? v) {
      final d = dateOf(v);
      return d == null
          ? '–'
          : DateFormat.yMMMd(locale).add_Hm().format(d.toLocal());
    }

    String billing(Object? b) =>
        b == 'monthly' ? l10n.billingMonthly : l10n.billingAnnual;

    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        if (readOnly) ...[const ReadOnlyNotice(), const SizedBox(height: 12)],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SegmentedButton<String>(
            key: UpgradeKeys.status,
            segments: [
              ButtonSegment(
                value: 'pending',
                label: Text(l10n.upgradesPending),
              ),
              ButtonSegment(
                value: 'activated',
                label: Text(l10n.upgradesActivated),
              ),
              ButtonSegment(value: 'closed', label: Text(l10n.upgradesClosed)),
            ],
            selected: {status},
            onSelectionChanged: (s) =>
                ref.read(upgradeStatusProvider.notifier).set(s.first),
          ),
        ),
        const SizedBox(height: 16),
        requests.when(
          loading: () => const SizedBox(height: 200, child: LoadingState()),
          error: (e, _) => ErrorState(message: core.messageForError(e)),
          data: (list) {
            if (list.isEmpty) {
              return SizedBox(
                key: UpgradeKeys.empty,
                height: 240,
                child: EmptyState(
                  icon: Icons.inbox_outlined,
                  title: l10n.upgradesEmpty,
                ),
              );
            }
            if (readOnly) {
              return Column(
                children: [
                  for (final r in list)
                    Card(
                      child: ListTile(
                        title: Text('${r['restaurantName']}'),
                        subtitle: Text(
                          '${r['ownerEmail'] ?? ''}\n${r['currentPlanId']} → ${r['requestedPlanId']} · ${billing(r['billing'])} · ${date(r['createdAt'])}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
              );
            }
            return Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  key: UpgradeKeys.table,
                  columns: [
                    DataColumn(label: Text(l10n.colRestaurant)),
                    DataColumn(label: Text(l10n.colContact)),
                    DataColumn(label: Text(l10n.colPlan)),
                    DataColumn(label: Text(l10n.colBilling)),
                    DataColumn(label: Text(l10n.colRequested)),
                    if (status == 'pending')
                      DataColumn(label: Text(l10n.colActions)),
                  ],
                  rows: [
                    for (final r in list)
                      DataRow(
                        cells: [
                          DataCell(Text('${r['restaurantName']}')),
                          DataCell(
                            Text(
                              '${r['ownerEmail'] ?? ''}\n${r['ownerMobile'] ?? ''}',
                            ),
                          ),
                          DataCell(
                            Text(
                              '${r['currentPlanId']} → ${r['requestedPlanId']}',
                            ),
                          ),
                          DataCell(Text(billing(r['billing']))),
                          DataCell(Text(date(r['createdAt']))),
                          if (status == 'pending')
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FilledButton(
                                    key: UpgradeKeys.record('${r['id']}'),
                                    onPressed: () => _record(context, ref, r),
                                    child: Text(l10n.recordPayment),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    key: UpgradeKeys.decline('${r['id']}'),
                                    onPressed: () => _decline(context, ref, r),
                                    child: Text(l10n.decline),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _record(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> request,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => RecordPaymentDialog(
        restaurantId: '${request['restaurantId']}',
        restaurantName: '${request['restaurantName']}',
        planId: '${request['requestedPlanId']}',
        billing: request['billing'] == 'monthly' ? 'monthly' : 'annual',
        currency: (request['currency'] as String?) ?? 'INR',
        requestId: '${request['id']}',
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.paymentRecorded)));
      ref.invalidate(upgradeRequestsProvider);
    }
  }

  Future<void> _decline(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> request,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeclineDialog(requestId: '${request['id']}'),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.requestDeclined)));
      ref.invalidate(upgradeRequestsProvider);
    }
  }
}

/// Records an offline payment and activates the plan (FR-106). Dates are
/// prefilled: today, plus one month or one year by billing.
class RecordPaymentDialog extends ConsumerStatefulWidget {
  const RecordPaymentDialog({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.planId,
    required this.billing,
    required this.currency,
    this.requestId,
    this.today,
  });

  final String restaurantId;
  final String restaurantName;
  final String planId;
  final String billing;
  final String currency;
  final String? requestId;

  /// For tests.
  final DateTime? today;

  @override
  ConsumerState<RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  late String _billing = widget.billing;
  late String _currency = widget.currency;
  String _method = 'bank-transfer';
  late DateTime _paidAt;
  late DateTime _startAt;
  late DateTime _endAt;
  bool _saving = false;
  String? _error;

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  DateTime _endFor(DateTime start, String billing) => billing == 'monthly'
      ? DateTime.utc(start.year, start.month + 1, start.day)
      : DateTime.utc(start.year + 1, start.month, start.day);

  @override
  void initState() {
    super.initState();
    final today = _day(widget.today ?? DateTime.now());
    _paidAt = today;
    _startAt = today;
    _endAt = _endFor(today, _billing);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.utc(2020),
    lastDate: DateTime.utc(2100),
  ).then((d) => d == null ? null : _day(d));

  Future<void> _submit() async {
    final core = CoreLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    final minor = parsePriceMinor(_amount.text, Currencies.of(_currency));
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminApiProvider).call('recordPaymentAndActivate', {
        'restaurantId': widget.restaurantId,
        'planId': widget.planId,
        'billing': _billing,
        'amountMinor': minor,
        'currency': _currency,
        'method': _method,
        'reference': _reference.text.trim(),
        'paidAt': _iso(_paidAt),
        'startAt': _iso(_startAt),
        'endAt': _iso(_endAt),
        'requestId': ?widget.requestId,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = core.messageForError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat.yMMMd(locale);
    Widget dateField(
      Key key,
      String label,
      DateTime value,
      ValueChanged<DateTime> onPicked,
    ) => ListTile(
      key: key,
      contentPadding: EdgeInsetsDirectional.zero,
      title: Text(label),
      subtitle: Text(fmt.format(value)),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: () async {
        final d = await _pick(value);
        if (d != null) setState(() => onPicked(d));
      },
    );
    return AlertDialog(
      title: Text(l10n.recordPaymentTitle(widget.restaurantName)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.recordPaymentPlan(widget.planId)),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'monthly',
                      label: Text(l10n.billingMonthly),
                    ),
                    ButtonSegment(
                      value: 'annual',
                      label: Text(l10n.billingAnnual),
                    ),
                  ],
                  selected: {_billing},
                  onSelectionChanged: (s) => setState(() {
                    _billing = s.first;
                    _endAt = _endFor(_startAt, _billing);
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: UpgradeKeys.amount,
                        controller: _amount,
                        decoration: InputDecoration(
                          labelText: l10n.paymentAmount,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        validator: (v) {
                          final m = parsePriceMinor(
                            v ?? '',
                            Currencies.of(_currency),
                          );
                          return m == null || m <= 0
                              ? l10n.paymentAmountInvalid
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: InputDecoration(
                          labelText: l10n.paymentCurrency,
                        ),
                        items: [
                          for (final c in {
                            ...Currencies.all.map((c) => c.code),
                            _currency,
                          })
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) =>
                            setState(() => _currency = v ?? _currency),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: UpgradeKeys.method,
                  value: _method,
                  decoration: InputDecoration(labelText: l10n.paymentMethod),
                  items: [
                    for (final m in paymentMethods)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          l10n.paymentMethodName(
                            m == 'bank-transfer' ? 'bankTransfer' : m,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _method = v ?? _method),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: UpgradeKeys.reference,
                  controller: _reference,
                  decoration: InputDecoration(labelText: l10n.paymentReference),
                  maxLength: 200,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? l10n.fieldRequired : null,
                ),
                dateField(
                  const ValueKey('payment.paidAt'),
                  l10n.paymentPaidAt,
                  _paidAt,
                  (d) => _paidAt = d,
                ),
                dateField(UpgradeKeys.startAt, l10n.paymentStartAt, _startAt, (
                  d,
                ) {
                  _startAt = d;
                  _endAt = _endFor(d, _billing);
                }),
                dateField(
                  UpgradeKeys.endAt,
                  l10n.paymentEndAt,
                  _endAt,
                  (d) => _endAt = d,
                ),
                TextFormField(
                  controller: _note,
                  decoration: InputDecoration(labelText: l10n.paymentNote),
                  maxLength: 1000,
                ),
                if (_error != null) FormMessage(_error!),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: UpgradeKeys.submit,
          onPressed: _saving ? null : _submit,
          child: Text(l10n.recordAndActivate),
        ),
      ],
    );
  }
}

class _DeclineDialog extends ConsumerStatefulWidget {
  const _DeclineDialog({required this.requestId});

  final String requestId;

  @override
  ConsumerState<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends ConsumerState<_DeclineDialog> {
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final valid = _reason.text.trim().length >= 3;
    return AlertDialog(
      title: Text(l10n.declineTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: UpgradeKeys.reason,
              controller: _reason,
              decoration: InputDecoration(
                labelText: l10n.reasonLabel,
                helperText: l10n.reasonHelp,
              ),
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) FormMessage(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: UpgradeKeys.declineSubmit,
          onPressed: !valid || _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  try {
                    await ref.read(adminApiProvider).call(
                      'closeUpgradeRequest',
                      {
                        'requestId': widget.requestId,
                        'reason': _reason.text.trim(),
                      },
                    );
                    if (context.mounted) Navigator.of(context).pop(true);
                  } catch (e) {
                    setState(() {
                      _saving = false;
                      _error = core.messageForError(e);
                    });
                  }
                },
          child: Text(l10n.decline),
        ),
      ],
    );
  }
}
