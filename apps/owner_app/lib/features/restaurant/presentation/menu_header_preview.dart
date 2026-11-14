import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Live mini-preview of the public menu's header (M03): cover, logo, name,
/// business type, description and the contact details the owner chose to
/// show (FR-013, FR-014). Hidden groups are listed underneath so the owner
/// sees the effect of each toggle. M07 renders the real page.
class MenuHeaderPreview extends StatelessWidget {
  const MenuHeaderPreview({super.key, required this.restaurant, this.now});

  final Restaurant restaurant;

  /// Instant used for "today" (tests).
  final DateTime? now;

  static const width = 360.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final r = restaurant;
    final v = r.visibility;
    final c = r.contact;
    final today = _today();
    final todaySlots = r.openingHours?[today];
    final hidden = [
      for (final f in VisibleField.values)
        if (!v.isShown(f)) visibleFieldLabel(l10n, f),
    ];

    final details = <(IconData, String)>[
      if (v.isShown(VisibleField.phone) && c.phone != null)
        (Icons.phone_outlined, c.phone!),
      if (v.isShown(VisibleField.email) && c.email != null)
        (Icons.mail_outline, c.email!),
      if (v.isShown(VisibleField.address) && _address(r).isNotEmpty)
        (Icons.place_outlined, _address(r)),
      if (v.isShown(VisibleField.hours) && todaySlots != null)
        (
          Icons.schedule,
          todaySlots.isEmpty
              ? l10n.previewClosedToday
              : l10n.previewHoursToday(todaySlots.map(_slotText).join(', ')),
        ),
    ];
    final social = v.isShown(VisibleField.social)
        ? c.social.keys.toList()
        : const <SocialNetwork>[];

    return Semantics(
      container: true,
      label: l10n.previewTitle,
      child: Card.outlined(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsetsDirectional.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
              child: Text(
                l10n.previewTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              height: 168,
              child: Stack(
                children: [
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    top: 0,
                    height: 120,
                    child: ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: r.cover == null
                          ? const SizedBox.expand()
                          : ResponsiveImage(
                              image: r.cover,
                              semanticLabel: l10n.fieldCover,
                            ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 16,
                    top: 72,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 4,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ResponsiveImage(
                        image: r.logo,
                        semanticLabel: l10n.fieldLogo,
                        placeholderIcon: Icons.storefront_outlined,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name.trim().isEmpty ? l10n.previewNoName : r.name,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (r.businessType != null)
                    Text(
                      r.businessType!.label(core),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (r.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      r.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  for (final (icon, text) in details) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(child: Icon(icon, size: 18)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(text)),
                      ],
                    ),
                  ],
                  if (social.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final n in social)
                          Chip(label: Text(n.label(core))),
                      ],
                    ),
                  ],
                  if (hidden.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.previewHidden(hidden.join(', ')),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Weekday _today() {
    try {
      final service = TimeService(clock: now == null ? null : () => now!);
      return Weekday.fromIso(service.nowIn(restaurant.timezone).weekday);
    } on Object {
      return Weekday.fromIso(DateTime.now().weekday);
    }
  }

  static String _slotText(TimeSlot s) => s.isAllDay
      ? '00:00–24:00'
      : '${formatHhMm(s.open)}–${formatHhMm(s.close)}';

  static String _address(Restaurant r) => [
    r.contact.address,
    r.contact.city,
    r.contact.postalCode,
  ].whereType<String>().join(', ');
}

/// Localized name of a visibility group (FR-013).
String visibleFieldLabel(AppLocalizations l10n, VisibleField f) => switch (f) {
  VisibleField.phone => l10n.visibilityPhone,
  VisibleField.email => l10n.visibilityEmail,
  VisibleField.address => l10n.visibilityAddress,
  VisibleField.hours => l10n.visibilityHours,
  VisibleField.social => l10n.visibilitySocial,
};
