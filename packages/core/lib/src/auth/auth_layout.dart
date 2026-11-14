import 'package:flutter/material.dart';

import '../layout/breakpoint.dart';
import '../theme/brand_colors.dart';

/// Layout for sign-in, sign-up and other account screens (M01).
///
/// * Compact (< 600 px): full-width single column, small logo on top.
/// * Medium (600–1023 px): centred card, logo above the form.
/// * Expanded (≥ 1024 px): brand panel (logo, tagline) on the start side,
///   form on the end side, form at most [maxFormWidth] wide.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.logo,
    required this.tagline,
    required this.title,
    required this.child,
    this.subtitle,
    this.card = false,
  });

  static const brandPanelKey = ValueKey('auth-brand-panel');
  static const formKey = ValueKey('auth-form-column');
  static const maxFormWidth = 480.0;

  /// Builds the logo at the given height (each app has its own asset).
  final Widget Function(BuildContext context, double height) logo;

  /// Localized tagline shown in the brand panel.
  final String tagline;
  final String title;
  final String? subtitle;

  /// The form or message.
  final Widget child;

  /// Show the content in a centred card on wide screens instead of the brand
  /// panel (used by "Check your email" and "Forgot password").
  final bool card;

  @override
  Widget build(BuildContext context) {
    final breakpoint = Breakpoint.of(context);
    final theme = Theme.of(context);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );

    Widget formColumn({required bool showLogo, double padding = 16}) =>
        SingleChildScrollView(
          key: formKey,
          padding: EdgeInsetsDirectional.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxFormWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showLogo) ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: logo(context, 48),
                    ),
                    const SizedBox(height: 24),
                  ],
                  header,
                  child,
                ],
              ),
            ),
          ),
        );

    final Widget body;
    if (breakpoint.isExpanded && !card) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _BrandPanel(logo: logo, tagline: tagline),
          ),
          Expanded(
            flex: 6,
            child: Center(child: formColumn(showLogo: false, padding: 48)),
          ),
        ],
      );
    } else if (breakpoint.isCompact) {
      body = formColumn(showLogo: true);
    } else {
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxFormWidth + 48),
            child: Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(24),
                child: Column(
                  key: formKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: logo(context, 56),
                    ),
                    const SizedBox(height: 24),
                    header,
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(body: SafeArea(child: body));
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.logo, required this.tagline});

  final Widget Function(BuildContext context, double height) logo;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ColoredBox(
      key: AuthLayout.brandPanelKey,
      color: dark ? theme.colorScheme.surfaceContainerHigh : BrandColors.cream,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            logo(context, 120),
            const SizedBox(height: 32),
            Text(
              tagline,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: dark
                    ? theme.colorScheme.onSurface
                    : BrandColors.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
