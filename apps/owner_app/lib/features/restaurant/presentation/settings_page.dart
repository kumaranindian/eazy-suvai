import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../data/restaurant_repository.dart';
import 'menu_link_page.dart';
import 'regional_page.dart';

/// Settings section home (M03): links to the restaurant's profile, opening
/// hours, currency and time zone, and menu link, each with a one-line
/// summary.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final r = ref.watch(currentRestaurantProvider).value;

    final items = <(Key, IconData, String, String?, String)>[
      (
        const ValueKey('settings.profile'),
        Icons.storefront_outlined,
        l10n.profileTitle,
        r?.name,
        Routes.profile,
      ),
      (
        const ValueKey('settings.hours'),
        Icons.schedule,
        l10n.hoursTitle,
        r == null
            ? null
            : (r.openingHours == null ? l10n.hoursNotSet : l10n.hoursSet),
        Routes.hours,
      ),
      (
        const ValueKey('settings.regional'),
        Icons.public,
        l10n.regionalTitle,
        r == null
            ? null
            : '${core.currencyName(r.currency)} · ${r.timezone} (${utcOffsetLabel(r.timezone)})',
        Routes.regional,
      ),
      (
        const ValueKey('settings.menuLink'),
        Icons.link,
        l10n.menuLinkTitle,
        r == null ? null : menuUrl(r.slug),
        Routes.menuLink,
      ),
    ];

    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
          children: [
            for (final (key, icon, title, subtitle, route) in items)
              ListTile(
                key: key,
                minTileHeight: 64,
                leading: Icon(icon),
                title: Text(title),
                subtitle: subtitle == null
                    ? null
                    : Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(route),
              ),
          ],
        ),
      ),
    );
  }
}
