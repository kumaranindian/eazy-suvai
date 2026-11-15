import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/owner_auth_service.dart';
import '../../plan/data/plan_repository.dart';
import '../data/account_notices.dart';

/// Keys, for tests.
abstract final class AccountNoticeKeys {
  static const announcement = ValueKey('notice.announcement');
  static const blocked = ValueKey('notice.blocked');
  static const signOut = ValueKey('notice.signOut');
}

/// The admin's announcement on the dashboard (M11).
class AnnouncementBanner extends ConsumerWidget {
  const AnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(platformNoticeProvider).value;
    final now = ref.watch(planClockProvider)();
    if (notice == null || !notice.visibleAt(now)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final bg = notice.warning
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final fg = notice.warning
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Semantics(
        key: AccountNoticeKeys.announcement,
        liveRegion: true,
        container: true,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Row(
              children: [
                Icon(
                  notice.warning
                      ? Icons.warning_amber_rounded
                      : Icons.campaign_outlined,
                  color: fg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(notice.text!, style: TextStyle(color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the app when an admin suspended or deactivated the
/// account (FR-099: "blocked; login shows a notice and support contact").
class AccountBlockedPage extends ConsumerWidget {
  const AccountBlockedPage({super.key, required this.status});

  /// `suspended` or `deactivated`.
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final support = ref.watch(platformNoticeProvider).value?.supportEmail;
    return Scaffold(
      key: AccountNoticeKeys.blocked,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == 'suspended'
                        ? Icons.pause_circle_outline
                        : Icons.block_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    status == 'suspended'
                        ? l10n.blockedSuspendedTitle
                        : l10n.blockedDeactivatedTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status == 'suspended'
                        ? l10n.blockedSuspendedBody
                        : l10n.blockedDeactivatedBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    l10n.blockedContact(support ?? 'support@eazysuvai.com'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  AppSecondaryButton(
                    key: AccountNoticeKeys.signOut,
                    label: l10n.actionSignOut,
                    icon: Icons.logout,
                    onPressed: () =>
                        ref.read(ownerAuthServiceProvider).signOut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
