// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'EazySuvai Admin';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navRestaurants => 'Restaurants';

  @override
  String get navPlans => 'Plans';

  @override
  String get navSettings => 'Settings';

  @override
  String get placeholderMessage => 'This screen is coming soon.';

  @override
  String layoutLabel(String layout) {
    return 'Layout: $layout';
  }

  @override
  String get layoutCompact => 'compact';

  @override
  String get layoutMedium => 'medium';

  @override
  String get layoutExpanded => 'expanded';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get actionGoHome => 'Go to dashboard';

  @override
  String get authTagline =>
      'Platform administration. Two-factor sign-in is required.';

  @override
  String get signInSubtitle => 'Sign in with your administrator account.';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get mfaCodeTitle => 'Enter your code';

  @override
  String get mfaCodeSubtitle =>
      'Open your authenticator app and enter the 6-digit code for EazySuvai Admin.';

  @override
  String get fieldMfaCode => '6-digit code';

  @override
  String get validationMfaCode =>
      'Enter the 6 digits from your authenticator app.';

  @override
  String get actionVerify => 'Verify';

  @override
  String get mfaSetupTitle => 'Set up two-factor sign-in';

  @override
  String get mfaSetupSubtitle =>
      'Administrators must use an authenticator app, such as Google Authenticator or Microsoft Authenticator.';

  @override
  String get mfaSetupStep1 =>
      '1. Scan this QR code with your authenticator app.';

  @override
  String get mfaSetupStep2 => 'Or enter this key by hand:';

  @override
  String get mfaSetupStep3 => '2. Enter the 6-digit code the app shows.';

  @override
  String get mfaQrLabel => 'QR code for your authenticator app';

  @override
  String get actionCopyKey => 'Copy key';

  @override
  String get mfaKeyCopied => 'Key copied.';

  @override
  String get actionEnable => 'Turn on two-factor sign-in';

  @override
  String get mfaEnrolled =>
      'Two-factor sign-in is on. Sign in again with your code.';

  @override
  String get actionStartSetup => 'Start setup';
}
