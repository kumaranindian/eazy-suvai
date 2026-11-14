import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/core_localizations.dart';
import '../menu/menu_models.dart';
import 'currency.dart';
import 'money.dart';

/// Lets through only a plain amount with at most [Currency.decimals]
/// fraction digits (FR-029): `1.250` for KWD, `1.25` for INR, no fraction
/// at all for a 0-decimal currency. Digits and one `.`; no signs, no
/// grouping, no exponent. Whole digits are capped so the amount can't pass
/// [MenuLimits.maxPriceMinor].
class PriceInputFormatter extends TextInputFormatter {
  PriceInputFormatter(this.currency)
    : _pattern = RegExp(
        currency.decimals == 0
            ? r'^\d{0,'
                  '${_wholeDigits(currency)}'
                  r'}$'
            : r'^\d{0,'
                  '${_wholeDigits(currency)}'
                  r'}(\.\d{0,'
                  '${currency.decimals}'
                  r'})?$',
      );

  final Currency currency;
  final RegExp _pattern;

  static int _wholeDigits(Currency c) =>
      MenuLimits.maxPriceMinor.toString().length - c.decimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}

/// Price text → integer minor units, without `double` (BR-019). Null when
/// [text] is empty, not an amount, has too many decimals or is negative.
int? parsePriceMinor(String text, Currency currency) {
  final t = text.trim();
  if (t.isEmpty || t.startsWith('-')) return null;
  try {
    return Money.parse(t, currency.code).minor;
  } on FormatException {
    return null;
  }
}

/// Minor units → the text the field shows, with every decimal place
/// (`1250` KWD → `1.250`).
String formatPriceInput(int minor, Currency currency) =>
    Money.of(minor, currency).toDecimalString();

/// Price entry for one currency (FR-029, AC-029).
///
/// Accepts exactly the currency's decimal places and reports integer minor
/// units through [onChanged] (null while empty or invalid). When the field
/// loses focus the text is completed to every decimal place (`1.25` →
/// `1.250` for KWD), so the owner sees what will be stored.
class PriceField extends StatefulWidget {
  const PriceField({
    super.key,
    required this.currency,
    required this.label,
    this.initialMinor,
    this.onChanged,
    this.enabled = true,
    this.required = true,
    this.textInputAction,
  });

  final Currency currency;
  final String label;
  final int? initialMinor;
  final ValueChanged<int?>? onChanged;
  final bool enabled;
  final bool required;
  final TextInputAction? textInputAction;

  @override
  State<PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<PriceField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMinor;
    _controller = TextEditingController(
      text: initial == null ? '' : formatPriceInput(initial, widget.currency),
    );
    _focus = FocusNode()..addListener(_onFocus);
  }

  @override
  void didUpdateWidget(PriceField old) {
    super.didUpdateWidget(old);
    final minor = widget.initialMinor;
    if (old.currency != widget.currency ||
        (minor != old.initialMinor &&
            minor != parsePriceMinor(_controller.text, widget.currency))) {
      _controller.text = minor == null
          ? ''
          : formatPriceInput(minor, widget.currency);
    }
  }

  void _onFocus() {
    if (_focus.hasFocus) return;
    final minor = parsePriceMinor(_controller.text, widget.currency);
    if (minor == null) return;
    final text = formatPriceInput(minor, widget.currency);
    if (text != _controller.text) _controller.text = text;
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value, CoreLocalizations l10n) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return widget.required ? l10n.priceRequired : null;
    final minor = parsePriceMinor(text, widget.currency);
    if (minor == null) {
      return l10n.priceInvalid(formatPriceInput(1250, widget.currency));
    }
    if (minor > MenuLimits.maxPriceMinor) return l10n.priceTooHigh;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CoreLocalizations.of(context);
    final c = widget.currency;
    return TextFormField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: c.decimals > 0),
      textInputAction: widget.textInputAction,
      inputFormatters: [PriceInputFormatter(c)],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) => _validate(v, l10n),
      onChanged: (v) => widget.onChanged?.call(parsePriceMinor(v, c)),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: '${c.symbol ?? c.code} ',
        hintText: formatPriceInput(0, c),
        helperText: l10n.priceDecimalsHelp(c.code, c.decimals),
      ),
    );
  }
}
