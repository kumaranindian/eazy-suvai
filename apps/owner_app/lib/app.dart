import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'router/app_router.dart';

/// Forces a text direction for the whole app (M13 QA: the RTL readiness
/// test, FRD §6.3). Null in the app: the locale decides.
final textDirectionOverrideProvider = Provider<TextDirection?>((ref) => null);

class OwnerApp extends ConsumerWidget {
  const OwnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    routerConfig: ref.watch(appRouterProvider),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      CoreLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      final direction = ref.watch(textDirectionOverrideProvider);
      return direction == null
          ? child!
          : Directionality(textDirection: direction, child: child!);
    },
  );
}
