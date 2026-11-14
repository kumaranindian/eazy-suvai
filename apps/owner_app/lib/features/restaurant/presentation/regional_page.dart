import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/generated/app_localizations.dart';
import '../application/draft_autosave.dart';
import '../data/restaurant_repository.dart';
import 'save_status.dart';

/// Keys, for tests.
abstract final class RegionalKeys {
  /// Prefix of the currency dropdown's key.
  static const currency = ValueKey('regional.currency');
  static const timezone = ValueKey('regional.timezone');
  static const timezoneSearch = ValueKey('regional.timezone.search');
  static const pricesBanner = ValueKey('regional.pricesNeedReview');
}

/// "UTC+05:30" for [zone] now.
String utcOffsetLabel(String zone, {DateTime? now}) {
  try {
    final offset = TimeService(
      clock: now == null ? null : () => now,
    ).nowIn(zone).timeZoneOffset;
    final sign = offset.isNegative ? '−' : '+';
    final minutes = offset.inMinutes.abs();
    final hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final mm = (minutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hh:$mm';
  } on Object {
    return '';
  }
}

/// Currency and time zone (M03, FR-011, FR-103, §6.2–6.4).
///
/// The country is set at sign-up and shown read-only. Changing the currency
/// after the first publish (or once items have prices) asks for
/// confirmation, because prices are stored in minor units and are not
/// converted. After a publish, `onRestaurantUpdated` then sets
/// `pricesNeedReview` and M06 asks the owner to confirm before publishing.
class RegionalPage extends ConsumerStatefulWidget {
  const RegionalPage({super.key});

  @override
  ConsumerState<RegionalPage> createState() => _RegionalPageState();
}

class _RegionalPageState extends ConsumerState<RegionalPage> {
  /// Bumped to reset the currency dropdown after a cancelled change.
  int _epoch = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(draftAutosaveProvider);
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final breakpoint = Breakpoint.of(context);
    final restaurant = ref.watch(currentRestaurantProvider);

    final Widget body = restaurant.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: core.messageForError(e)),
      data: (r) {
        if (r == null) return ErrorState(message: core.errorNotFound);
        final country = Countries.byCode(r.country);
        return ListView(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: breakpoint.isCompact ? 16 : 24,
            vertical: 16,
          ),
          children: [
            // No room in the app bar on phones.
            if (breakpoint.isCompact) ...[
              const SaveStatusIndicator(),
              const SizedBox(height: 16),
            ],
            if (r.pricesNeedReview) ...[
              FormMessage(
                key: RegionalKeys.pricesBanner,
                l10n.regionalPricesNeedReview,
              ),
              const SizedBox(height: 16),
            ],
            FormSection(
              title: l10n.regionalSectionCountry,
              icon: Icons.flag_outlined,
              children: [
                ListTile(
                  contentPadding: EdgeInsetsDirectional.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: Text(country?.name(core) ?? r.country),
                  subtitle: Text(l10n.regionalCountryLocked),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FormSection(
              title: l10n.regionalSectionCurrency,
              icon: Icons.payments_outlined,
              subtitle: l10n.regionalCurrencyHelp,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    '${RegionalKeys.currency.value}.${r.currency}.$_epoch',
                  ),
                  value: Currencies.isKnown(r.currency) ? r.currency : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.fieldCurrency),
                  items: [
                    for (final c in Currencies.all)
                      DropdownMenuItem(
                        value: c.code,
                        child: Text(
                          l10n.currencyOption(
                            core.currencyName(c.code),
                            c.code,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (code) => _changeCurrency(r, code),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FormSection(
              title: l10n.regionalSectionTimezone,
              icon: Icons.public,
              subtitle: l10n.regionalTimezoneHelp,
              children: [
                ListTile(
                  key: RegionalKeys.timezone,
                  contentPadding: EdgeInsetsDirectional.zero,
                  title: Text(r.timezone),
                  subtitle: Text(utcOffsetLabel(r.timezone)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changeTimezone(r, country),
                ),
              ],
            ),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.regionalTitle),
        actions: [
          if (!breakpoint.isCompact)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 16),
              child: Center(child: SaveStatusIndicator()),
            ),
        ],
      ),
      body: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: body,
        ),
      ),
    );
  }

  Future<void> _changeCurrency(Restaurant r, String? code) async {
    if (code == null || code == r.currency) return;
    final l10n = AppLocalizations.of(context);
    final autosave = ref.read(draftAutosaveProvider.notifier);
    // FR-103: prices are not converted.
    if (r.isPublished || r.itemCount > 0) {
      final ok = await showConfirmDialog(
        context,
        title: l10n.currencyWarningTitle(code),
        message: r.isPublished
            ? l10n.currencyWarningPublished(r.currency, code)
            : l10n.currencyWarningDraft(r.currency, code),
        confirmLabel: l10n.currencyWarningConfirm,
      );
      if (!ok) {
        // Show the stored currency again.
        if (mounted) setState(() => _epoch++);
        return;
      }
    }
    autosave.stage(RestaurantFields.currency, code);
    await autosave.flush();
  }

  Future<void> _changeTimezone(Restaurant r, Country? country) async {
    final zone = await showTimezonePicker(
      context,
      current: r.timezone,
      suggested: country?.suggestedTimezones ?? [r.timezone],
    );
    if (zone == null || zone == r.timezone) return;
    final autosave = ref.read(draftAutosaveProvider.notifier)
      ..stage(RestaurantFields.timezone, zone);
    await autosave.flush();
  }
}

/// Lets the owner pick an IANA time zone: the country's zones first, then
/// every zone, with search. Full screen on compact windows.
Future<String?> showTimezonePicker(
  BuildContext context, {
  required String current,
  required List<String> suggested,
}) {
  final compact = Breakpoint.of(context).isCompact;
  return showDialog<String>(
    context: context,
    builder: (context) {
      final picker = _TimezonePicker(current: current, suggested: suggested);
      return compact
          ? Dialog.fullscreen(child: picker)
          : Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                  maxHeight: 640,
                ),
                child: picker,
              ),
            );
    },
  );
}

class _TimezonePicker extends StatefulWidget {
  const _TimezonePicker({required this.current, required this.suggested});

  final String current;
  final List<String> suggested;

  @override
  State<_TimezonePicker> createState() => _TimezonePickerState();
}

class _TimezonePickerState extends State<_TimezonePicker> {
  static final List<String> _all = () {
    TimeService.ensureInitialized();
    return tz.timeZoneDatabase.locations.keys
        .where((z) => z.contains('/') || z == 'UTC')
        .toList()
      ..sort();
  }();

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase().replaceAll(' ', '_');
    bool matches(String z) => q.isEmpty || z.toLowerCase().contains(q);
    final suggested = widget.suggested.where(matches).toList();
    final others = _all
        .where((z) => matches(z) && !widget.suggested.contains(z))
        .toList();

    Widget tile(String z) => ListTile(
      title: Text(z),
      subtitle: Text(utcOffsetLabel(z)),
      selected: z == widget.current,
      trailing: z == widget.current ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(z),
    );

    return Column(
      children: [
        AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.regionalTimezonePick),
          actions: [
            AppIconButton(
              icon: Icons.close,
              semanticLabel: CoreLocalizations.of(context).actionCancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: TextField(
            key: RegionalKeys.timezoneSearch,
            autofocus: !Breakpoint.of(context).isCompact,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: l10n.regionalTimezoneSearch,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: suggested.length + others.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _header(
                  context,
                  l10n.regionalTimezoneSuggested,
                  suggested.isEmpty,
                );
              }
              if (i <= suggested.length) return tile(suggested[i - 1]);
              if (i == suggested.length + 1) {
                return _header(
                  context,
                  l10n.regionalTimezoneAll,
                  others.isEmpty,
                );
              }
              return tile(others[i - suggested.length - 2]);
            },
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, String text, bool empty) => empty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleSmall),
          ),
        );
}
