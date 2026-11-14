import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../application/admin_auth_service.dart';
import '../data/admin_mfa_repository.dart';
import 'admin_auth_layout.dart';
import 'sign_in_page.dart';

/// TOTP enrolment for an admin without a second factor (FR-084).
class MfaSetupPage extends ConsumerStatefulWidget {
  const MfaSetupPage({super.key});

  @override
  ConsumerState<MfaSetupPage> createState() => _MfaSetupPageState();
}

class _MfaSetupPageState extends ConsumerState<MfaSetupPage> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  TotpEnrollment? _enrollment;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final e = await ref.read(adminAuthServiceProvider).startEnrollment();
      if (mounted) setState(() => _enrollment = e);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = CoreLocalizations.of(context).messageForError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    try {
      await ref
          .read(adminAuthServiceProvider)
          .finishEnrollment(_enrollment!, _code.text);
      router.go('${Routes.signIn}?enrolled=1');
    } catch (e) {
      if (!mounted) return;
      _code.clear();
      setState(() => _error = CoreLocalizations.of(context).messageForError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final enrollment = _enrollment;
    return AdminAuthLayout(
      title: l10n.mfaSetupTitle,
      subtitle: l10n.mfaSetupSubtitle,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (enrollment == null && _busy) const LoadingState(),
            if (enrollment != null) ...[
              Text(l10n.mfaSetupStep1),
              const SizedBox(height: 16),
              Center(
                child: ColoredBox(
                  // QR codes need a light background in dark mode too.
                  color: Colors.white,
                  child: QrImageView(
                    key: const ValueKey('mfa.qr'),
                    data: enrollment.qrCodeUrl,
                    size: 200,
                    padding: const EdgeInsets.all(12),
                    semanticsLabel: l10n.mfaQrLabel,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.mfaSetupStep2),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      enrollment.secretKey,
                      key: const ValueKey('mfa.key'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.copy,
                    semanticLabel: l10n.actionCopyKey,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                        ClipboardData(text: enrollment.secretKey),
                      );
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.mfaKeyCopied)),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l10n.mfaSetupStep3),
              const SizedBox(height: 16),
              TotpCodeField(
                key: const ValueKey('mfa.code'),
                controller: _code,
                onSubmitted: _finish,
              ),
              const SizedBox(height: 24),
            ],
            if (_error != null) ...[
              FormMessage(_error!),
              const SizedBox(height: 16),
            ],
            if (enrollment != null)
              AppPrimaryButton(
                key: const ValueKey('mfa.submit'),
                label: l10n.actionEnable,
                loading: _busy,
                expand: true,
                onPressed: _finish,
              )
            else if (!_busy)
              AppPrimaryButton(
                label: _error == null
                    ? l10n.actionStartSetup
                    : core.actionRetry,
                expand: true,
                onPressed: _start,
              ),
            const SizedBox(height: 16),
            AppSecondaryButton(
              label: l10n.actionSignOut,
              expand: true,
              onPressed: () => ref.read(adminAuthServiceProvider).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
