import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The admin's announcement and the support contact, from
/// `config/platform` (M11; readable by verified owners).
@immutable
class PlatformNotice {
  const PlatformNotice({
    this.text,
    this.warning = false,
    this.supportEmail,
    this.until,
  });

  static PlatformNotice fromMap(Map<String, dynamic>? data) {
    final a = data?['announcement'];
    final active =
        a is Map &&
        a['active'] == true &&
        (a['text'] as String? ?? '').trim().isNotEmpty;
    return PlatformNotice(
      text: active ? (a['text'] as String).trim() : null,
      warning: active && a['level'] == 'warning',
      until: active && a['until'] is String
          ? DateTime.tryParse(a['until'] as String)
          : null,
      supportEmail: data?['supportEmail'] as String?,
    );
  }

  final String? text;
  final bool warning;
  final DateTime? until;
  final String? supportEmail;

  /// Whether the banner shows at [now].
  bool visibleAt(DateTime now) =>
      text != null && (until == null || now.isBefore(until!));
}

final platformNoticeProvider = StreamProvider<PlatformNotice>(
  (ref) => FirebaseFirestore.instance
      .doc('config/platform')
      .snapshots()
      .map((s) => PlatformNotice.fromMap(s.data())),
);

/// `users/{uid}.accountStatus`, set by `setRestaurantStatus` (M11, FR-099):
/// `active`, `suspended` or `deactivated` (missing = active).
final accountStatusProvider = StreamProvider<String>((ref) {
  final uid = ref.watch(authSessionProvider).value?.uid;
  if (uid == null) return Stream.value('active');
  return FirebaseFirestore.instance
      .doc('users/$uid')
      .snapshots()
      .map((s) => s.data()?['accountStatus'] as String? ?? 'active');
});
