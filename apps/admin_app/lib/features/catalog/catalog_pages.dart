import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/read_only.dart';

/// Keys, for tests.
abstract final class CatalogKeys {
  static ValueKey<String> edit(String kind, String id) =>
      ValueKey('catalog.edit.$kind.$id');
  static ValueKey<String> add(String kind) => ValueKey('catalog.add.$kind');
  static const save = ValueKey('catalog.save');
  static ValueKey<String> field(String name) => ValueKey('catalog.field.$name');
  static const apply = ValueKey('catalog.applyToSubscribers');
  static const retired = ValueKey('catalog.retired');
}

/// `adminListCatalog` for plans, labels, tags or themes.
final catalogProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, kind) async {
      final r = await ref.watch(adminApiProvider).call('adminListCatalog', {
        'kind': kind,
      });
      return listOf(r['entries']);
    });

const labelIcons = [
  'veg',
  'nonVeg',
  'vegan',
  'egg',
  'spicy',
  'bestseller',
  'chefsSpecial',
  'new',
];

Color? _hexColor(Object? v) {
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch('${v ?? ''}');
  return m == null
      ? null
      : Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

// ---- plans --------------------------------------------------------------------

/// Plans (M11, FR-076 to FR-078): list and editor for limits and prices.
/// "Apply to current subscribers" copies the flags to them (FR-077).
class PlansPage extends ConsumerWidget {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final plans = ref.watch(catalogProvider('plans'));
    final readOnly = adminReadOnly(context);
    return plans.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: core.messageForError(e)),
      data: (list) => AdminPageBody(
        children: [
          for (final p in list)
            AdminSectionCard(
              title: '${p['name']} (${p['id']})',
              trailing: readOnly
                  ? null
                  : TextButton.icon(
                      key: CatalogKeys.edit('plan', '${p['id']}'),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.edit),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => PlanEditor(plan: p),
                        );
                        if (ok == true) {
                          ref.invalidate(catalogProvider('plans'));
                        }
                      },
                    ),
              children: [
                Text(
                  l10n.planSummary(
                    '${(p['limits'] as Map?)?['maxItems'] ?? '–'}',
                    '${(p['limits'] as Map?)?['maxCategories'] ?? '–'}',
                    '${(p['limits'] as Map?)?['analyticsDays'] ?? '–'}',
                  ),
                ),
                Text(l10n.planPrices(_pricesText(p['prices']))),
                if (p['active'] == false) Text(l10n.planInactive),
              ],
            ),
        ],
      ),
    );
  }

  static String _pricesText(Object? prices) {
    if (prices is! Map || prices.isEmpty) return '–';
    return [
      for (final e in prices.entries)
        '${e.key}: ${(e.value as Map?)?['monthly'] ?? '–'} / ${(e.value as Map?)?['annual'] ?? '–'}',
    ].join(', ');
  }
}

class PlanEditor extends ConsumerStatefulWidget {
  const PlanEditor({super.key, required this.plan});

  final Map<String, dynamic> plan;

  @override
  ConsumerState<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends ConsumerState<PlanEditor> {
  late final Map<String, dynamic> _limits = Map<String, dynamic>.from(
    (widget.plan['limits'] as Map?) ?? const {},
  );
  late final _name = TextEditingController(
    text: '${widget.plan['name'] ?? ''}',
  );
  late final _items = TextEditingController(
    text: '${_limits['maxItems'] ?? ''}',
  );
  late final _categories = TextEditingController(
    text: '${_limits['maxCategories'] ?? ''}',
  );
  late final _analytics = TextEditingController(
    text: '${_limits['analyticsDays'] ?? 7}',
  );
  late final _prices = TextEditingController(
    text: _priceLines(widget.plan['prices']),
  );
  late bool _active = widget.plan['active'] != false;
  late bool _premium = _limits['premiumThemes'] == true;
  late bool _qrLogo = _limits['qrLogo'] == true;
  late bool _removeBranding = _limits['removeBranding'] == true;
  bool _apply = false;
  bool _saving = false;
  String? _error;

  static String _priceLines(Object? prices) => prices is Map
      ? [
          for (final e in prices.entries)
            '${e.key} ${(e.value as Map?)?['monthly'] ?? ''} ${(e.value as Map?)?['annual'] ?? ''}'
                .trim(),
        ].join('\n')
      : '';

  @override
  void dispose() {
    for (final c in [_name, _items, _categories, _analytics, _prices]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final core = CoreLocalizations.of(context);
    final l10n = AppLocalizations.of(context);
    int? limit(TextEditingController c) =>
        c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());
    final prices = <String, Map<String, int?>>{};
    for (final line
        in _prices.text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)) {
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2 || !RegExp(r'^[A-Z]{3}$').hasMatch(parts[0])) {
        setState(() => _error = l10n.pricesFormat);
        return;
      }
      prices[parts[0]] = {
        'monthly': int.tryParse(parts[1]),
        if (parts.length > 2) 'annual': int.tryParse(parts[2]),
      };
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminApiProvider).call('upsertPlan', {
        'id': widget.plan['id'],
        'name': _name.text.trim(),
        'isFree': widget.plan['isFree'] == true,
        'active': _active,
        'sort': widget.plan['sort'] ?? 0,
        'billing': List<String>.from(
          (widget.plan['billing'] as List?) ?? const [],
        ),
        'prices': prices,
        'limits': {
          'maxItems': limit(_items),
          'maxCategories': limit(_categories),
          'maxBranches': _limits['maxBranches'] ?? 1,
          'premiumThemes': _premium,
          'defaultThemeId': _limits['defaultThemeId'] ?? 'saffron',
          'analyticsDays': int.tryParse(_analytics.text.trim()) ?? 7,
          'qrLogo': _qrLogo,
          'removeBranding': _removeBranding,
        },
        'applyToSubscribers': _apply,
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
    Widget number(
      String key,
      String label,
      TextEditingController c, {
      String? helper,
    }) => TextField(
      key: CatalogKeys.field(key),
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, helperText: helper),
    );
    return AlertDialog(
      title: Text(l10n.editPlan('${widget.plan['id']}')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: CatalogKeys.field('name'),
                controller: _name,
                decoration: InputDecoration(labelText: l10n.fieldName),
              ),
              number(
                'maxItems',
                l10n.fieldMaxItems,
                _items,
                helper: l10n.emptyUnlimited,
              ),
              number(
                'maxCategories',
                l10n.fieldMaxCategories,
                _categories,
                helper: l10n.emptyUnlimited,
              ),
              number('analyticsDays', l10n.fieldAnalyticsDays, _analytics),
              SwitchListTile(
                value: _premium,
                onChanged: (v) => setState(() => _premium = v),
                title: Text(l10n.fieldPremiumThemes),
              ),
              SwitchListTile(
                value: _qrLogo,
                onChanged: (v) => setState(() => _qrLogo = v),
                title: Text(l10n.fieldQrLogo),
              ),
              SwitchListTile(
                value: _removeBranding,
                onChanged: (v) => setState(() => _removeBranding = v),
                title: Text(l10n.fieldRemoveBranding),
              ),
              SwitchListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(l10n.fieldActive),
              ),
              TextField(
                key: CatalogKeys.field('prices'),
                controller: _prices,
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.fieldPrices,
                  helperText: l10n.pricesHelp,
                ),
              ),
              CheckboxListTile(
                key: CatalogKeys.apply,
                value: _apply,
                onChanged: (v) => setState(() => _apply = v ?? false),
                title: Text(l10n.applyToSubscribers),
                subtitle: Text(l10n.applyToSubscribersHelp),
              ),
              if (_error != null) FormMessage(_error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: CatalogKeys.save,
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

// ---- labels, tags and themes ---------------------------------------------------

/// Labels, tags and themes (M11, FR-023, FR-033, FR-059, FR-104): tabs with
/// add, edit and retire (never delete).
class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.tabLabels),
              Tab(text: l10n.tabTags),
              Tab(text: l10n.tabThemes),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _LabelList(kind: 'labels'),
                _LabelList(kind: 'tags'),
                _ThemeList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelList extends ConsumerWidget {
  const _LabelList({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final list = ref.watch(catalogProvider(kind));
    final readOnly = adminReadOnly(context);
    Future<void> edit(Map<String, dynamic>? entry) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) =>
            LabelEditor(kind: kind == 'labels' ? 'label' : 'tag', entry: entry),
      );
      if (ok == true) ref.invalidate(catalogProvider(kind));
    }

    return list.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: core.messageForError(e)),
      data: (entries) => AdminPageBody(
        children: [
          if (!readOnly)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                key: CatalogKeys.add(kind),
                icon: const Icon(Icons.add),
                label: Text(l10n.add),
                onPressed: () => edit(null),
              ),
            ),
          for (final e in entries)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _hexColor(e['color']),
                radius: 12,
              ),
              title: Text(
                '${e['name']}${e['retired'] == true ? ' · ${l10n.retired}' : ''}',
              ),
              subtitle: Text(
                '${e['id']} · ${e['icon']} · ${l10n.sortOrder(e['sort'] as int? ?? 0)}',
              ),
              trailing: readOnly
                  ? null
                  : IconButton(
                      key: CatalogKeys.edit(kind, '${e['id']}'),
                      tooltip: l10n.edit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => edit(e),
                    ),
            ),
        ],
      ),
    );
  }
}

class LabelEditor extends ConsumerStatefulWidget {
  const LabelEditor({super.key, required this.kind, this.entry});

  /// `label` or `tag`.
  final String kind;
  final Map<String, dynamic>? entry;

  @override
  ConsumerState<LabelEditor> createState() => _LabelEditorState();
}

class _LabelEditorState extends ConsumerState<LabelEditor> {
  late final _id = TextEditingController(text: '${widget.entry?['id'] ?? ''}');
  late final _name = TextEditingController(
    text: '${widget.entry?['name'] ?? ''}',
  );
  late final _color = TextEditingController(
    text: '${widget.entry?['color'] ?? '#2E7D32'}',
  );
  late final _sort = TextEditingController(
    text: '${widget.entry?['sort'] ?? 100}',
  );
  late String _icon = labelIcons.contains(widget.entry?['icon'])
      ? '${widget.entry!['icon']}'
      : (widget.kind == 'label' ? 'veg' : 'new');
  late bool _retired = widget.entry?['retired'] == true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_id, _name, _color, _sort]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final isNew = widget.entry == null;
    return AlertDialog(
      title: Text(
        isNew ? l10n.addEntry : l10n.editEntry('${widget.entry!['name']}'),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: CatalogKeys.field('id'),
                controller: _id,
                enabled: isNew,
                decoration: InputDecoration(
                  labelText: l10n.fieldId,
                  helperText: l10n.idHelp,
                ),
              ),
              TextField(
                key: CatalogKeys.field('name'),
                controller: _name,
                decoration: InputDecoration(labelText: l10n.fieldName),
              ),
              DropdownButtonFormField<String>(
                value: _icon,
                decoration: InputDecoration(labelText: l10n.fieldIcon),
                items: [
                  for (final i in labelIcons)
                    DropdownMenuItem(value: i, child: Text(i)),
                ],
                onChanged: (v) => setState(() => _icon = v ?? _icon),
              ),
              TextField(
                key: CatalogKeys.field('color'),
                controller: _color,
                decoration: InputDecoration(
                  labelText: l10n.fieldColor,
                  prefixIcon: Icon(Icons.circle, color: _hexColor(_color.text)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                key: CatalogKeys.field('sort'),
                controller: _sort,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.fieldSort),
              ),
              SwitchListTile(
                key: CatalogKeys.retired,
                value: _retired,
                onChanged: (v) => setState(() => _retired = v),
                title: Text(l10n.retired),
                subtitle: Text(l10n.retiredHelp),
              ),
              if (_error != null) FormMessage(_error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: CatalogKeys.save,
          onPressed: _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await ref.read(adminApiProvider).call('upsertLabel', {
                      'kind': widget.kind,
                      'id': _id.text.trim(),
                      'name': _name.text.trim(),
                      'icon': _icon,
                      'color': _color.text.trim(),
                      'sort': int.tryParse(_sort.text.trim()) ?? 0,
                      'retired': _retired,
                    });
                    if (context.mounted) Navigator.of(context).pop(true);
                  } catch (e) {
                    setState(() {
                      _saving = false;
                      _error = core.messageForError(e);
                    });
                  }
                },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _ThemeList extends ConsumerWidget {
  const _ThemeList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final list = ref.watch(catalogProvider('themes'));
    final readOnly = adminReadOnly(context);
    Future<void> edit(Map<String, dynamic>? t) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => ThemeEditor(theme: t),
      );
      if (ok == true) ref.invalidate(catalogProvider('themes'));
    }

    return list.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: core.messageForError(e)),
      data: (entries) => AdminPageBody(
        children: [
          if (!readOnly)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                key: CatalogKeys.add('themes'),
                icon: const Icon(Icons.add),
                label: Text(l10n.add),
                onPressed: () => edit(null),
              ),
            ),
          for (final t in entries)
            ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final k in ['primary', 'secondary', 'background'])
                    Container(
                      width: 16,
                      height: 32,
                      color: _hexColor((t['tokens'] as Map?)?[k]),
                    ),
                ],
              ),
              title: Text(
                '${t['name']}${t['premium'] == true ? ' · ${l10n.premium}' : ''}${t['retired'] == true ? ' · ${l10n.retired}' : ''}',
              ),
              subtitle: Text(
                '${t['id']} · ${(t['tokens'] as Map?)?['font']} · ${(t['tokens'] as Map?)?['layout']} · ${(t['tokens'] as Map?)?['mode']}',
              ),
              trailing: readOnly
                  ? null
                  : IconButton(
                      key: CatalogKeys.edit('themes', '${t['id']}'),
                      tooltip: l10n.edit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => edit(t),
                    ),
            ),
        ],
      ),
    );
  }
}

class ThemeEditor extends ConsumerStatefulWidget {
  const ThemeEditor({super.key, this.theme});

  final Map<String, dynamic>? theme;

  @override
  ConsumerState<ThemeEditor> createState() => _ThemeEditorState();
}

class _ThemeEditorState extends ConsumerState<ThemeEditor> {
  late final Map<String, dynamic> _t = Map<String, dynamic>.from(
    (widget.theme?['tokens'] as Map?) ?? const {},
  );
  late final _id = TextEditingController(text: '${widget.theme?['id'] ?? ''}');
  late final _name = TextEditingController(
    text: '${widget.theme?['name'] ?? ''}',
  );
  late final _sort = TextEditingController(
    text: '${widget.theme?['sort'] ?? 100}',
  );
  late final _colors = {
    for (final k in ['primary', 'secondary', 'background', 'surface', 'text'])
      k: TextEditingController(text: '${_t[k] ?? '#FFFFFF'}'),
  };
  late final _font = TextEditingController(text: '${_t['font'] ?? 'Poppins'}');
  late String _layout = '${_t['layout'] ?? 'list'}';
  late String _card = '${_t['cardLayout'] ?? 'image-left'}';
  late String _mode = '${_t['mode'] ?? 'light'}';
  late bool _premium = widget.theme?['premium'] == true;
  late bool _retired = widget.theme?['retired'] == true;
  bool _acceptFixes = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_id, _name, _sort, _font, ..._colors.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final isNew = widget.theme == null;
    // The same contrast fix the menu applies (FR-060), shown before saving.
    final resolved = resolveMenuTheme(
      ThemeTokens.fromMap({
        for (final e in _colors.entries)
          e.key: e.value.text.trim().toUpperCase(),
        'font': _font.text.trim(),
        'layout': _layout,
        'cardLayout': _card,
        'mode': _mode,
      }),
    );
    Widget choice(
      String label,
      String value,
      List<String> options,
      ValueChanged<String> onChanged,
    ) => DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
      ],
      onChanged: (v) => setState(() => onChanged(v ?? value)),
    );
    return AlertDialog(
      title: Text(
        isNew ? l10n.addEntry : l10n.editEntry('${widget.theme!['name']}'),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: CatalogKeys.field('id'),
                controller: _id,
                enabled: isNew,
                decoration: InputDecoration(
                  labelText: l10n.fieldId,
                  helperText: l10n.idHelp,
                ),
              ),
              TextField(
                key: CatalogKeys.field('name'),
                controller: _name,
                decoration: InputDecoration(labelText: l10n.fieldName),
              ),
              for (final e in _colors.entries)
                TextField(
                  key: CatalogKeys.field(e.key),
                  controller: e.value,
                  decoration: InputDecoration(
                    labelText: e.key,
                    prefixIcon: Icon(
                      Icons.square,
                      color: _hexColor(e.value.text),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              TextField(
                controller: _font,
                decoration: InputDecoration(labelText: l10n.fieldFont),
              ),
              choice(l10n.fieldLayout, _layout, const [
                'list',
                'grid',
              ], (v) => _layout = v),
              choice(l10n.fieldCardLayout, _card, const [
                'compact',
                'image-top',
                'image-left',
              ], (v) => _card = v),
              choice(l10n.fieldMode, _mode, const [
                'light',
                'dark',
              ], (v) => _mode = v),
              TextField(
                controller: _sort,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.fieldSort),
              ),
              SwitchListTile(
                value: _premium,
                onChanged: (v) => setState(() => _premium = v),
                title: Text(l10n.premium),
              ),
              SwitchListTile(
                key: CatalogKeys.retired,
                value: _retired,
                onChanged: (v) => setState(() => _retired = v),
                title: Text(l10n.retired),
                subtitle: Text(l10n.retiredHelp),
              ),
              // Preview of the resolved colours (what customers would see).
              Container(
                padding: const EdgeInsetsDirectional.all(12),
                color: resolved.backgroundColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.previewHeading,
                      style: TextStyle(
                        color: resolved.accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.previewBody,
                      style: TextStyle(color: resolved.textColor),
                    ),
                  ],
                ),
              ),
              if (resolved.issues.isNotEmpty) ...[
                FormMessage(l10n.contrastIssues(resolved.issues.length)),
                CheckboxListTile(
                  value: _acceptFixes,
                  onChanged: (v) => setState(() => _acceptFixes = v ?? false),
                  title: Text(l10n.acceptContrastFixes),
                ),
              ],
              if (_error != null) FormMessage(_error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: CatalogKeys.save,
          onPressed: _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await ref.read(adminApiProvider).call('upsertTheme', {
                      'id': _id.text.trim(),
                      'name': _name.text.trim(),
                      'premium': _premium,
                      'retired': _retired,
                      'sort': int.tryParse(_sort.text.trim()) ?? 0,
                      'tokens': {
                        for (final e in _colors.entries)
                          e.key: e.value.text.trim().toUpperCase(),
                        'font': _font.text.trim(),
                        'layout': _layout,
                        'cardLayout': _card,
                        'mode': _mode,
                      },
                      'acceptContrastFixes': _acceptFixes,
                    });
                    if (context.mounted) Navigator.of(context).pop(true);
                  } catch (e) {
                    setState(() {
                      _saving = false;
                      _error = core.messageForError(e);
                    });
                  }
                },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
