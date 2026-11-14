import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Redirect hook for every navigation.
///
/// M00: lets everything through. M01 fills this in: send signed-out users to
/// `/sign-in`, unverified users to the verify-email screen (FR-091), and
/// users with a non-owner role away from the owner app.
///
/// Return a path to redirect, or `null` to continue.
String? authGuard(Ref ref, GoRouterState state) => null;
