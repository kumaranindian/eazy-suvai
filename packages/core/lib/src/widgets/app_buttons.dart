import 'package:flutter/material.dart';

import '../l10n/generated/core_localizations.dart';

/// Main call-to-action button. Shows a spinner and ignores taps while
/// [loading] is true.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  /// Fill the available width (used for full-width forms on phones).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? _ButtonSpinner(color: Theme.of(context).colorScheme.onPrimary)
        : Text(label);
    final button = icon == null || loading
        ? FilledButton(onPressed: loading ? null : onPressed, child: child)
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: child,
          );
    return _maybeExpand(
      Semantics(button: true, label: loading ? label : null, child: button),
    );
  }

  Widget _maybeExpand(Widget w) =>
      expand ? SizedBox(width: double.infinity, child: w) : w;
}

/// Secondary action button (outlined).
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? _ButtonSpinner(color: Theme.of(context).colorScheme.primary)
        : Text(label);
    final button = icon == null || loading
        ? OutlinedButton(onPressed: loading ? null : onPressed, child: child)
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: child,
          );
    final wrapped = Semantics(
      button: true,
      label: loading ? label : null,
      child: button,
    );
    return expand ? SizedBox(width: double.infinity, child: wrapped) : wrapped;
  }
}

/// Icon-only button with a required semantics label and a 48 px target.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;

  /// Read by screen readers and shown as a tooltip. Must be localized.
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon),
    tooltip: semanticLabel,
    onPressed: onPressed,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  );
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: color,
      semanticsLabel: CoreLocalizations.of(context).stateLoading,
    ),
  );
}
