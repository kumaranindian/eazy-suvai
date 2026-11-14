import 'package:flutter/material.dart';

/// An error or success message above a form's submit button. Announced by
/// screen readers when it appears (live region).
class FormMessage extends StatelessWidget {
  const FormMessage(this.text, {super.key, this.isError = true});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isError ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = isError ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: fg,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}
