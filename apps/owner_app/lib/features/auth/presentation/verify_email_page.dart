import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../application/owner_auth_service.dart';
import 'auth_widgets.dart';

/// "Check your email" (FR-091). Shown after sign-up (`reason=sent`) and
/// after a sign-in attempt before verification (`reason=unverified`).
/// Resend is limited to once a minute.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, this.email, this.reason});

  final String? email;

  /// `sent` (email just sent) or `unverified` (sign-in refused).
  final String? reason;

  static const resendCooldown = Duration(seconds: 60);

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  Timer? _timer;
  int _secondsLeft = 0;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    // The email was just sent at sign-up: wait a minute before resending.
    if (widget.reason == 'sent') _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = VerifyEmailPage.resendCooldown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    try {
      final outcome = await ref
          .read(ownerAuthServiceProvider)
          .resendVerification();
      if (!mounted || outcome == ResendOutcome.alreadyVerified) return;
      _startCooldown();
      setState(() {
        _message = l10n.verifySent;
        _messageIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = core.messageForError(e);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canResend = ref.watch(pendingCredentialsProvider) != null;
    final email = widget.email;
    final body = widget.reason == 'unverified'
        ? l10n.verifyRequired
        : (email == null || email.isEmpty)
        ? l10n.verifyBodyNoEmail
        : l10n.verifyBody(email);

    return OwnerAuthLayout(
      card: true,
      title: l10n.verifyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          formGap,
          Text(body, key: const ValueKey('verify.body')),
          formGap,
          Text(l10n.verifyHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          if (_message != null) ...[
            FormMessage(_message!, isError: _messageIsError),
            formGap,
          ],
          if (canResend)
            AppPrimaryButton(
              key: const ValueKey('verify.resend'),
              label: _secondsLeft > 0
                  ? l10n.actionResendIn(_secondsLeft)
                  : l10n.actionResend,
              loading: _busy,
              expand: true,
              onPressed: _secondsLeft > 0 ? null : _resend,
            )
          else
            Text(l10n.verifySignInToResend, textAlign: TextAlign.center),
          formGap,
          AppSecondaryButton(
            key: const ValueKey('verify.back'),
            label: l10n.actionBackToSignIn,
            expand: true,
            onPressed: () => context.go(Routes.signIn),
          ),
        ],
      ),
    );
  }
}
