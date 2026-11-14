import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Details collected at sign-up (FR-002). Email and password go to Firebase
/// Auth; the rest to `completeRegistration`.
class RegistrationDetails {
  const RegistrationDetails({
    required this.restaurantName,
    required this.ownerName,
    required this.mobile,
    required this.country,
    required this.businessType,
    this.city,
  });

  final String restaurantName;
  final String ownerName;

  /// E.164, already validated for [country].
  final String mobile;
  final Country country;
  final BusinessType businessType;
  final String? city;

  Map<String, Object?> toJson() => {
    'restaurantName': restaurantName.trim(),
    'ownerName': ownerName.trim(),
    'mobile': mobile,
    'country': country.code,
    'businessType': businessType.name,
    if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
  };
}

/// What `completeRegistration` returns.
class RegistrationResult {
  const RegistrationResult({
    required this.restaurantId,
    required this.slug,
    required this.qrCode,
    required this.created,
  });

  factory RegistrationResult.fromJson(Map<Object?, Object?> json) =>
      RegistrationResult(
        restaurantId: json['restaurantId']! as String,
        slug: json['slug']! as String,
        qrCode: json['qrCode']! as String,
        created: json['created'] == true,
      );

  final String restaurantId;
  final String slug;
  final String qrCode;
  final bool created;
}

/// Calls the `completeRegistration` callable (M01).
abstract class RegistrationRepository {
  /// Creates the restaurant for the signed-in user. With `null` details it
  /// only resumes (re-applies claims); it then throws
  /// `registration-incomplete` if there is no restaurant yet.
  Future<RegistrationResult> complete(RegistrationDetails? details);
}

class FunctionsRegistrationRepository implements RegistrationRepository {
  @override
  Future<RegistrationResult> complete(RegistrationDetails? details) async {
    final result = await regionalFunctions
        .httpsCallable('completeRegistration')
        .call<Map<Object?, Object?>>(details?.toJson() ?? const {});
    return RegistrationResult.fromJson(result.data);
  }
}

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => FunctionsRegistrationRepository(),
);
