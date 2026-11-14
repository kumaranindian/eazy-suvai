import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/draft_autosave.dart';
import '../data/restaurant_repository.dart';
import 'opening_hours_editor.dart';
import 'save_status.dart';

/// Opening hours (M03, FR-011): per weekday up to 3 slots, or closed.
/// Valid changes autosave to the draft.
class OpeningHoursPage extends ConsumerWidget {
  const OpeningHoursPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(currentRestaurantProvider)
        .when(
          loading: () => const Scaffold(body: LoadingState()),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: Text(l10n.hoursTitle)),
            body: ErrorState(
              message: CoreLocalizations.of(context).messageForError(e),
            ),
          ),
          data: (r) => r == null
              ? Scaffold(
                  body: ErrorState(
                    message: CoreLocalizations.of(context).errorNotFound,
                  ),
                )
              : _HoursEditorPage(restaurant: r),
        );
  }
}

class _HoursEditorPage extends ConsumerStatefulWidget {
  const _HoursEditorPage({required this.restaurant});

  final Restaurant restaurant;

  @override
  ConsumerState<_HoursEditorPage> createState() => _HoursEditorPageState();
}

class _HoursEditorPageState extends ConsumerState<_HoursEditorPage> {
  static const removeKey = ValueKey('hours.removeAll');

  late OpeningHours? _hours = widget.restaurant.openingHours;
  Map<Weekday, HoursIssue> _issues = const {};

  DraftAutosave get _autosave => ref.read(draftAutosaveProvider.notifier);

  void _set(OpeningHours? hours) {
    setState(() {
      _hours = hours;
      _issues = hours?.validate() ?? const {};
    });
    _autosave.setInvalid('hours', invalid: _issues.isNotEmpty);
    if (_issues.isEmpty) {
      _autosave.stage(RestaurantFields.openingHours, hours?.toWire());
    }
  }

  Future<void> _removeAll() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l10n.hoursRemoveAllTitle,
      message: l10n.hoursRemoveAllMessage,
      confirmLabel: l10n.hoursRemoveAll,
      destructive: true,
    );
    if (ok) _set(null);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(draftAutosaveProvider);
    final l10n = AppLocalizations.of(context);
    final breakpoint = Breakpoint.of(context);
    final hours = _hours;
    final zone = widget.restaurant.timezone;

    final content = hours == null
        ? EmptyState(
            icon: Icons.schedule,
            title: l10n.hoursNotSet,
            message: l10n.hoursEmptyMessage,
            actionLabel: l10n.hoursAdd,
            onAction: () => _set(OpeningHours.template()),
          )
        : SingleChildScrollView(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: breakpoint.isCompact ? 16 : 24,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.hoursIntro(zone),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                OpeningHoursEditor(
                  value: hours,
                  issues: _issues,
                  useSheets: breakpoint.isCompact,
                  onChanged: _set,
                  onFieldValidity: (id, valid) =>
                      _autosave.setInvalid('hours.$id', invalid: !valid),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: removeKey,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.hoursRemoveAll),
                    onPressed: _removeAll,
                  ),
                ),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hoursTitle),
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
          child: content,
        ),
      ),
      bottomNavigationBar: breakpoint.isCompact ? const SaveBar() : null,
    );
  }
}
