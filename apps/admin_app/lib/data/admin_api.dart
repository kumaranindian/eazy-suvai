import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every admin read and write goes through a callable function (master
/// plan, M01: the security rules always require a TOTP sign-in, and each
/// change must be audit-logged on the server, BR-014). This is the one
/// seam the screens use; tests replace it with [AdminApi] fakes.
abstract class AdminApi {
  /// Calls the callable [name] with [data] and returns its result map.
  Future<Map<String, dynamic>> call(String name, [Map<String, Object?> data]);
}

class FunctionsAdminApi implements AdminApi {
  const FunctionsAdminApi();

  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, Object?> data = const {},
  ]) async {
    final result = await regionalFunctions
        .httpsCallable(name)
        .call<Object?>(data);
    final value = result.data;
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }
}

final adminApiProvider = Provider<AdminApi>((ref) => const FunctionsAdminApi());

/// A list of maps from a callable result field.
List<Map<String, dynamic>> listOf(Object? value) => [
  for (final v in (value as List?) ?? const [])
    if (v is Map) Map<String, dynamic>.from(v),
];

/// An ISO date string from a callable, or null.
DateTime? dateOf(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
