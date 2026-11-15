import 'package:admin_app/data/admin_api.dart';

/// Records callable calls and answers from [handlers] (by name).
class FakeAdminApi implements AdminApi {
  FakeAdminApi([Map<String, Object? Function(Map<String, Object?>)>? handlers])
    : handlers = {...?handlers};

  final Map<String, Object? Function(Map<String, Object?>)> handlers;
  final calls = <(String, Map<String, Object?>)>[];

  /// Thrown once by the next call to that name.
  final errors = <String, Object>{};

  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, Object?> data = const {},
  ]) async {
    calls.add((name, data));
    final e = errors.remove(name);
    if (e != null) throw e;
    final h = handlers[name];
    final r = h == null ? null : h(data);
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  List<Map<String, Object?>> callsTo(String name) => [
    for (final (n, d) in calls)
      if (n == name) d,
  ];
}
