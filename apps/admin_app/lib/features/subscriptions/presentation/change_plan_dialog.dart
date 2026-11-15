import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/admin_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/catalog_pages.dart';

/// Keys, for tests.
abstract final class ChangePlanKeys {
  static ValueKey<String> plan(String id) => ValueKey('changePlan.plan.$id');
  static const startAt = ValueKey('changePlan.startAt');
  static const endAt = ValueKey('changePlan.endAt');
  static const reason = ValueKey('changePlan.reason');
  static const submit = ValueKey('changePlan.submit');
}

/// Moves a restaurant to any active plan without recording a payment
/// (FR-081; `changeSubscription` with `action: 'modify'`): trials,
/// complimentary upgrades and corrections. A paid plan needs an end date in
/// the future; a free plan needs none. The server audits the change with
/// the reason, restores hidden content on higher limits and applies the new
/// limits on lower ones.
class ChangePlanDialog extends ConsumerStatefulWidget {
  const ChangePlanDialog({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.currentPlanId,
    this.today,
  });

  final String restaurantId;
  final String restaurantName;
  final String currentPlanId;

  /// For tests.
  final DateTime? today;

  @override
  ConsumerState<ChangePlanDialog> createState() => _ChangePlanDialogState();
}

class _ChangePlanDialogState extends ConsumerState<ChangePlanDialog> {
  final _reason = TextEditingController();
  String? _planId;
  late DateTime _today;
  late DateTime _startAt;
  late DateTime _endAt;
  bool _saving = false;
  String? _error;

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _today = _day(widget.today ?? DateTime.now());
    _startAt = _today;
    _endAt = DateTime.utc(_today.year, _today.month + 1, _today.day);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.utc(2020),
    lastDate: DateTime.utc(2100),
  ).then((d) => d == null ? null : _day(d));

  bool get _datesValid => _endAt.isAfter(_startAt) && _endAt.isAfter(_today);

  Future<void> _submit(bool toFree) async {
    final core = CoreLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminApiProvider).call('changeSubscription', {
        'action': 'modify',
        'restaurantId': widget.restaurantId,
        'planId': _planId,
        if (!toFree) 'startAt': _iso(_startAt),
        if (!toFree) 'expiresAt': _iso(_endAt),
        'reason': _reason.text.trim(),
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
    final core = CoreLocalizations.of(context);
    final fmt = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final plans = ref.watch(catalogProvider('plans'));
    final all = plans.value ?? const <Map<String, dynamic>>[];
    String nameOf(String id) =>
        '${all.where((p) => p['id'] == id).firstOrNull?['name'] ?? id}';
    final choices =
        all
            .where(
              (p) => p['active'] == true && p['id'] != widget.currentPlanId,
            )
            .toList()
          ..sort(
            (a, b) =>
                ((a['sort'] as num?) ?? 0).compareTo((b['sort'] as num?) ?? 0),
          );
    final chosen = choices.where((p) => p['id'] == _planId).firstOrNull;
    final toFree = chosen?['isFree'] == true;
    final reasonOk = _reason.text.trim().length >= 3;
    final canSubmit =
        !_saving && chosen != null && reasonOk && (toFree || _datesValid);

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

    final Widget body = switch (plans) {
      AsyncValue(isLoading: true, hasValue: false) => const Padding(
        padding: EdgeInsetsDirectional.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      AsyncValue(:final error?, hasValue: false) => FormMessage(
        core.messageForError(error),
      ),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.changePlanCurrent(nameOf(widget.currentPlanId))),
          const SizedBox(height: 12),
          if (choices.isEmpty)
            Text(l10n.changePlanNoOther)
          else ...[
            Text(
              l10n.changePlanNew,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in choices)
                  ChoiceChip(
                    key: ChangePlanKeys.plan('${p['id']}'),
                    label: Text('${p['name'] ?? p['id']}'),
                    selected: _planId == p['id'],
                    onSelected: (_) => setState(() => _planId = '${p['id']}'),
                  ),
              ],
            ),
          ],
          if (chosen != null) ...[
            const SizedBox(height: 8),
            Text(toFree ? l10n.changePlanFreeNote : l10n.changePlanPaidNote),
            if (!toFree) ...[
              dateField(
                ChangePlanKeys.startAt,
                l10n.paymentStartAt,
                _startAt,
                (d) => _startAt = d,
              ),
              dateField(
                ChangePlanKeys.endAt,
                l10n.paymentEndAt,
                _endAt,
                (d) => _endAt = d,
              ),
              if (!_datesValid) FormMessage(l10n.changePlanEndInvalid),
            ],
            const SizedBox(height: 8),
            TextField(
              key: ChangePlanKeys.reason,
              controller: _reason,
              maxLength: 1000,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.reasonLabel,
                helperText: l10n.reasonHelp,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_error != null) FormMessage(_error!),
        ],
      ),
    };

    return AlertDialog(
      title: Text(l10n.changePlanTitle(widget.restaurantName)),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: body)),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: ChangePlanKeys.submit,
          onPressed: canSubmit ? () => _submit(toFree) : null,
          child: Text(l10n.changePlan),
        ),
      ],
    );
  }
}
