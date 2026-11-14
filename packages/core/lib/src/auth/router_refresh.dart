import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

/// A [Listenable] for `GoRouter.refreshListenable` that fires whenever the
/// auth session changes, so the router re-runs its guard.
Listenable authRefreshListenable(Ref ref) {
  final notifier = _RefreshNotifier();
  ref.listen(authSessionProvider, (_, _) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
}

class _RefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Reads `?from=` safely: only app-internal paths are allowed, so a crafted
/// link cannot redirect to another site after sign-in.
String? safeFromParam(String? from) {
  if (from == null || from.isEmpty) return null;
  if (!from.startsWith('/') || from.startsWith('//') || from.contains('\\')) {
    return null;
  }
  return from;
}
