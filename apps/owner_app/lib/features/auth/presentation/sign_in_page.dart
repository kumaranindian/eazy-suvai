import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../application/owner_auth_service.dart';
import 'auth_widgets.dart';

/// Owner sign-in (FR-005). Unverified owners are signed out and sent to
/// "Check your email" with a resend button (FR-091).
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(ownerAuthServiceProvider)
          .signIn(_email.text, _password.text);
      // The router guard moves a verified owner on.
    } on AuthFailure catch (e) {
      if (!mounted) return;
      if (e.code == AuthErrorCode.emailNotVerified) {
        context.go(
          Uri(
            path: Routes.verifyEmail,
            queryParameters: {
              'email': _email.text.trim(),
              'reason': 'unverified',
            },
          ).toString(),
        );
        return;
      }
      setState(() => _error = CoreLocalizations.of(context).messageForError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = CoreLocalizations.of(context).messageForError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    return OwnerAuthLayout(
      title: l10n.signInTitle,
      subtitle: l10n.signInSubtitle,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              key: const ValueKey('signIn.email'),
              label: l10n.fieldEmail,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              prefixIcon: Icons.mail_outline,
              validator: (v) => Validators.email(core, v),
            ),
            formGap,
            AppPasswordField(
              key: const ValueKey('signIn.password'),
              label: l10n.fieldPassword,
              controller: _password,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => Validators.required(core, v),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => context.go(
                  Uri(
                    path: Routes.forgotPassword,
                    queryParameters: _email.text.trim().isEmpty
                        ? null
                        : {'email': _email.text.trim()},
                  ).toString(),
                ),
                child: Text(l10n.actionForgotPassword),
              ),
            ),
            if (_error != null) ...[FormMessage(_error!), formGap],
            AppPrimaryButton(
              key: const ValueKey('signIn.submit'),
              label: l10n.actionSignIn,
              loading: _busy,
              expand: true,
              onPressed: _submit,
            ),
            formGap,
            AuthLinkRow(
              text: l10n.signInNoAccount,
              action: l10n.actionSignUp,
              onPressed: () => context.go(Routes.signUp),
            ),
          ],
        ),
      ),
    );
  }
}
