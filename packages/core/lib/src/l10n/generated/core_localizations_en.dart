// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'core_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CoreLocalizationsEn extends CoreLocalizations {
  CoreLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get stateLoading => 'Loading…';

  @override
  String get stateErrorTitle => 'Something went wrong';

  @override
  String get errorUnauthenticated => 'Please sign in to continue.';

  @override
  String get errorEmailNotVerified => 'Please verify your email address first.';

  @override
  String get errorPermissionDenied => 'You don\'t have permission to do this.';

  @override
  String get errorAccountInactive =>
      'This account is not active. Contact support for help.';

  @override
  String get errorInvalidInput =>
      'Some details are not valid. Check them and try again.';

  @override
  String get errorLimitReached => 'You\'ve reached your plan\'s limit.';

  @override
  String get errorNotFound => 'We couldn\'t find what you were looking for.';

  @override
  String get errorAlreadyExists => 'This already exists.';

  @override
  String get errorNetwork =>
      'You seem to be offline. Check your connection and try again.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get errorRegistrationIncomplete =>
      'Your account isn\'t set up yet. Add your restaurant details to finish.';

  @override
  String get errorMfaRequired =>
      'Sign in with your authenticator code to continue.';

  @override
  String get authErrorInvalidEmail => 'Enter a valid email address.';

  @override
  String get authErrorInvalidCredential =>
      'That email and password don\'t match. Check them and try again.';

  @override
  String get authErrorUserDisabled =>
      'This account has been disabled. Contact support for help.';

  @override
  String get authErrorEmailAlreadyInUse =>
      'An account with this email already exists. Sign in instead, or reset your password.';

  @override
  String get authErrorWeakPassword =>
      'Choose a stronger password with at least 8 characters.';

  @override
  String get authErrorTooManyRequests =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get authErrorRequiresRecentLogin =>
      'For your security, sign in again and retry.';

  @override
  String get authErrorExpiredActionCode =>
      'This link has expired. Request a new one.';

  @override
  String get authErrorInvalidActionCode =>
      'This link is not valid or was already used. Request a new one.';

  @override
  String get authErrorInvalidMfaCode =>
      'That code is not correct. Enter the current 6-digit code from your authenticator app.';

  @override
  String get authErrorMfaSessionExpired =>
      'This sign-in took too long. Start again.';

  @override
  String get authErrorUnverifiedEmail =>
      'Verify your email address before setting up two-factor authentication.';

  @override
  String get authErrorNotAdmin =>
      'This account is not a platform administrator.';

  @override
  String get authErrorAdminAccount =>
      'This is an administrator account. Use the admin app to sign in.';

  @override
  String get authErrorOperationNotAllowed =>
      'This sign-in method is not available. Contact support.';

  @override
  String get validationRequired => 'This field is required.';

  @override
  String validationTooLong(int max) {
    return 'Use at most $max characters.';
  }

  @override
  String get validationEmail =>
      'Enter a valid email address, like name@example.com.';

  @override
  String validationPasswordLength(int min) {
    return 'Use at least $min characters.';
  }

  @override
  String get validationMobile =>
      'Enter a valid mobile number for the selected country.';

  @override
  String get countryIN => 'India';

  @override
  String get countryAE => 'United Arab Emirates';

  @override
  String get countryKW => 'Kuwait';

  @override
  String get countrySA => 'Saudi Arabia';

  @override
  String get countryQA => 'Qatar';

  @override
  String get countryBH => 'Bahrain';

  @override
  String get countryOM => 'Oman';

  @override
  String get countryUS => 'United States';

  @override
  String get businessTypeRestaurant => 'Restaurant';

  @override
  String get businessTypeCafe => 'Café';

  @override
  String get businessTypeBakery => 'Bakery';

  @override
  String get businessTypeCloudKitchen => 'Cloud kitchen';

  @override
  String get businessTypeSweetShop => 'Sweet shop';

  @override
  String get businessTypeJuiceBar => 'Juice bar';

  @override
  String get businessTypeFoodTruck => 'Food truck';

  @override
  String get businessTypeBar => 'Bar or pub';

  @override
  String get businessTypeHotel => 'Hotel';

  @override
  String get businessTypeOther => 'Other';

  @override
  String get actionShowPassword => 'Show password';

  @override
  String get actionHidePassword => 'Hide password';
}
