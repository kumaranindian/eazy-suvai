import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// A colour picker: preset swatches plus a hex input (FR-055).
///
/// [value] is the colour in use (`#RRGGBB`); [overridden] says whether it
/// differs from the theme, which shows "Use theme colour". [onChanged]
/// receives a new `#RRGGBB`, or null to go back to the theme's colour.
class ColorField extends StatefulWidget {
  const ColorField({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.overridden,
    required this.onChanged,
    this.help,
  });

  /// Key prefix for tests (`color.<id>.hex`, `color.<id>.reset`).
  final String id;
  final String label;
  final String? help;
  final String value;
  final bool overridden;
  final ValueChanged<String?> onChanged;

  /// Swatches offered next to the hex field: brand-friendly food colours,
  /// light and dark backgrounds.
  static const swatches = [
    '#A8550A',
    '#C8650A',
    '#B3261E',
    '#7A4A2A',
    '#3B7A20',
    '#2E6B1F',
    '#0B6580',
    '#1565C0',
    '#6A1B9A',
    '#222222',
    '#FFFFFF',
    '#FFF8EE',
    '#F3F8EC',
    '#F2F8FA',
    '#121417',
    '#1E2126',
  ];

  @override
  State<ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<ColorField> {
  late final TextEditingController _hex = TextEditingController(
    text: widget.value,
  );
  String? _error;

  @override
  void didUpdateWidget(ColorField old) {
    super.didUpdateWidget(old);
    // Follow outside changes (swatch, reset) unless the user is mid-edit
    // on an invalid value.
    if (widget.value != old.value &&
        Contrast.normalizeHex(_hex.text) != widget.value) {
      _hex.text = widget.value;
      _error = null;
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _typed(String text) {
    final l10n = AppLocalizations.of(context);
    final hex = Contrast.normalizeHex(text);
    setState(() => _error = hex == null ? l10n.themeHexInvalid : null);
    if (hex != null && hex != widget.value) widget.onChanged(hex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: theme.textTheme.titleSmall),
                  if (widget.help != null)
                    Text(
                      widget.help!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (widget.overridden)
              TextButton(
                key: ValueKey('color.${widget.id}.reset'),
                onPressed: () => widget.onChanged(null),
                child: Text(l10n.themeResetColour),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: hexToColor(widget.value),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: ValueKey('color.${widget.id}.hex'),
                controller: _hex,
                maxLength: 7,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.themeHexLabel(widget.label),
                  errorText: _error,
                  counterText: '',
                ),
                onChanged: _typed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final s in ColorField.swatches)
              _Swatch(
                key: ValueKey('color.${widget.id}.swatch.$s'),
                hex: s,
                selected: s == widget.value,
                label: l10n.themeSwatch(s),
                onTap: () {
                  setState(() => _error = null);
                  widget.onChanged(s);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.hex,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = hexToColor(hex);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: AppTheme.minTouchTarget,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outline,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: hexToColor(Contrast.readableTextOn(hex)),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
