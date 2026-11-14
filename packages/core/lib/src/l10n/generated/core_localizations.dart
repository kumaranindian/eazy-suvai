import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'core_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of CoreLocalizations
/// returned by `CoreLocalizations.of(context)`.
///
/// Applications need to include `CoreLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/core_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: CoreLocalizations.localizationsDelegates,
///   supportedLocales: CoreLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the CoreLocalizations.supportedLocales
/// property.
abstract class CoreLocalizations {
  CoreLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static CoreLocalizations of(BuildContext context) {
    return Localizations.of<CoreLocalizations>(context, CoreLocalizations)!;
  }

  static const LocalizationsDelegate<CoreLocalizations> delegate =
      _CoreLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Button that repeats a failed action.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// Dismisses a dialog without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Default confirm button in a confirm dialog.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// Accessibility label for a loading indicator.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get stateLoading;

  /// Title of the generic error state.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get stateErrorTitle;

  /// Server error: the user is not signed in.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue.'**
  String get errorUnauthenticated;

  /// Server error: the user's email is not verified.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email address first.'**
  String get errorEmailNotVerified;

  /// Server error: the user is not allowed to do this.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this.'**
  String get errorPermissionDenied;

  /// Server error: the restaurant is suspended, deactivated or deleted.
  ///
  /// In en, this message translates to:
  /// **'This account is not active. Contact support for help.'**
  String get errorAccountInactive;

  /// Server error: the request failed validation.
  ///
  /// In en, this message translates to:
  /// **'Some details are not valid. Check them and try again.'**
  String get errorInvalidInput;

  /// Server error: a plan limit was reached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your plan\'s limit.'**
  String get errorLimitReached;

  /// Server error: the record does not exist.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find what you were looking for.'**
  String get errorNotFound;

  /// Server error: the record already exists, for example a taken slug.
  ///
  /// In en, this message translates to:
  /// **'This already exists.'**
  String get errorAlreadyExists;

  /// The device could not reach the server.
  ///
  /// In en, this message translates to:
  /// **'You seem to be offline. Check your connection and try again.'**
  String get errorNetwork;

  /// Fallback for any unexpected error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// Server error: signed in, but the restaurant was never created.
  ///
  /// In en, this message translates to:
  /// **'Your account isn\'t set up yet. Add your restaurant details to finish.'**
  String get errorRegistrationIncomplete;

  /// Server error: an administrator signed in without two-factor authentication.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your authenticator code to continue.'**
  String get errorMfaRequired;

  /// Auth error: the email address is malformed.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authErrorInvalidEmail;

  /// Auth error: wrong email or password. Must not reveal which one.
  ///
  /// In en, this message translates to:
  /// **'That email and password don\'t match. Check them and try again.'**
  String get authErrorInvalidCredential;

  /// Auth error: the account is disabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled. Contact support for help.'**
  String get authErrorUserDisabled;

  /// Auth error: registering with an email that already has an account (FR-004).
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in instead, or reset your password.'**
  String get authErrorEmailAlreadyInUse;

  /// Auth error: the password does not meet the policy.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password with at least 8 characters.'**
  String get authErrorWeakPassword;

  /// Auth error: rate limited after repeated attempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get authErrorTooManyRequests;

  /// Auth error: the action needs a recent sign-in.
  ///
  /// In en, this message translates to:
  /// **'For your security, sign in again and retry.'**
  String get authErrorRequiresRecentLogin;

  /// Auth error: a verification or reset link expired.
  ///
  /// In en, this message translates to:
  /// **'This link has expired. Request a new one.'**
  String get authErrorExpiredActionCode;

  /// Auth error: a verification or reset link is invalid or used.
  ///
  /// In en, this message translates to:
  /// **'This link is not valid or was already used. Request a new one.'**
  String get authErrorInvalidActionCode;

  /// Auth error: wrong TOTP code.
  ///
  /// In en, this message translates to:
  /// **'That code is not correct. Enter the current 6-digit code from your authenticator app.'**
  String get authErrorInvalidMfaCode;

  /// Auth error: the multi-factor sign-in session expired.
  ///
  /// In en, this message translates to:
  /// **'This sign-in took too long. Start again.'**
  String get authErrorMfaSessionExpired;

  /// Auth error: MFA enrolment needs a verified email.
  ///
  /// In en, this message translates to:
  /// **'Verify your email address before setting up two-factor authentication.'**
  String get authErrorUnverifiedEmail;

  /// Auth error: a non-admin tried to sign in to the admin app.
  ///
  /// In en, this message translates to:
  /// **'This account is not a platform administrator.'**
  String get authErrorNotAdmin;

  /// Auth error: an admin tried to sign in to the owner app.
  ///
  /// In en, this message translates to:
  /// **'This is an administrator account. Use the admin app to sign in.'**
  String get authErrorAdminAccount;

  /// Auth error: the sign-in method is disabled on the project.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is not available. Contact support.'**
  String get authErrorOperationNotAllowed;

  /// Form validation: empty required field.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get validationRequired;

  /// Form validation: text too long.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters.'**
  String validationTooLong(int max);

  /// Form validation: malformed email (FR-003).
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address, like name@example.com.'**
  String get validationEmail;

  /// Form validation: password too short.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters.'**
  String validationPasswordLength(int min);

  /// Form validation: mobile number not valid for the chosen country (FR-003).
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number for the selected country.'**
  String get validationMobile;

  /// Country name.
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get countryIN;

  /// Country name.
  ///
  /// In en, this message translates to:
  /// **'United Arab Emirates'**
  String get countryAE;

  /// Country name.
  ///
  /// In en, this message translates to:
  /// **'Kuwait'**
  String get countryKW;

  /// Country name.
  ///
  /// In en, this message translates to:
  /// **'Saudi Arabia'**
  String get countrySA;

  /// Country name.
  ///
  /// In en, this message translates to:
  /// **'Qatar'**
  String get countryQA;

  /// Country name.
  ///
  /// In en, this message translates to:
  /// **'Bahrain'**
  String get countryBH;

  /// Country name.
  ///
  /// In en, this message translates to:
  /// **'Oman'**
  String get countryOM;

  /// Country name.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get countryUS;

  /// Business type option.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get businessTypeRestaurant;

  /// Business type option.
  ///
  /// In en, this message translates to:
  /// **'Café'**
  String get businessTypeCafe;

  /// Business type option.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get businessTypeBakery;

  /// Business type option: delivery-only kitchen.
  ///
  /// In en, this message translates to:
  /// **'Cloud kitchen'**
  String get businessTypeCloudKitchen;

  /// Business type option.
  ///
  /// In en, this message translates to:
  /// **'Sweet shop'**
  String get businessTypeSweetShop;

  /// Business type option.
  ///
  /// In en, this message translates to:
  /// **'Juice bar'**
  String get businessTypeJuiceBar;

  /// Business type option.
  ///
  /// In en, this message translates to:
  /// **'Food truck'**
  String get businessTypeFoodTruck;

  /// Business type option.
  ///
  /// In en, this message translates to:
  /// **'Bar or pub'**
  String get businessTypeBar;

  /// Business type option.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get businessTypeHotel;

  /// Business type option.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get businessTypeOther;

  /// Accessibility label of the button that reveals the password.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get actionShowPassword;

  /// Accessibility label of the button that hides the password.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get actionHidePassword;
}

class _CoreLocalizationsDelegate
    extends LocalizationsDelegate<CoreLocalizations> {
  const _CoreLocalizationsDelegate();

  @override
  Future<CoreLocalizations> load(Locale locale) {
    return SynchronousFuture<CoreLocalizations>(
      lookupCoreLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_CoreLocalizationsDelegate old) => false;
}

CoreLocalizations lookupCoreLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return CoreLocalizationsEn();
  }

  throw FlutterError(
    'CoreLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
