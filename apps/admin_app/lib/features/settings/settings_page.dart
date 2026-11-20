import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/read_only.dart';

/// Keys, for tests.
abstract final class SettingsKeys {
  static const reservedSlugs = ValueKey('settings.reservedSlugs');
  static const graceDays = ValueKey('settings.graceDays');
  static const fonts = ValueKey('settings.fonts');
  static const currencies = ValueKey('settings.currencies');
  static const supportEmail = ValueKey('settings.supportEmail');
  static const liveIdleMinutes = ValueKey('settings.liveIdleMinutes');
  static const liveMaxMinutes = ValueKey('settings.liveMaxMinutes');
  static const saveConfig = ValueKey('settings.saveConfig');
  static const announcementText = ValueKey('settings.announcementText');
  static const announcementActive = ValueKey('settings.announcementActive');
  static const saveAnnouncement = ValueKey('settings.saveAnnouncement');
  static const adminEmail = ValueKey('settings.adminEmail');
  static const grant = ValueKey('settings.grant');
  static ValueKey<String> revoke(String uid) =>
      ValueKey('settings.revoke.$uid');
}

final platformConfigProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final r = await ref.watch(adminApiProvider).call('adminListCatalog', {
      'kind': 'config',
    });
    return Map<String, dynamic>.from((r['config'] as Map?) ?? const {});
  },
);

final adminsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  final r = await ref.watch(adminApiProvider).call('adminListAdmins');
  return listOf(r['admins']);
});

/// Platform settings (M11): reserved slugs, grace days (0–30, FR-100),
/// fonts, currencies, support email, how long an open public menu keeps
/// checking for changes (idle and per-scan minutes), the owner-app
/// announcement, and the admin users. Every save goes through an audit-logged callable.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = CoreLocalizations.of(context);
    final config = ref.watch(platformConfigProvider);
    return config.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: core.messageForError(e)),
      data: (c) => AdminPageBody(
        maxWidth: 900,
        children: [
          _ConfigForm(config: c),
          _AnnouncementForm(config: c),
          const _Admins(),
        ],
      ),
    );
  }
}

class _ConfigForm extends ConsumerStatefulWidget {
  const _ConfigForm({required this.config});

  final Map<String, dynamic> config;

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  late final _slugs = TextEditingController(
    text: ((widget.config['reservedSlugs'] as List?) ?? const []).join(', '),
  );
  late final _grace = TextEditingController(
    text: '${widget.config['graceDays'] ?? 14}',
  );
  late final _fonts = TextEditingController(
    text: ((widget.config['fonts'] as List?) ?? const []).join(', '),
  );
  late final _currencies = TextEditingController(
    text: [
      for (final e
          in ((widget.config['currencies'] as Map?) ?? const {}).entries)
        '${e.key}=${e.value}',
    ].join(', '),
  );
  late final _support = TextEditingController(
    text: '${widget.config['supportEmail'] ?? ''}',
  );
  late final _liveIdle = TextEditingController(
    text: '${widget.config['liveIdleMinutes'] ?? 30}',
  );
  late final _liveMax = TextEditingController(
    text: '${widget.config['liveMaxMinutes'] ?? 120}',
  );

  @override
  void dispose() {
    for (final c in [
      _slugs,
      _grace,
      _fonts,
      _currencies,
      _support,
      _liveIdle,
      _liveMax,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _list(TextEditingController c) => c.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final readOnly = adminReadOnly(context);
    return AdminSectionCard(
      title: l10n.settingsPlatform,
      children: [
        TextField(
          key: SettingsKeys.reservedSlugs,
          controller: _slugs,
          enabled: !readOnly,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.fieldReservedSlugs,
            helperText: l10n.commaSeparated,
          ),
        ),
        TextField(
          key: SettingsKeys.graceDays,
          controller: _grace,
          enabled: !readOnly,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.fieldGraceDays,
            helperText: l10n.graceDaysHelp,
          ),
        ),
        TextField(
          key: SettingsKeys.fonts,
          controller: _fonts,
          enabled: !readOnly,
          decoration: InputDecoration(
            labelText: l10n.fieldFonts,
            helperText: l10n.commaSeparated,
          ),
        ),
        TextField(
          key: SettingsKeys.currencies,
          controller: _currencies,
          enabled: !readOnly,
          decoration: InputDecoration(
            labelText: l10n.fieldCurrencies,
            helperText: l10n.currenciesHelp,
          ),
        ),
        TextField(
          key: SettingsKeys.supportEmail,
          controller: _support,
          enabled: !readOnly,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: l10n.fieldSupportEmail),
        ),
        TextField(
          key: SettingsKeys.liveIdleMinutes,
          controller: _liveIdle,
          enabled: !readOnly,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.fieldLiveIdleMinutes,
            helperText: l10n.liveIdleMinutesHelp,
            helperMaxLines: 3,
          ),
        ),
        TextField(
          key: SettingsKeys.liveMaxMinutes,
          controller: _liveMax,
          enabled: !readOnly,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.fieldLiveMaxMinutes,
            helperText: l10n.liveMaxMinutesHelp,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: 12),
        if (!readOnly)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: SettingsKeys.saveConfig,
              onPressed: () async {
                final currencies = <String, int>{};
                for (final part in _list(_currencies)) {
                  final kv = part.split('=');
                  if (kv.length == 2 && int.tryParse(kv[1].trim()) != null) {
                    currencies[kv[0].trim().toUpperCase()] = int.parse(
                      kv[1].trim(),
                    );
                  }
                }
                final ok = await runAdminAction(
                  context,
                  () =>
                      ref.read(adminApiProvider).call('updatePlatformConfig', {
                        'reservedSlugs': _list(
                          _slugs,
                        ).map((s) => s.toLowerCase()).toList(),
                        'graceDays': int.tryParse(_grace.text.trim()) ?? 14,
                        'fonts': _list(_fonts),
                        'currencies': currencies,
                        if (_support.text.trim().isNotEmpty)
                          'supportEmail': _support.text.trim(),
                        'liveIdleMinutes':
                            int.tryParse(_liveIdle.text.trim()) ?? 30,
                        'liveMaxMinutes':
                            int.tryParse(_liveMax.text.trim()) ?? 120,
                      }),
                  done: l10n.saved,
                );
                if (ok) ref.invalidate(platformConfigProvider);
              },
              child: Text(l10n.save),
            ),
          ),
      ],
    );
  }
}

class _AnnouncementForm extends ConsumerStatefulWidget {
  const _AnnouncementForm({required this.config});

  final Map<String, dynamic> config;

  @override
  ConsumerState<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends ConsumerState<_AnnouncementForm> {
  late final Map<String, dynamic> _a = Map<String, dynamic>.from(
    (widget.config['announcement'] as Map?) ?? const {},
  );
  late final _text = TextEditingController(text: '${_a['text'] ?? ''}');
  late bool _active = _a['active'] == true;
  late String _level = _a['level'] == 'warning' ? 'warning' : 'info';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final readOnly = adminReadOnly(context);
    return AdminSectionCard(
      title: l10n.settingsAnnouncement,
      children: [
        Text(l10n.announcementHelp),
        TextField(
          key: SettingsKeys.announcementText,
          controller: _text,
          enabled: !readOnly,
          maxLength: 300,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(labelText: l10n.fieldAnnouncement),
        ),
        Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'info', label: Text(l10n.levelInfo)),
                ButtonSegment(value: 'warning', label: Text(l10n.levelWarning)),
              ],
              selected: {_level},
              onSelectionChanged: readOnly
                  ? null
                  : (s) => setState(() => _level = s.first),
            ),
            // One node for screen readers: the switch with its text (M13).
            MergeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    key: SettingsKeys.announcementActive,
                    value: _active,
                    onChanged: readOnly
                        ? null
                        : (v) => setState(() => _active = v),
                  ),
                  Flexible(child: Text(l10n.showToOwners)),
                ],
              ),
            ),
          ],
        ),
        if (!readOnly)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: SettingsKeys.saveAnnouncement,
              onPressed: () async {
                final ok = await runAdminAction(
                  context,
                  () => ref.read(adminApiProvider).call('setAnnouncement', {
                    'text': _text.text.trim(),
                    'level': _level,
                    'active': _active,
                  }),
                  done: l10n.saved,
                );
                if (ok) ref.invalidate(platformConfigProvider);
              },
              child: Text(l10n.save),
            ),
          ),
      ],
    );
  }
}

class _Admins extends ConsumerStatefulWidget {
  const _Admins();

  @override
  ConsumerState<_Admins> createState() => _AdminsState();
}

class _AdminsState extends ConsumerState<_Admins> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _set(String email, bool grant) async {
    final l10n = AppLocalizations.of(context);
    final reason = await askReason(
      context,
      title: grant ? l10n.grantAdminTitle(email) : l10n.revokeAdminTitle(email),
      confirmLabel: grant ? l10n.grantAdmin : l10n.revokeAdmin,
      destructive: !grant,
    );
    if (reason == null || !mounted) return;
    final ok = await runAdminAction(
      context,
      () => ref.read(adminApiProvider).call('setAdminRole', {
        'email': email,
        'grant': grant,
        'reason': reason,
      }),
      done: l10n.saved,
    );
    if (ok) {
      _email.clear();
      ref.invalidate(adminsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final admins = ref.watch(adminsProvider);
    final readOnly = adminReadOnly(context);
    return AdminSectionCard(
      title: l10n.settingsAdmins,
      children: [
        admins.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => FormMessage(core.messageForError(e)),
          data: (list) => Column(
            children: [
              if (list.isEmpty) Text(l10n.none),
              for (final a in list)
                ListTile(
                  contentPadding: EdgeInsetsDirectional.zero,
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: Text('${a['email'] ?? a['uid']}'),
                  trailing: readOnly
                      ? null
                      : TextButton(
                          key: SettingsKeys.revoke('${a['uid']}'),
                          onPressed: () => _set('${a['email']}', false),
                          child: Text(l10n.revokeAdmin),
                        ),
                ),
            ],
          ),
        ),
        if (!readOnly) ...[
          Text(l10n.addAdminHelp),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: SettingsKeys.adminEmail,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l10n.fieldEmail),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: SettingsKeys.grant,
                onPressed: () => _email.text.trim().isEmpty
                    ? null
                    : _set(_email.text.trim(), true),
                child: Text(l10n.grantAdmin),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
