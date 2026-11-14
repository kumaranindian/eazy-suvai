import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/restaurant_repository.dart';
import 'save_status.dart';

/// Keys, for tests.
abstract final class MenuLinkKeys {
  static const field = ValueKey('menuLink.field');
  static const copy = ValueKey('menuLink.copy');
  static const save = ValueKey('menuLink.save');
  static const status = ValueKey('menuLink.status');
}

/// The public menu URL for [slug].
String menuUrl(String slug) => '${AppEnv.fromDefines().menuBaseUrl}/$slug';

enum _Check { idle, invalid, checking, available, unavailable, failed }

/// Menu link (slug) editor (M03, FR-092, FR-093, BR-002).
///
/// Shows the current link with a copy button. A new slug is checked as the
/// owner types (format and reserved words on the device, then availability
/// through `changeSlug` with `dryRun`, after a 500 ms pause). Saving calls
/// `changeSlug`; the old link keeps working and redirects (M07).
class MenuLinkPage extends ConsumerStatefulWidget {
  const MenuLinkPage({super.key});

  static const checkDelay = Duration(milliseconds: 500);

  @override
  ConsumerState<MenuLinkPage> createState() => _MenuLinkPageState();
}

class _MenuLinkPageState extends ConsumerState<MenuLinkPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  _Check _check = _Check.idle;
  String? _message;
  bool _saving = false;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _show(_Check check, String? message) => setState(() {
    _check = check;
    _message = message;
  });

  void _changed(String current, String rid) {
    _debounce?.cancel();
    final core = CoreLocalizations.of(context);
    final slug = SlugRules.normalize(_controller.text);
    final seq = ++_seq;
    if (slug.isEmpty || slug == current) {
      _show(_Check.idle, null);
      return;
    }
    final local = SlugRules.check(slug);
    if (local != null) {
      _show(_Check.invalid, core.messageFor(local));
      return;
    }
    _show(_Check.checking, null);
    _debounce = Timer(MenuLinkPage.checkDelay, () async {
      try {
        await ref.read(restaurantRepositoryProvider).checkSlug(rid, slug);
        if (mounted && seq == _seq) _show(_Check.available, null);
      } catch (e) {
        if (!mounted || seq != _seq) return;
        final code = e is FirebaseFunctionsException
            ? appErrorCodeOfFunctions(e)
            : null;
        final known =
            code == AppErrorCode.slugTaken ||
            code == AppErrorCode.slugReserved ||
            code == AppErrorCode.slugInvalid;
        _show(
          known ? _Check.unavailable : _Check.failed,
          core.messageForError(e),
        );
      }
    });
  }

  Future<void> _save(Restaurant r) async {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final slug = SlugRules.normalize(_controller.text);
    final ok = await showConfirmDialog(
      context,
      title: l10n.menuLinkConfirmTitle,
      message: l10n.menuLinkConfirmMessage(menuUrl(slug), menuUrl(r.slug)),
      confirmLabel: l10n.menuLinkConfirmAction,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(restaurantRepositoryProvider).changeSlug(r.id, slug);
      if (!mounted) return;
      _controller.clear();
      setState(() => _saving = false);
      _show(_Check.idle, null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.menuLinkChanged)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _check = _Check.unavailable;
        _message = core.messageForError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final breakpoint = Breakpoint.of(context);

    final Widget body = ref
        .watch(currentRestaurantProvider)
        .when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(message: core.messageForError(e)),
          data: (r) {
            if (r == null) return ErrorState(message: core.errorNotFound);
            final url = menuUrl(r.slug);
            final base =
                '${AppEnv.fromDefines().menuBaseUrl.replaceFirst(RegExp('^https?://'), '')}/';
            final (
              IconData? icon,
              Color? color,
              String? text,
            ) = switch (_check) {
              _Check.idle => (null, null, null),
              _Check.checking => (
                Icons.hourglass_empty,
                theme.colorScheme.onSurfaceVariant,
                l10n.menuLinkChecking,
              ),
              _Check.available => (
                Icons.check_circle_outline,
                theme.brightness == Brightness.dark
                    ? BrandColors.greenOnDark
                    : BrandColors.greenText,
                l10n.menuLinkAvailable,
              ),
              _Check.invalid || _Check.unavailable || _Check.failed => (
                Icons.error_outline,
                theme.colorScheme.error,
                _message,
              ),
            };
            return ListView(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: breakpoint.isCompact ? 16 : 24,
                vertical: 16,
              ),
              children: [
                FormSection(
                  title: l10n.menuLinkCurrent,
                  icon: Icons.link,
                  subtitle: l10n.menuLinkQrNote,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            url,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        AppIconButton(
                          key: MenuLinkKeys.copy,
                          icon: Icons.copy,
                          semanticLabel: l10n.menuLinkCopy,
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: url));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.menuLinkCopied)),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FormSection(
                  title: l10n.menuLinkChange,
                  icon: Icons.edit_outlined,
                  subtitle: l10n.menuLinkRules,
                  children: [
                    TextField(
                      key: MenuLinkKeys.field,
                      controller: _controller,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.url,
                      maxLength: SlugRules.maxLength,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[A-Za-z0-9-]'),
                        ),
                        TextInputFormatter.withFunction(
                          (old, next) =>
                              next.copyWith(text: next.text.toLowerCase()),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.menuLinkNew,
                        prefixText: base,
                        hintText: r.slug,
                      ),
                      onChanged: (_) => _changed(r.slug, r.id),
                    ),
                    if (text != null)
                      Semantics(
                        key: MenuLinkKeys.status,
                        liveRegion: true,
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(text, style: TextStyle(color: color)),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: AppPrimaryButton(
                        key: MenuLinkKeys.save,
                        label: l10n.menuLinkSave,
                        loading: _saving,
                        onPressed: _check == _Check.available
                            ? () => _save(r)
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuLinkTitle)),
      body: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: body,
        ),
      ),
    );
  }
}
