// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'EazySuvai';

  @override
  String get navHome => 'Home';

  @override
  String get navMenu => 'Menu';

  @override
  String get navShare => 'QR & share';

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
  String get actionGoHome => 'Go to home';

  @override
  String get authTagline => 'Your menu, live in minutes. Scan, browse, enjoy.';

  @override
  String get signInSubtitle => 'Welcome back. Sign in to manage your menu.';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionForgotPassword => 'Forgot password?';

  @override
  String get signInNoAccount => 'New to EazySuvai?';

  @override
  String get actionSignUp => 'Create an account';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get signUpSubtitle =>
      'Start free. Your restaurant gets its own menu link and QR code.';

  @override
  String get signUpSectionRestaurant => 'Your restaurant';

  @override
  String get signUpSectionOwner => 'About you';

  @override
  String get fieldRestaurantName => 'Restaurant name';

  @override
  String get fieldBusinessType => 'Business type';

  @override
  String get fieldCountry => 'Country';

  @override
  String get fieldCity => 'City (optional)';

  @override
  String get fieldCityHelper => 'Helps keep your menu link unique.';

  @override
  String get fieldOwnerName => 'Your name';

  @override
  String get fieldMobile => 'Mobile number';

  @override
  String get fieldPasswordHelper => 'At least 8 characters.';

  @override
  String get actionCreateAccount => 'Create account';

  @override
  String get signUpHaveAccount => 'Already have an account?';

  @override
  String get signUpCompleteTitle => 'Finish setting up';

  @override
  String get signUpCompleteSubtitle =>
      'Add your restaurant details to finish creating your account.';

  @override
  String get actionFinishSetup => 'Finish setup';

  @override
  String get verifyTitle => 'Check your email';

  @override
  String verifyBody(String email) {
    return 'We sent a verification link to $email. Open it to activate your account, then sign in.';
  }

  @override
  String get verifyBodyNoEmail =>
      'We sent you a verification link. Open it to activate your account, then sign in.';

  @override
  String get verifyRequired =>
      'Verify your email address before you sign in. Didn\'t get the email? Send it again.';

  @override
  String get verifyHint =>
      'Can\'t find it? Check your spam folder. Unverified accounts are removed after 7 days.';

  @override
  String get actionResend => 'Resend email';

  @override
  String actionResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get verifySent => 'We sent a new verification link.';

  @override
  String get verifySignInToResend => 'To get a new link, sign in again.';

  @override
  String get actionBackToSignIn => 'Back to sign in';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotSubtitle =>
      'Enter your account email. We\'ll send you a link to choose a new password.';

  @override
  String get actionSendResetLink => 'Send reset link';

  @override
  String forgotSent(String email) {
    return 'If an account exists for $email, we\'ve sent a reset link. It works once and expires in 1 hour.';
  }

  @override
  String get finishingTitle => 'Finishing setup…';

  @override
  String get finishingBody =>
      'We\'re getting your restaurant ready. This takes a few seconds.';

  @override
  String get devMediaTitle => 'Image upload test';

  @override
  String get devMediaIntro =>
      'Developer page. Images uploaded here become your restaurant\'s logo and cover.';

  @override
  String get devMediaLogo => 'Logo';

  @override
  String get devMediaCover => 'Cover image';
}
