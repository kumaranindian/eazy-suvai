import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// `07:00–11:00, 18:00–23:30`, "Closed" or "Open 24 hours".
String formatDaySlots(AppLocalizations l10n, List<TimeSlot> slots) {
  if (slots.isEmpty) return l10n.hoursClosed;
  if (slots.length == 1 && slots.single.isAllDay) return l10n.hoursAllDay;
  return slots
      .map((s) => '${formatHhMm(s.open)}–${formatHhMm(s.close)}')
      .join(', ');
}

/// Read-only list of the week's opening hours.
class OpeningHoursSummary extends StatelessWidget {
  const OpeningHoursSummary({super.key, required this.hours});

  final OpeningHours? hours;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final h = hours;
    if (h == null) return Text(l10n.hoursNotSet);
    return Column(
      children: [
        for (final d in Weekday.values)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 112, child: Text(d.label(core))),
                Expanded(child: Text(formatDaySlots(l10n, h[d]))),
              ],
            ),
          ),
      ],
    );
  }
}
