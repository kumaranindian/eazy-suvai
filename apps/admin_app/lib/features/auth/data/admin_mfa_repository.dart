import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pending TOTP sign-in challenge (password accepted, code needed).
abstract class MfaChallenge {}

/// A TOTP secret being enrolled.
class TotpEnrollment {
  const TotpEnrollment({
    required this.secretKey,
    required this.qrCodeUrl,
    this.handle,
  });

  /// Base32 secret to type into an authenticator app by hand.
  final String secretKey;

  /// `otpauth://` URL shown as a QR code.
  final String qrCodeUrl;

  /// Implementation data (the Firebase `TotpSecret`).
  final Object? handle;
}

/// TOTP multi-factor authentication for platform admins (FR-084), on top of
/// the shared [AuthRepository]. Needs Identity Platform with TOTP enabled on
/// the project; the Auth emulator does not support TOTP.
abstract class AdminMfaRepository {
  /// Signs in with email and password. Returns a challenge when the account
  /// has a second factor, or `null` when signed in without one.
  Future<MfaChallenge?> signIn(String email, String password);

  /// Completes [challenge] with a 6-digit [code].
  Future<void> resolve(MfaChallenge challenge, String code);

  /// Starts TOTP enrolment for the signed-in user.
  Future<TotpEnrollment> startEnrollment({required String accountName});

  /// Confirms enrolment with the first [code] from the authenticator app.
  Future<void> finishEnrollment(TotpEnrollment enrollment, String code);
}

class _FirebaseChallenge implements MfaChallenge {
  _FirebaseChallenge(this.resolver, this.hint);

  final MultiFactorResolver resolver;
  final MultiFactorInfo hint;
}

class FirebaseAdminMfaRepository implements AdminMfaRepository {
  FirebaseAdminMfaRepository(this.auth, this.sessions);

  final FirebaseAuth auth;
  final AuthRepository sessions;

  static const issuer = 'EazySuvai Admin';

  @override
  Future<MfaChallenge?> signIn(String email, String password) async {
    try {
      await sessions.signIn(email, password);
      return null;
    } on FirebaseAuthMultiFactorException catch (e) {
      final resolver = e.resolver;
      final hint = resolver.hints.where((h) => h.factorId == 'totp');
      if (hint.isEmpty) {
        throw FirebaseAuthException(code: 'operation-not-allowed');
      }
      return _FirebaseChallenge(resolver, hint.first);
    }
  }

  @override
  Future<void> resolve(MfaChallenge challenge, String code) async {
    final c = challenge as _FirebaseChallenge;
    final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
      c.hint.uid,
      code,
    );
    await c.resolver.resolveSignIn(assertion);
    await sessions.refreshSession();
  }

  @override
  Future<TotpEnrollment> startEnrollment({required String accountName}) async {
    final user = auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');
    final session = await user.multiFactor.getSession();
    final secret = await TotpMultiFactorGenerator.generateSecret(session);
    final url = await secret.generateQrCodeUrl(
      accountName: accountName,
      issuer: issuer,
    );
    return TotpEnrollment(
      secretKey: secret.secretKey,
      qrCodeUrl: url,
      handle: secret,
    );
  }

  @override
  Future<void> finishEnrollment(TotpEnrollment enrollment, String code) async {
    final user = auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');
    final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(
      enrollment.handle! as TotpSecret,
      code,
    );
    await user.multiFactor.enroll(assertion, displayName: issuer);
  }
}

final adminMfaRepositoryProvider = Provider<AdminMfaRepository>(
  (ref) => FirebaseAdminMfaRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(authRepositoryProvider),
  ),
);

/// Whether admins must use TOTP. Always true except on the emulators, which
/// have no TOTP; there `assertAdmin` relaxes the check too (demo project
/// only). Firestore rules always require it.
final adminMfaRequiredProvider = Provider<bool>(
  (ref) => !AppEnv.fromDefines().useEmulators,
);
