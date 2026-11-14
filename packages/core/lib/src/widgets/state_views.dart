import 'package:flutter/material.dart';

import '../l10n/generated/core_localizations.dart';
import 'app_buttons.dart';

/// Centered loading indicator with a screen-reader label.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  /// Optional localized text shown below the spinner.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = CoreLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(semanticsLabel: l10n.stateLoading),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when a list or page has no content yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _StateLayout(
    icon: icon,
    title: title,
    message: message,
    action: actionLabel != null && onAction != null
        ? AppPrimaryButton(label: actionLabel!, onPressed: onAction)
        : null,
  );
}

/// Shown when loading failed. Offers a retry button when [onRetry] is set.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.title, this.message, this.onRetry});

  /// Defaults to the localized "Something went wrong".
  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = CoreLocalizations.of(context);
    return _StateLayout(
      icon: Icons.error_outline,
      iconColor: Theme.of(context).colorScheme.error,
      title: title ?? l10n.stateErrorTitle,
      message: message,
      action: onRetry == null
          ? null
          : AppSecondaryButton(
              label: l10n.actionRetry,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 56,
                  color: iconColor ?? theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}
