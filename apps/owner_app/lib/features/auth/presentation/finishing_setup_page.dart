import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../application/owner_auth_service.dart';
import 'auth_widgets.dart';

/// Shown to a verified user whose token has no owner claims yet. Re-applies
/// the claims through `completeRegistration` (idempotent) and refreshes the
/// ID token; the router guard then opens the dashboard. If the restaurant
/// was never created, sends the user to the sign-up form in complete mode.
class FinishingSetupPage extends ConsumerStatefulWidget {
  const FinishingSetupPage({super.key});

  @override
  ConsumerState<FinishingSetupPage> createState() => _FinishingSetupPageState();
}

class _FinishingSetupPageState extends ConsumerState<FinishingSetupPage> {
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }

  Future<void> _resume() async {
    final session = ref.read(authSessionProvider).value;
    if (session?.isAdmin ?? false) {
      setState(() {
        _busy = false;
        _error = CoreLocalizations.of(
          context,
        ).authMessageFor(AuthErrorCode.adminAccount);
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(ownerAuthServiceProvider).resumeSetup();
    } on Object catch (e) {
      if (!mounted) return;
      if (_isRegistrationIncomplete(e)) {
        context.go(Routes.signUp);
        return;
      }
      setState(() => _error = CoreLocalizations.of(context).messageForError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static bool _isRegistrationIncomplete(Object e) =>
      e is FirebaseFunctionsException &&
      appErrorCodeOfFunctions(e) == AppErrorCode.registrationIncomplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    return OwnerAuthLayout(
      card: true,
      title: l10n.finishingTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error == null) ...[
            Text(l10n.finishingBody),
            const SizedBox(height: 24),
            const LoadingState(),
          ] else ...[
            FormMessage(_error!),
            formGap,
            AppPrimaryButton(
              label: core.actionRetry,
              loading: _busy,
              expand: true,
              onPressed: _resume,
            ),
          ],
          formGap,
          AppSecondaryButton(
            label: l10n.actionSignOut,
            expand: true,
            onPressed: () => ref.read(ownerAuthServiceProvider).signOut(),
          ),
        ],
      ),
    );
  }
}
