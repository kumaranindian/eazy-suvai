import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Labelled text field with the app's standard decoration.
///
/// [label] and [helperText] must come from the localization files.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.helperText,
    this.hintText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffix,
    this.prefixText,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? helperText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final IconData? prefixIcon;
  final Widget? suffix;

  /// Fixed text before the input, for example a dial code `+91`.
  final String? prefixText;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    initialValue: initialValue,
    validator: validator,
    onChanged: onChanged,
    onFieldSubmitted: onFieldSubmitted,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    inputFormatters: inputFormatters,
    autofillHints: autofillHints,
    obscureText: obscureText,
    enabled: enabled,
    maxLength: maxLength,
    maxLines: obscureText ? 1 : maxLines,
    minLines: minLines,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: label,
      helperText: helperText,
      hintText: hintText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      suffixIcon: suffix,
      prefixText: prefixText,
    ),
  );
}
