import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import 'read_only.dart';

/// Page body used by every admin section: padding, max width, and the
/// read-only notice below 600 px (M11).
class AdminPageBody extends StatelessWidget {
  const AdminPageBody({
    super.key,
    required this.children,
    this.maxWidth = 1400,
  });

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoint.of(context).isCompact;
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(compact ? 16 : 24),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (adminReadOnly(context)) ...[
                const ReadOnlyNotice(),
                const SizedBox(height: 16),
              ],
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled card section.
class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wraps at large text sizes instead of overflowing (M13).
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Asks for the reason every sensitive admin action needs (FR-088, BR-014).
/// Returns the trimmed reason, or null when cancelled.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _ReasonDialog(
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    destructive: destructive,
  ),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    this.message,
    required this.confirmLabel,
    required this.destructive,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final bool destructive;

  static const field = ValueKey('reason.field');
  static const confirm = ValueKey('reason.confirm');

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

/// Keys of the reason dialog, for tests.
abstract final class ReasonKeys {
  static const field = _ReasonDialog.field;
  static const confirm = _ReasonDialog.confirm;
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final valid = _controller.text.trim().length >= 3;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(widget.message!),
              const SizedBox(height: 12),
            ],
            TextField(
              key: _ReasonDialog.field,
              controller: _controller,
              autofocus: true,
              maxLength: 1000,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.reasonLabel,
                helperText: l10n.reasonHelp,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: _ReasonDialog.confirm,
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: valid
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// A date (and time) from an ISO string, in the admin's locale.
String fmtDate(BuildContext context, Object? iso, {bool time = false}) {
  final d = iso is String ? DateTime.tryParse(iso) : null;
  if (d == null) return '–';
  final locale = Localizations.localeOf(context).toLanguageTag();
  final f = time ? DateFormat.yMMMd(locale).add_Hm() : DateFormat.yMMMd(locale);
  return f.format(d.toLocal());
}

/// Runs an admin call with a snackbar for the result. Returns true on success.
Future<bool> runAdminAction(
  BuildContext context,
  Future<void> Function() action, {
  required String done,
}) async {
  final core = CoreLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(core.messageForError(e))));
    return false;
  }
}

/// A small coloured status chip.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;

  /// `good`, `warn`, `bad` or `neutral`.
  final String tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      'good' => (scheme.primaryContainer, scheme.onPrimaryContainer),
      'warn' => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      'bad' => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}

String statusTone(String status) => switch (status) {
  'active' => 'good',
  'suspended' => 'warn',
  'deactivated' || 'deleted' => 'bad',
  _ => 'neutral',
};
