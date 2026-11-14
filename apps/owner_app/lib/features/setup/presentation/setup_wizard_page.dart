import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../restaurant/application/draft_autosave.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../../restaurant/presentation/menu_header_preview.dart';
import '../../restaurant/presentation/profile_form.dart';
import '../../restaurant/presentation/save_status.dart';

/// Keys, for tests.
abstract final class WizardKeys {
  static const next = ValueKey('wizard.next');
  static const back = ValueKey('wizard.back');
  static const skip = ValueKey('wizard.skip');
  static const toMenu = ValueKey('wizard.toMenu');
  static const toDashboard = ValueKey('wizard.toDashboard');
  static const stepper = ValueKey('wizard.stepper');
  static const progress = ValueKey('wizard.progress');
}

enum _Step { profile, images, menu }

/// First-run setup wizard (M03, FRD §5.1 steps 4–5): profile basics → logo
/// and cover → a hint about building the menu. Edits autosave to the draft
/// like the profile page. Finishing or skipping sets `setupCompletedAt`.
///
/// Compact: one step per page with a progress bar. Medium: the same in a
/// wider card. Expanded: a stepper on the left, the step in the middle and
/// a live menu-header preview on the right.
class SetupWizardPage extends ConsumerWidget {
  const SetupWizardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = CoreLocalizations.of(context);
    return ref
        .watch(currentRestaurantProvider)
        .when(
          loading: () => const Scaffold(body: LoadingState()),
          error: (e, _) =>
              Scaffold(body: ErrorState(message: core.messageForError(e))),
          data: (r) => r == null
              ? Scaffold(body: ErrorState(message: core.errorNotFound))
              : _Wizard(restaurant: r),
        );
  }
}

class _Wizard extends ConsumerStatefulWidget {
  const _Wizard({required this.restaurant});

  final Restaurant restaurant;

  @override
  ConsumerState<_Wizard> createState() => _WizardState();
}

class _WizardState extends ConsumerState<_Wizard> {
  final _formKey = GlobalKey<FormState>();
  late final ProfileFormModel _form;
  _Step _step = _Step.profile;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _form = ProfileFormModel(
      widget.restaurant,
      autosave: () => ref.read(draftAutosaveProvider.notifier),
      onChanged: () => setState(() {}),
    );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  String _title(AppLocalizations l10n, _Step s) => switch (s) {
    _Step.profile => l10n.wizardStepProfile,
    _Step.images => l10n.wizardStepImages,
    _Step.menu => l10n.wizardStepMenu,
  };

  Future<void> _next() async {
    final core = CoreLocalizations.of(context);
    if (_step == _Step.profile) {
      final valid = _formKey.currentState?.validate() ?? false;
      if (!valid || _form.businessType == null || !_form.contactValid(core)) {
        return;
      }
    }
    final autosave = ref.read(draftAutosaveProvider.notifier);
    _setBusy(true, null);
    await autosave.flush();
    if (!mounted) return;
    if (ref.read(draftAutosaveProvider).status == SaveStatus.failed) {
      _setBusy(false, AppLocalizations.of(context).saveFailed);
      return;
    }
    setState(() {
      _busy = false;
      _step = _Step.values[_step.index + 1];
    });
  }

  void _setBusy(bool busy, String? error) => setState(() {
    _busy = busy;
    _error = error;
  });

  void _back() => setState(() => _step = _Step.values[_step.index - 1]);

  Future<void> _finish(String route) async {
    _setBusy(true, null);
    try {
      await ref.read(draftAutosaveProvider.notifier).flush();
      await ref
          .read(restaurantRepositoryProvider)
          .completeSetup(widget.restaurant.id);
      if (mounted) context.go(route);
    } catch (e) {
      if (!mounted) return;
      _setBusy(false, CoreLocalizations.of(context).messageForError(e));
    }
  }

  Widget _stepContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final live = widget.restaurant;
    return switch (_step) {
      _Step.profile => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: withGaps([
            Text(l10n.wizardProfileIntro),
            _form.nameField(context),
            _form.businessTypeField(context),
            _form.descriptionField(context),
            _form.phoneField(context),
            ..._form.addressFields(context),
          ]),
        ),
      ),
      _Step.images => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: withGaps([
          Text(l10n.wizardImagesIntro),
          ImagePickerField(
            purpose: ImagePurpose.logo,
            restaurantId: live.id,
            targetPath: 'restaurants/${live.id}',
            label: l10n.fieldLogo,
            value: live.logo,
          ),
          ImagePickerField(
            purpose: ImagePurpose.cover,
            restaurantId: live.id,
            targetPath: 'restaurants/${live.id}',
            label: l10n.fieldCover,
            value: live.cover,
          ),
        ]),
      ),
      _Step.menu => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: withGaps([
          Text(l10n.wizardMenuIntro),
          for (final (icon, text) in [
            (Icons.category_outlined, l10n.wizardMenuCategories),
            (Icons.lunch_dining_outlined, l10n.wizardMenuItems),
            (Icons.palette_outlined, l10n.wizardMenuTheme),
            (Icons.publish_outlined, l10n.wizardMenuPublish),
          ])
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icon)),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
              ],
            ),
        ]),
      ),
    };
  }

  Widget _buttons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final last = _step == _Step.menu;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_step != _Step.profile)
          TextButton(
            key: WizardKeys.back,
            onPressed: _busy ? null : _back,
            child: Text(l10n.actionBack),
          ),
        if (last) ...[
          AppSecondaryButton(
            key: WizardKeys.toDashboard,
            label: l10n.wizardToDashboard,
            onPressed: _busy ? null : () => _finish(Routes.home),
          ),
          AppPrimaryButton(
            key: WizardKeys.toMenu,
            label: l10n.wizardToMenu,
            loading: _busy,
            onPressed: () => _finish(Routes.menu),
          ),
        ] else
          AppPrimaryButton(
            key: WizardKeys.next,
            label: _step == _Step.images && widget.restaurant.logo == null
                ? l10n.wizardSkipStep
                : l10n.actionNext,
            loading: _busy,
            onPressed: _next,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(draftAutosaveProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final breakpoint = Breakpoint.of(context);
    final stepNumber = _step.index + 1;
    final total = _Step.values.length;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!breakpoint.isExpanded) ...[
          LinearProgressIndicator(
            key: WizardKeys.progress,
            value: stepNumber / total,
            semanticsLabel: l10n.wizardStepOf(stepNumber, total),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.wizardStepOf(stepNumber, total),
            style: theme.textTheme.labelLarge,
          ),
        ],
        Semantics(
          header: true,
          child: Text(
            _title(l10n, _step),
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );

    final stepBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        _stepContent(context),
        if (_error != null) ...[
          const SizedBox(height: 16),
          FormMessage(_error!),
        ],
        const SizedBox(height: 24),
        if (!breakpoint.isCompact) _buttons(context),
      ],
    );

    final Widget body = switch (breakpoint) {
      Breakpoint.compact => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(16),
        child: stepBody,
      ),
      Breakpoint.medium => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card.outlined(
              margin: EdgeInsetsDirectional.zero,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(24),
                child: stepBody,
              ),
            ),
          ),
        ),
      ),
      Breakpoint.expanded => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: WizardKeys.stepper,
            width: Breakpoint.sideMenuWidth,
            child: _StepList(
              titles: [for (final s in _Step.values) _title(l10n, s)],
              current: _step.index,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(32),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: stepBody,
                ),
              ),
            ),
          ),
          SizedBox(
            width: MenuHeaderPreview.width + 32,
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 32, 32, 32),
              child: MenuHeaderPreview(
                restaurant: _form.preview(widget.restaurant),
              ),
            ),
          ),
        ],
      ),
    };

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.wizardTitle),
        actions: [
          if (!breakpoint.isCompact) const Center(child: SaveStatusIndicator()),
          TextButton(
            key: WizardKeys.skip,
            onPressed: _busy ? null : () => _finish(Routes.home),
            child: Text(l10n.wizardSkip),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: breakpoint.isCompact
          ? Material(
              elevation: 3,
              color: theme.colorScheme.surfaceContainer,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(child: SaveStatusIndicator()),
                      Flexible(child: _buttons(context)),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// Vertical list of steps for wide windows; the current one highlighted.
class _StepList extends StatelessWidget {
  const _StepList({required this.titles, required this.current});

  final List<String> titles;
  final int current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          for (final (i, title) in titles.indexed)
            Semantics(
              selected: i == current,
              label: l10n.wizardStepOf(i + 1, titles.length),
              child: ListTile(
                minTileHeight: 56,
                selected: i == current,
                selectedTileColor: scheme.secondaryContainer,
                selectedColor: scheme.onSecondaryContainer,
                shape: const StadiumBorder(),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: i <= current
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  foregroundColor: i <= current
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                  child: i < current
                      ? const Icon(Icons.check, size: 16)
                      : Text('${i + 1}'),
                ),
                title: Text(title),
              ),
            ),
        ],
      ),
    );
  }
}
