import 'package:core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'opening_hours_summary.dart';

/// Keys, for tests.
abstract final class HoursKeys {
  static ValueKey<String> open(Weekday d) => ValueKey('hours.${d.key}.open');
  static ValueKey<String> add(Weekday d) => ValueKey('hours.${d.key}.add');
  static ValueKey<String> copy(Weekday d) => ValueKey('hours.${d.key}.copy');
  static ValueKey<String> slot(Weekday d, int i) =>
      ValueKey('hours.${d.key}.$i');
  static ValueKey<String> opens(Weekday d, int i) =>
      ValueKey('hours.${d.key}.$i.opens');
  static ValueKey<String> closes(Weekday d, int i) =>
      ValueKey('hours.${d.key}.$i.closes');
  static ValueKey<String> remove(Weekday d, int i) =>
      ValueKey('hours.${d.key}.$i.remove');
  static const sheetOpens = ValueKey('hours.sheet.opens');
  static const sheetCloses = ValueKey('hours.sheet.closes');
  static const sheetDone = ValueKey('hours.sheet.done');
}

/// Edits a week of opening hours (FR-011): per weekday open or closed, and
/// up to 3 time slots.
///
/// With [useSheets] (compact windows) each slot is a button that opens time
/// pickers in a bottom sheet; otherwise slots are inline `HH:mm` fields.
class OpeningHoursEditor extends StatelessWidget {
  const OpeningHoursEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.useSheets,
    this.issues = const {},
    this.onFieldValidity,
  });

  final OpeningHours value;
  final ValueChanged<OpeningHours> onChanged;
  final bool useSheets;
  final Map<Weekday, HoursIssue> issues;

  /// Inline fields report text that is not a valid time (yet).
  final void Function(String fieldId, bool valid)? onFieldValidity;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final d in Weekday.values)
        _DayEditor(
          day: d,
          slots: value[d],
          issue: issues[d],
          useSheets: useSheets,
          onChanged: (slots) => onChanged(value.withDay(d, slots)),
          onCopyToAll: () => onChanged(
            OpeningHours({for (final other in Weekday.values) other: value[d]}),
          ),
          onFieldValidity: onFieldValidity,
        ),
    ],
  );
}

class _DayEditor extends StatelessWidget {
  const _DayEditor({
    required this.day,
    required this.slots,
    required this.issue,
    required this.useSheets,
    required this.onChanged,
    required this.onCopyToAll,
    required this.onFieldValidity,
  });

  final Weekday day;
  final List<TimeSlot> slots;
  final HoursIssue? issue;
  final bool useSheets;
  final ValueChanged<List<TimeSlot>> onChanged;
  final VoidCallback onCopyToAll;
  final void Function(String fieldId, bool valid)? onFieldValidity;

  /// A new slot after the last one: one hour later, two hours long.
  TimeSlot _nextSlot() {
    if (slots.isEmpty) return const TimeSlot(9 * 60, 22 * 60);
    final start = (slots.last.end + 60).clamp(0, 22 * 60) % 1440;
    return TimeSlot(start, (start + 120) % 1440);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final dayName = day.label(core);
    final open = slots.isNotEmpty;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(dayName, style: theme.textTheme.titleSmall)),
              Text(open ? l10n.hoursOpen : l10n.hoursClosed),
              const SizedBox(width: 8),
              Semantics(
                label: l10n.hoursOpenOn(dayName),
                child: Switch(
                  key: HoursKeys.open(day),
                  value: open,
                  onChanged: (v) => onChanged(v ? [_nextSlot()] : const []),
                ),
              ),
              AppIconButton(
                key: HoursKeys.copy(day),
                icon: Icons.copy_all_outlined,
                semanticLabel: l10n.hoursCopyToAll(dayName),
                onPressed: onCopyToAll,
              ),
            ],
          ),
          if (open)
            for (final (i, slot) in slots.indexed)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: useSheets
                          ? _SheetSlotButton(
                              key: HoursKeys.slot(day, i),
                              dayName: dayName,
                              slot: slot,
                              onChanged: (s) => onChanged([...slots]..[i] = s),
                            )
                          : _InlineSlot(
                              day: day,
                              index: i,
                              slot: slot,
                              onChanged: (s) => onChanged([...slots]..[i] = s),
                              onFieldValidity: onFieldValidity,
                            ),
                    ),
                    AppIconButton(
                      key: HoursKeys.remove(day, i),
                      icon: Icons.remove_circle_outline,
                      semanticLabel: l10n.hoursRemoveSlot,
                      onPressed: () => onChanged([...slots]..removeAt(i)),
                    ),
                  ],
                ),
              ),
          if (open && slots.length < OpeningHours.maxSlots)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: HoursKeys.add(day),
                icon: const Icon(Icons.add),
                label: Text(l10n.hoursAddSlot),
                onPressed: () => onChanged([...slots, _nextSlot()]),
              ),
            ),
          if (issue != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  issue!.message(core),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

/// Compact: the slot as a button; tapping opens the time pickers in a
/// bottom sheet.
class _SheetSlotButton extends StatelessWidget {
  const _SheetSlotButton({
    super.key,
    required this.dayName,
    required this.slot,
    required this.onChanged,
  });

  final String dayName;
  final TimeSlot slot;
  final ValueChanged<TimeSlot> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: AlignmentDirectional.centerStart,
      ),
      icon: const Icon(Icons.schedule),
      label: Text(formatDaySlots(l10n, [slot])),
      onPressed: () async {
        final result = await showModalBottomSheet<TimeSlot>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _SlotSheet(dayName: dayName, initial: slot),
        );
        if (result != null) onChanged(result);
      },
    );
  }
}

class _SlotSheet extends StatefulWidget {
  const _SlotSheet({required this.dayName, required this.initial});

  final String dayName;
  final TimeSlot initial;

  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  late TimeSlot _slot = widget.initial;

  static const _step = 5;

  DateTime _at(Minutes m) {
    final rounded = (m ~/ _step) * _step;
    return DateTime(2000, 1, 1, rounded ~/ 60, rounded % 60);
  }

  Widget _picker(
    Key key,
    String label,
    Minutes value,
    ValueChanged<Minutes> onChanged,
  ) => Expanded(
    child: Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        SizedBox(
          height: 180,
          child: CupertinoDatePicker(
            key: key,
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            minuteInterval: _step,
            initialDateTime: _at(value),
            onDateTimeChanged: (t) => onChanged(t.hour * 60 + t.minute),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.hoursSheetTitle(widget.dayName),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l10n.hoursOvernightHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(
              children: [
                _picker(
                  HoursKeys.sheetOpens,
                  l10n.hoursOpens,
                  _slot.open,
                  (m) => setState(() => _slot = _slot.copyWith(open: m)),
                ),
                const SizedBox(width: 16),
                _picker(
                  HoursKeys.sheetCloses,
                  l10n.hoursCloses,
                  _slot.close,
                  (m) => setState(() => _slot = _slot.copyWith(close: m)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              key: HoursKeys.sheetDone,
              label: l10n.actionDone,
              expand: true,
              onPressed: () => Navigator.of(context).pop(_slot),
            ),
          ],
        ),
      ),
    );
  }
}

/// Medium and expanded: "Opens" and "Closes" as `HH:mm` fields.
class _InlineSlot extends StatelessWidget {
  const _InlineSlot({
    required this.day,
    required this.index,
    required this.slot,
    required this.onChanged,
    required this.onFieldValidity,
  });

  final Weekday day;
  final int index;
  final TimeSlot slot;
  final ValueChanged<TimeSlot> onChanged;
  final void Function(String fieldId, bool valid)? onFieldValidity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _TimeField(
            key: HoursKeys.opens(day, index),
            label: l10n.hoursOpens,
            value: slot.open,
            onChanged: (m) => onChanged(slot.copyWith(open: m)),
            onValidity: (ok) =>
                onFieldValidity?.call('${day.key}.$index.opens', ok),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TimeField(
            key: HoursKeys.closes(day, index),
            label: l10n.hoursCloses,
            value: slot.close,
            onChanged: (m) => onChanged(slot.copyWith(close: m)),
            onValidity: (ok) =>
                onFieldValidity?.call('${day.key}.$index.closes', ok),
          ),
        ),
      ],
    );
  }
}

class _TimeField extends StatefulWidget {
  const _TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onValidity,
  });

  final String label;
  final Minutes value;
  final ValueChanged<Minutes> onChanged;
  final ValueChanged<bool> onValidity;

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late final _controller = TextEditingController(
    text: formatHhMm(widget.value),
  );
  bool _valid = true;

  @override
  void didUpdateWidget(_TimeField old) {
    super.didUpdateWidget(old);
    // Follow outside changes (copy to all days), not our own edits.
    if (parseHhMm(_controller.text) != widget.value && _valid) {
      _controller.text = formatHhMm(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final m = parseHhMm(text);
    final valid = m != null;
    if (valid != _valid) {
      setState(() => _valid = valid);
      widget.onValidity(valid);
    }
    if (m != null) widget.onChanged(m);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: TextInputType.datetime,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
      LengthLimitingTextInputFormatter(5),
    ],
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: 'HH:mm',
      errorText: _valid ? null : AppLocalizations.of(context).hoursTimeFormat,
    ),
    onChanged: _changed,
  );
}
