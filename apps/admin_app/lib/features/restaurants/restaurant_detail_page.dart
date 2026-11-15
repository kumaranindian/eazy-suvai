import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/admin_api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../router/app_router.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/read_only.dart';
import '../subscriptions/presentation/change_plan_dialog.dart';
import '../subscriptions/presentation/upgrade_requests_page.dart';

/// Keys, for tests.
abstract final class DetailKeys {
  static const summary = ValueKey('detail.summary');
  static const status = ValueKey('detail.status');
  static const subscription = ValueKey('detail.subscription');
  static const payments = ValueKey('detail.payments');
  static const history = ValueKey('detail.history');
  static const activity = ValueKey('detail.activity');
  static ValueKey<String> statusAction(String to) =>
      ValueKey('detail.status.$to');
  static const extend = ValueKey('detail.extend');
  static const downgrade = ValueKey('detail.downgrade');
  static const recordPayment = ValueKey('detail.recordPayment');
  static const changePlan = ValueKey('detail.changePlan');
  static const menuLink = ValueKey('detail.menuLink');
  static const auditLink = ValueKey('detail.auditLink');
}

final restaurantDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, id) => ref.watch(adminApiProvider).call('adminGetRestaurant', {
        'restaurantId': id,
      }),
    );

/// Status changes an admin may make from [status] (FR-088; mirrors
/// `setRestaurantStatus`). Reactivation of a deactivated account is only
/// possible within 90 days; the server checks the date.
List<String> statusActionsFor(String status) => switch (status) {
  'active' => const ['suspended', 'deactivated'],
  'suspended' => const ['active', 'deactivated'],
  'deactivated' => const ['active'],
  _ => const [],
};

/// Restaurant detail (M11, FR-087 to FR-089): profile summary, public menu
/// link, status with actions (reason required), subscription with record
/// payment / change plan / extend / downgrade, payments, plan history and
/// activity.
/// Admins never edit the menu here (§3.5).
class RestaurantDetailPage extends ConsumerWidget {
  const RestaurantDetailPage({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final detail = ref.watch(restaurantDetailProvider(restaurantId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail.value?['restaurant']?['name'] as String? ??
              l10n.restaurantDetail,
        ),
      ),
      body: detail.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: core.messageForError(e)),
        data: (d) => _Detail(restaurantId: restaurantId, data: d),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.restaurantId, required this.data});

  final String restaurantId;
  final Map<String, dynamic> data;

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    String to,
  ) async {
    final l10n = AppLocalizations.of(context);
    final reason = await askReason(
      context,
      title: l10n.statusActionTitle(to),
      message: l10n.statusActionMessage(to),
      confirmLabel: l10n.statusActionLabel(to),
      destructive: to != 'active',
    );
    if (reason == null || !context.mounted) return;
    final ok = await runAdminAction(
      context,
      () => ref.read(adminApiProvider).call('setRestaurantStatus', {
        'restaurantId': restaurantId,
        'status': to,
        'reason': reason,
      }),
      done: l10n.statusChanged,
    );
    if (ok) ref.invalidate(restaurantDetailProvider(restaurantId));
  }

  Future<void> _extend(
    BuildContext context,
    WidgetRef ref,
    DateTime? current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (current != null && current.isAfter(now) ? current : now)
          .add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime.utc(2100),
      helpText: l10n.extendPick,
    );
    if (picked == null || !context.mounted) return;
    final reason = await askReason(
      context,
      title: l10n.extendTitle,
      confirmLabel: l10n.extend,
    );
    if (reason == null || !context.mounted) return;
    final iso =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    final ok = await runAdminAction(
      context,
      () => ref.read(adminApiProvider).call('changeSubscription', {
        'action': 'extend',
        'restaurantId': restaurantId,
        'expiresAt': iso,
        'reason': reason,
      }),
      done: l10n.subscriptionChanged,
    );
    if (ok) ref.invalidate(restaurantDetailProvider(restaurantId));
  }

  Future<void> _downgrade(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final reason = await askReason(
      context,
      title: l10n.downgradeTitle,
      message: l10n.downgradeMessage,
      confirmLabel: l10n.downgrade,
      destructive: true,
    );
    if (reason == null || !context.mounted) return;
    final ok = await runAdminAction(
      context,
      () => ref.read(adminApiProvider).call('changeSubscription', {
        'action': 'downgrade',
        'restaurantId': restaurantId,
        'reason': reason,
      }),
      done: l10n.subscriptionChanged,
    );
    if (ok) ref.invalidate(restaurantDetailProvider(restaurantId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final r = Map<String, dynamic>.from(data['restaurant'] as Map);
    final sub = Map<String, dynamic>.from(data['subscription'] as Map);
    final payments = listOf(data['payments']);
    final history = listOf(data['history']);
    final activity = listOf(data['activity']);
    final signIns = Map<String, dynamic>.from(
      (data['signIns'] as Map?) ?? const {},
    );
    final readOnly = adminReadOnly(context);
    final status = '${r['status']}';
    final menuUrl = '${AppEnv.fromDefines().menuBaseUrl}/${r['slug']}';
    final expanded = Breakpoint.of(context).isExpanded;

    Widget field(String label, Object? value) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: SelectableText('${value ?? '–'}')),
        ],
      ),
    );

    final summary = AdminSectionCard(
      key: DetailKeys.summary,
      title: l10n.detailProfile,
      children: [
        field(l10n.fieldOwner, r['ownerName']),
        field(l10n.fieldEmail, r['ownerEmail']),
        field(l10n.fieldMobile, r['ownerMobile']),
        field(l10n.fieldCountry, '${r['country'] ?? ''} · ${r['city'] ?? ''}'),
        field(l10n.fieldBusiness, r['businessType']),
        field(l10n.fieldCurrency, '${r['currency']} · ${r['timezone']}'),
        field(
          l10n.fieldMenu,
          '${r['categories']} / ${r['items']} · ${r['publishedVersion'] == null ? l10n.notPublished : l10n.publishedVersion(r['publishedVersion'] as int, fmtDate(context, r['publishedAt']))}',
        ),
        field(l10n.fieldQrCode, r['qrCode']),
        field(l10n.fieldRegistered, fmtDate(context, r['createdAt'])),
        field(l10n.fieldLastSignIn, signIns['lastSignInAt']),
        Row(
          children: [
            Expanded(child: SelectableText(menuUrl, key: DetailKeys.menuLink)),
            IconButton(
              tooltip: l10n.copyLink,
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(ClipboardData(text: menuUrl)),
            ),
          ],
        ),
      ],
    );

    final statusCard = AdminSectionCard(
      key: DetailKeys.status,
      title: l10n.detailStatus,
      trailing: StatusChip(
        label: l10n.statusName(status),
        tone: statusTone(status),
      ),
      children: [
        if (r['statusReason'] != null)
          field(
            l10n.fieldReason,
            '${r['statusReason']} (${fmtDate(context, r['statusChangedAt'], time: true)})',
          ),
        if (r['deactivatedAt'] != null)
          field(l10n.fieldDeactivated, fmtDate(context, r['deactivatedAt'])),
        if (!readOnly)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final to in statusActionsFor(status))
                OutlinedButton(
                  key: DetailKeys.statusAction(to),
                  onPressed: () => _changeStatus(context, ref, to),
                  child: Text(
                    l10n.statusActionLabel(
                      status == 'deactivated' && to == 'active'
                          ? 'reactivate'
                          : to,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );

    final subStatus = '${sub['status']}';
    final subscriptionCard = AdminSectionCard(
      key: DetailKeys.subscription,
      title: l10n.detailSubscription,
      children: [
        field(
          l10n.colPlan,
          '${sub['planId']} · ${l10n.subscriptionStatusName(subStatus)}${sub['billing'] == null ? '' : ' · ${sub['billing']}'}',
        ),
        field(l10n.fieldStarts, fmtDate(context, sub['startAt'])),
        field(l10n.fieldExpires, fmtDate(context, sub['expiresAt'])),
        if (subStatus == 'grace')
          field(l10n.fieldGraceEnds, fmtDate(context, sub['graceEndsAt'])),
        if (!readOnly)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: DetailKeys.recordPayment,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => RecordPaymentDialog(
                      restaurantId: restaurantId,
                      restaurantName: '${r['name']}',
                      planId: 'pro',
                      billing: sub['billing'] == 'monthly'
                          ? 'monthly'
                          : 'annual',
                      currency: '${r['currency'] ?? 'INR'}',
                    ),
                  );
                  if (ok == true) {
                    ref.invalidate(restaurantDetailProvider(restaurantId));
                  }
                },
                child: Text(l10n.recordPayment),
              ),
              OutlinedButton(
                key: DetailKeys.changePlan,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => ChangePlanDialog(
                      restaurantId: restaurantId,
                      restaurantName: '${r['name']}',
                      currentPlanId: '${sub['planId'] ?? 'free'}',
                    ),
                  );
                  if (ok == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.subscriptionChanged)),
                    );
                    ref.invalidate(restaurantDetailProvider(restaurantId));
                  }
                },
                child: Text(l10n.changePlan),
              ),
              if (subStatus != 'free') ...[
                OutlinedButton(
                  key: DetailKeys.extend,
                  onPressed: () => _extend(
                    context,
                    ref,
                    DateTime.tryParse('${sub['expiresAt']}'),
                  ),
                  child: Text(l10n.extend),
                ),
                OutlinedButton(
                  key: DetailKeys.downgrade,
                  onPressed: () => _downgrade(context, ref),
                  child: Text(l10n.downgrade),
                ),
              ],
            ],
          ),
      ],
    );

    final paymentsCard = AdminSectionCard(
      key: DetailKeys.payments,
      title: l10n.detailPayments,
      children: [
        if (payments.isEmpty) Text(l10n.none),
        for (final p in payments)
          ListTile(
            contentPadding: EdgeInsetsDirectional.zero,
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(
              Money(
                p['amountMinor'] as int,
                '${p['currency']}',
              ).format(locale: Localizations.localeOf(context).toLanguageTag()),
            ),
            subtitle: Text(
              '${l10n.paymentMethodName(p['method'] == 'bank-transfer' ? 'bankTransfer' : '${p['method']}')} · ${p['reference']} · ${fmtDate(context, p['paidAt'])}\n${p['planId']}: ${fmtDate(context, p['periodStart'])} – ${fmtDate(context, p['periodEnd'])}',
            ),
            isThreeLine: true,
          ),
      ],
    );

    final historyCard = AdminSectionCard(
      key: DetailKeys.history,
      title: l10n.detailHistory,
      children: [
        if (history.isEmpty) Text(l10n.none),
        for (final h in history)
          ListTile(
            contentPadding: EdgeInsetsDirectional.zero,
            title: Text(
              '${h['action']}: ${h['fromPlanId']} → ${h['toPlanId']} (${h['toStatus']})',
            ),
            subtitle: Text(
              '${fmtDate(context, h['at'], time: true)}${h['reason'] == null ? '' : ' · ${h['reason']}'}',
            ),
          ),
      ],
    );

    final activityCard = AdminSectionCard(
      key: DetailKeys.activity,
      title: l10n.detailActivity,
      trailing: TextButton(
        key: DetailKeys.auditLink,
        onPressed: () => context.go('${Routes.audit}?restaurant=$restaurantId'),
        child: Text(l10n.viewAuditLog),
      ),
      children: [
        if (signIns['lastSignInAt'] != null)
          ListTile(
            contentPadding: EdgeInsetsDirectional.zero,
            leading: const Icon(Icons.login),
            title: Text(l10n.activitySignIn),
            subtitle: Text('${signIns['lastSignInAt']}'),
          ),
        if (activity.isEmpty) Text(l10n.none),
        for (final a in activity)
          ListTile(
            contentPadding: EdgeInsetsDirectional.zero,
            leading: Icon(
              '${a['action']}'.startsWith('menu.')
                  ? Icons.publish
                  : ('${a['action']}'.startsWith('subscription.')
                        ? Icons.workspace_premium_outlined
                        : Icons.admin_panel_settings_outlined),
            ),
            title: Text('${a['action']}'),
            subtitle: Text(
              '${fmtDate(context, a['at'], time: true)} · ${a['actorRole']}${a['reason'] == null ? '' : ' · ${a['reason']}'}',
            ),
          ),
      ],
    );

    if (!expanded) {
      return AdminPageBody(
        children: [
          statusCard,
          summary,
          subscriptionCard,
          paymentsCard,
          historyCard,
          activityCard,
        ],
      );
    }
    return AdminPageBody(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: [statusCard, summary])),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [subscriptionCard, paymentsCard, historyCard],
              ),
            ),
          ],
        ),
        activityCard,
      ],
    );
  }
}
