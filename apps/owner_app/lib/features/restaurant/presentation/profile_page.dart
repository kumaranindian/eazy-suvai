import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../application/draft_autosave.dart';
import '../data/restaurant_repository.dart';
import 'menu_header_preview.dart';
import 'opening_hours_summary.dart';
import 'profile_form.dart';
import 'save_status.dart';

/// Restaurant profile editor (M03, FR-011 to FR-013, AC-002).
///
/// Changes autosave to the draft after a 1 s pause. Layout by width:
/// * compact: sections as expandable panels, sticky save bar at the bottom;
/// * medium: two columns of section cards;
/// * expanded: the form (max 720 px) with a live menu-header preview.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final restaurant = ref.watch(currentRestaurantProvider);
    return restaurant.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.profileTitle)),
        body: ErrorState(
          message: CoreLocalizations.of(context).messageForError(e),
          onRetry: () => ref.invalidate(currentRestaurantProvider),
        ),
      ),
      data: (r) => r == null
          ? Scaffold(
              body: ErrorState(
                message: CoreLocalizations.of(context).errorNotFound,
              ),
            )
          : _ProfileEditor(restaurant: r),
    );
  }
}

class _ProfileEditor extends ConsumerStatefulWidget {
  const _ProfileEditor({required this.restaurant});

  final Restaurant restaurant;

  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
  late final ProfileFormModel _form;

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

  @override
  Widget build(BuildContext context) {
    // Keep the provider alive while the page is open.
    ref.watch(draftAutosaveProvider);
    final l10n = AppLocalizations.of(context);
    final live = widget.restaurant;
    final breakpoint = Breakpoint.of(context);

    final sections = <_Section>[
      _Section(l10n.profileSectionBasics, Icons.storefront_outlined, [
        _form.nameField(context),
        _form.businessTypeField(context),
        _form.descriptionField(context),
      ]),
      _Section(l10n.profileSectionImages, Icons.image_outlined, [
        ImagePickerField(
          purpose: ImagePurpose.logo,
          restaurantId: live.id,
          targetPath: 'restaurants/${live.id}',
          label: l10n.fieldLogo,
          value: live.logo,
          onRemove: () => _removeImage(RestaurantFields.logo),
        ),
        ImagePickerField(
          purpose: ImagePurpose.cover,
          restaurantId: live.id,
          targetPath: 'restaurants/${live.id}',
          label: l10n.fieldCover,
          value: live.cover,
          onRemove: () => _removeImage(RestaurantFields.cover),
        ),
      ]),
      _Section(l10n.profileSectionContact, Icons.call_outlined, [
        _form.phoneField(context),
        _form.emailField(context),
        _form.websiteField(context),
      ]),
      _Section(
        l10n.profileSectionAddress,
        Icons.place_outlined,
        _form.addressFields(context),
      ),
      _Section(l10n.profileSectionHours, Icons.schedule, [
        OpeningHoursSummary(hours: live.openingHours),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppSecondaryButton(
            label: live.openingHours == null ? l10n.hoursAdd : l10n.hoursEdit,
            icon: Icons.edit_calendar_outlined,
            onPressed: () => context.go(Routes.hours),
          ),
        ),
      ]),
      _Section(
        l10n.profileSectionSocial,
        Icons.public,
        _form.socialFields(context),
        subtitle: l10n.profileSectionSocialHelp,
      ),
      _Section(
        l10n.profileSectionVisibility,
        Icons.visibility_outlined,
        _form.visibilityFields(context),
        subtitle: l10n.profileSectionVisibilityHelp,
      ),
    ];

    final preview = MenuHeaderPreview(restaurant: _form.preview(live));

    final Widget body = switch (breakpoint) {
      // Scroll views with columns, not lazy lists: every field stays built,
      // so the form can validate it and its state survives scrolling.
      Breakpoint.compact => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, s) in sections.indexed)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: Card.outlined(
                  margin: EdgeInsetsDirectional.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    key: PageStorageKey('profile.section.$i'),
                    initiallyExpanded: i == 0,
                    maintainState: true,
                    leading: Icon(s.icon),
                    title: Text(s.title),
                    subtitle: s.subtitle == null ? null : Text(s.subtitle!),
                    childrenPadding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      0,
                      16,
                      16,
                    ),
                    children: withGaps(s.children),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            preview,
          ],
        ),
      ),
      Breakpoint.medium => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final column in [0, 1]) ...[
              if (column == 1) const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final (i, s) in sections.indexed)
                      if (i % 2 == column)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(bottom: 16),
                          child: s.card(),
                        ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      Breakpoint.expanded => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final s in sections)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(bottom: 16),
                          child: s.card(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: MenuHeaderPreview.width + 24,
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 24, 24, 24),
              child: preview,
            ),
          ),
        ],
      ),
    };

    return PopScope(
      onPopInvokedWithResult: (_, _) =>
          ref.read(draftAutosaveProvider.notifier).flush(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileTitle),
          actions: [
            if (!breakpoint.isCompact)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 16),
                child: Center(child: SaveStatusIndicator()),
              ),
          ],
        ),
        body: Form(child: body),
        bottomNavigationBar: breakpoint.isCompact ? const SaveBar() : null,
      ),
    );
  }

  Future<void> _removeImage(String field) async {
    final autosave = ref.read(draftAutosaveProvider.notifier)
      ..stage(field, null);
    await autosave.flush();
  }
}

class _Section {
  const _Section(this.title, this.icon, this.children, {this.subtitle});

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? subtitle;

  Widget card() => FormSection(
    title: title,
    icon: icon,
    subtitle: subtitle,
    children: children,
  );
}
