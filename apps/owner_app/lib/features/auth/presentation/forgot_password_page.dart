import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../application/owner_auth_service.dart';
import 'auth_widgets.dart';

/// Password reset by emailed link (FR-006). The link is Firebase's: single
/// use, valid for 1 hour. The confirmation never says whether the address
/// has an account (email enumeration protection).
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.email});

  final String? email;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;
  String? _sentTo;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _sentTo = null;
    });
    final email = _email.text.trim();
    try {
      await ref.read(ownerAuthServiceProvider).sendPasswordReset(email);
      if (mounted) setState(() => _sentTo = email);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Unknown addresses look like success (no account enumeration).
      if (AuthErrorCode.fromFirebase(e.code) ==
          AuthErrorCode.invalidCredential) {
        setState(() => _sentTo = email);
      } else {
        setState(
          () => _error = CoreLocalizations.of(context).messageForError(e),
        );
      }
    } on Object catch (e) {
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
      card: true,
      title: l10n.forgotTitle,
      subtitle: l10n.forgotSubtitle,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              key: const ValueKey('forgot.email'),
              label: l10n.fieldEmail,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              prefixIcon: Icons.mail_outline,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => Validators.email(core, v),
            ),
            const SizedBox(height: 24),
            if (_sentTo != null) ...[
              FormMessage(l10n.forgotSent(_sentTo!), isError: false),
              formGap,
            ],
            if (_error != null) ...[FormMessage(_error!), formGap],
            AppPrimaryButton(
              key: const ValueKey('forgot.submit'),
              label: l10n.actionSendResetLink,
              loading: _busy,
              expand: true,
              onPressed: _submit,
            ),
            formGap,
            AppSecondaryButton(
              label: l10n.actionBackToSignIn,
              expand: true,
              onPressed: () => context.go(Routes.signIn),
            ),
          ],
        ),
      ),
    );
  }
}
