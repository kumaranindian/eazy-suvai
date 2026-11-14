import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/admin_auth_service.dart';
import '../data/admin_mfa_repository.dart';
import 'admin_auth_layout.dart';

/// Admin sign-in (FR-084): email and password, then the TOTP code.
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key, this.enrolled = false});

  /// Just finished TOTP enrolment: show a confirmation.
  final bool enrolled;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  MfaChallenge? _challenge;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = CoreLocalizations.of(context).messageForError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() => _run(() async {
    final challenge = await ref
        .read(adminAuthServiceProvider)
        .signIn(_email.text, _password.text);
    if (mounted && challenge != null) {
      setState(() => _challenge = challenge);
    }
  });

  Future<void> _verify() => _run(() async {
    try {
      await ref
          .read(adminAuthServiceProvider)
          .verifyCode(_challenge!, _code.text);
    } on Exception {
      _code.clear();
      rethrow;
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final codeStep = _challenge != null;

    return AdminAuthLayout(
      title: codeStep ? l10n.mfaCodeTitle : l10n.signInTitle,
      subtitle: codeStep ? l10n.mfaCodeSubtitle : l10n.signInSubtitle,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.enrolled && !codeStep) ...[
              FormMessage(l10n.mfaEnrolled, isError: false),
              const SizedBox(height: 16),
            ],
            if (!codeStep) ...[
              AppTextField(
                key: const ValueKey('admin.email'),
                label: l10n.fieldEmail,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                prefixIcon: Icons.mail_outline,
                validator: (v) => Validators.email(core, v),
              ),
              const SizedBox(height: 16),
              AppPasswordField(
                key: const ValueKey('admin.password'),
                label: l10n.fieldPassword,
                controller: _password,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signIn(),
                validator: (v) => Validators.required(core, v),
              ),
            ] else
              TotpCodeField(
                key: const ValueKey('admin.code'),
                controller: _code,
                onSubmitted: _verify,
              ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              FormMessage(_error!),
              const SizedBox(height: 16),
            ],
            AppPrimaryButton(
              key: const ValueKey('admin.submit'),
              label: codeStep ? l10n.actionVerify : l10n.actionSignIn,
              loading: _busy,
              expand: true,
              onPressed: codeStep ? _verify : _signIn,
            ),
            if (codeStep) ...[
              const SizedBox(height: 16),
              AppSecondaryButton(
                label: l10n.actionCancel,
                expand: true,
                onPressed: () => setState(() {
                  _challenge = null;
                  _error = null;
                  _code.clear();
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 6-digit one-time code input.
class TotpCodeField extends StatelessWidget {
  const TotpCodeField({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppTextField(
      label: l10n.fieldMfaCode,
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      prefixIcon: Icons.password,
      onFieldSubmitted: (_) => onSubmitted(),
      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
          ? null
          : l10n.validationMfaCode,
    );
  }
}
