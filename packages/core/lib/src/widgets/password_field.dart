import 'package:flutter/material.dart';

import '../l10n/generated/core_localizations.dart';
import 'app_text_field.dart';

/// Password field with a show/hide toggle (48 px target, semantics label).
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.helperText,
    this.textInputAction,
    this.onFieldSubmitted,
    this.newPassword = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final String? helperText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  /// Autofill as a new password (sign-up) instead of the current one.
  final bool newPassword;
  final bool enabled;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = CoreLocalizations.of(context);
    final label = _obscure ? l10n.actionShowPassword : l10n.actionHidePassword;
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      validator: widget.validator,
      helperText: widget.helperText,
      obscureText: _obscure,
      enabled: widget.enabled,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      prefixIcon: Icons.lock_outline,
      suffix: IconButton(
        tooltip: label,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
