import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Warns about colour pairs below WCAG AA and says which colour the menu
/// uses instead (FR-060). A live region, so screen readers announce it
/// when a colour change creates or fixes a problem.
class ContrastNotice extends StatelessWidget {
  const ContrastNotice({super.key, required this.theme});

  final ResolvedMenuTheme theme;

  static const warningKey = ValueKey('theme.contrastWarning');
  static const okKey = ValueKey('theme.contrastOk');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final green = Theme.of(context).brightness == Brightness.dark
        ? BrandColors.greenOnDark
        : BrandColors.greenText;

    if (!theme.hasIssues) {
      return Semantics(
        key: okKey,
        liveRegion: true,
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.themeContrastOk,
                style: text.bodyMedium?.copyWith(color: green),
              ),
            ),
          ],
        ),
      );
    }

    String colourName(String hex) => switch (hex) {
      Contrast.white => l10n.themeColourWhite,
      Contrast.nearBlack || '#000000' => l10n.themeColourBlack,
      _ => hex,
    };

    String message(ContrastIssue i) {
      final ratio = i.ratio.toStringAsFixed(1);
      return switch (i.kind) {
        ContrastIssueKind.text => l10n.themeContrastText(
          ratio,
          colourName(i.adjusted),
        ),
        ContrastIssueKind.surfaceText => l10n.themeContrastSurfaceText(
          ratio,
          colourName(i.adjusted),
        ),
        ContrastIssueKind.accent => l10n.themeContrastAccent(ratio),
      };
    }

    return Semantics(
      key: warningKey,
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.themeContrastTitle,
                      style: text.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              for (final i in theme.issues) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsetsDirectional.only(top: 2),
                        decoration: BoxDecoration(
                          color: hexToColor(i.adjusted),
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message(i),
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
