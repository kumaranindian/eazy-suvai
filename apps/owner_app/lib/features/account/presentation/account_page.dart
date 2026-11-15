import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../auth/application/owner_auth_service.dart';
import '../../qr/data/share_actions.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../../auth/presentation/legal_links.dart';
import '../data/account_repository.dart';

/// Keys, for tests.
abstract final class AccountKeys {
  static const exportJson = ValueKey('account.exportJson');
  static const exportCsv = ValueKey('account.exportCsv');
  static const delete = ValueKey('account.delete');
  static const next = ValueKey('deleteFlow.next');
  static const name = ValueKey('deleteFlow.name');
  static const confirm = ValueKey('deleteFlow.confirm');
}

/// Downloads the menu as JSON or CSV (FR-105): a browser download on web,
/// the share sheet on Android and iOS (the same saver as the QR files).
Future<void> exportMenuFile(
  BuildContext context,
  WidgetRef ref, {
  required bool csv,
}) async {
  final l10n = AppLocalizations.of(context);
  final core = CoreLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final rid = ref.read(currentRestaurantIdProvider);
  if (rid == null) return;
  try {
    final files = await ref.read(accountRepositoryProvider).exportMenu(rid);
    final actions = ref.read(qrShareActionsProvider);
    final name = '${files.fileBase}.${csv ? 'csv' : 'json'}';
    await actions.saveFile(
      utf8.encode(csv ? files.csv : files.json),
      fileName: name,
      mimeType: csv ? 'text/csv' : 'application/json',
    );
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone(name))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(core.messageForError(e))));
  }
}

/// Account (M12): export the menu, close the account.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final compact = Breakpoint.of(context).isCompact;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: compact ? 16 : 24,
              vertical: 16,
            ),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.exportTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.exportHelp),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppSecondaryButton(
                            key: AccountKeys.exportCsv,
                            label: l10n.exportCsv,
                            icon: Icons.table_chart_outlined,
                            expand: compact,
                            onPressed: () =>
                                exportMenuFile(context, ref, csv: true),
                          ),
                          AppSecondaryButton(
                            key: AccountKeys.exportJson,
                            label: l10n.exportJson,
                            icon: Icons.data_object,
                            expand: compact,
                            onPressed: () =>
                                exportMenuFile(context, ref, csv: false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.deleteTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.deleteHelp),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: AccountKeys.delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: Text(l10n.deleteStart),
                        onPressed: () => context.go(Routes.deleteAccount),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const LegalLinks(agreement: false),
            ],
          ),
        ),
      ),
    );
  }
}

/// The delete-account flow (FR-105): 1. offer the export, 2. type the
/// restaurant's name, 3. confirm. The account is deactivated at once and
/// deleted after 90 days; support can reopen it until then.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  int _step = 0;
  final _name = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  static String _norm(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Future<void> _delete(Restaurant r) async {
    final core = CoreLocalizations.of(context);
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .requestDeletion(r.id, _name.text);
      // The server revoked the sessions; sign out here too.
      await ref.read(ownerAuthServiceProvider).signOut();
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = core.messageForError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = ref.watch(currentRestaurantProvider).value;
    final theme = Theme.of(context);
    if (r == null) return const Scaffold(body: LoadingState());
    final matches =
        _norm(_name.text) != '' && _norm(_name.text) == _norm(r.name);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteTitle)),
      body: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Stepper(
            currentStep: _step,
            controlsBuilder: (context, details) => const SizedBox.shrink(),
            steps: [
              Step(
                title: Text(l10n.deleteStepExport),
                isActive: _step >= 0,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.deleteExportOffer),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppSecondaryButton(
                          label: l10n.exportCsv,
                          icon: Icons.table_chart_outlined,
                          onPressed: () =>
                              exportMenuFile(context, ref, csv: true),
                        ),
                        AppSecondaryButton(
                          label: l10n.exportJson,
                          icon: Icons.data_object,
                          onPressed: () =>
                              exportMenuFile(context, ref, csv: false),
                        ),
                        FilledButton(
                          key: AccountKeys.next,
                          onPressed: () => setState(() => _step = 1),
                          child: Text(l10n.deleteContinue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Step(
                title: Text(l10n.deleteStepName),
                isActive: _step >= 1,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.deleteTypeName(r.name)),
                    const SizedBox(height: 8),
                    TextField(
                      key: AccountKeys.name,
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: l10n.deleteNameLabel,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: matches
                          ? () => setState(() => _step = 2)
                          : null,
                      child: Text(l10n.deleteContinue),
                    ),
                  ],
                ),
              ),
              Step(
                title: Text(l10n.deleteStepConfirm),
                isActive: _step >= 2,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.deleteConsequences),
                    const SizedBox(height: 12),
                    if (_error != null) FormMessage(_error!),
                    FilledButton.icon(
                      key: AccountKeys.confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: Text(l10n.deleteConfirm),
                      onPressed: _deleting || !matches
                          ? null
                          : () => _delete(r),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
