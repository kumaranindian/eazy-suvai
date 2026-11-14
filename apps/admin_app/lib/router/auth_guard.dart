import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Redirect hook for every navigation.
///
/// M00: lets everything through. M01/M11 fill this in: signed-out users go
/// to `/sign-in`; only users with the `platformAdmin` claim and a completed
/// TOTP second factor may enter (FR-084).
///
/// Return a path to redirect, or `null` to continue.
String? authGuard(Ref ref, GoRouterState state) => null;
