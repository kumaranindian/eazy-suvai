import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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

  /// Product name shown in the browser tab and app bar.
  ///
  /// In en, this message translates to:
  /// **'EazySuvai Admin'**
  String get appTitle;

  /// Navigation: platform dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// Navigation: list of restaurants on the platform.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get navRestaurants;

  /// Navigation: subscription plans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get navPlans;

  /// Navigation: platform configuration.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Body of a placeholder screen that a later module replaces.
  ///
  /// In en, this message translates to:
  /// **'This screen is coming soon.'**
  String get placeholderMessage;

  /// Shows the current responsive layout class on placeholder screens.
  ///
  /// In en, this message translates to:
  /// **'Layout: {layout}'**
  String layoutLabel(String layout);

  /// Responsive layout name below 600 px.
  ///
  /// In en, this message translates to:
  /// **'compact'**
  String get layoutCompact;

  /// Responsive layout name from 600 to 1023 px.
  ///
  /// In en, this message translates to:
  /// **'medium'**
  String get layoutMedium;

  /// Responsive layout name from 1024 px.
  ///
  /// In en, this message translates to:
  /// **'expanded'**
  String get layoutExpanded;

  /// Title of the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Title shown for an unknown route.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// Button that returns to the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to dashboard'**
  String get actionGoHome;

  /// Tagline in the brand panel of the admin sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Platform administration. Two-factor sign-in is required.'**
  String get authTagline;

  /// Subtitle of the admin sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your administrator account.'**
  String get signInSubtitle;

  /// Email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// Password field label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// Button that signs in.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// Signs the user out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// Abandons the code step and returns to email and password.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Title of the two-factor code step.
  ///
  /// In en, this message translates to:
  /// **'Enter your code'**
  String get mfaCodeTitle;

  /// Subtitle of the two-factor code step.
  ///
  /// In en, this message translates to:
  /// **'Open your authenticator app and enter the 6-digit code for EazySuvai Admin.'**
  String get mfaCodeSubtitle;

  /// Label of the authenticator code field.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get fieldMfaCode;

  /// Validation: the TOTP code must be 6 digits.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digits from your authenticator app.'**
  String get validationMfaCode;

  /// Submits the authenticator code.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get actionVerify;

  /// Title of the TOTP enrolment screen (FR-084).
  ///
  /// In en, this message translates to:
  /// **'Set up two-factor sign-in'**
  String get mfaSetupTitle;

  /// Subtitle of the TOTP enrolment screen.
  ///
  /// In en, this message translates to:
  /// **'Administrators must use an authenticator app, such as Google Authenticator or Microsoft Authenticator.'**
  String get mfaSetupSubtitle;

  /// Enrolment step 1.
  ///
  /// In en, this message translates to:
  /// **'1. Scan this QR code with your authenticator app.'**
  String get mfaSetupStep1;

  /// Text before the manual TOTP key.
  ///
  /// In en, this message translates to:
  /// **'Or enter this key by hand:'**
  String get mfaSetupStep2;

  /// Enrolment step 3.
  ///
  /// In en, this message translates to:
  /// **'2. Enter the 6-digit code the app shows.'**
  String get mfaSetupStep3;

  /// Accessibility label of the TOTP QR code.
  ///
  /// In en, this message translates to:
  /// **'QR code for your authenticator app'**
  String get mfaQrLabel;

  /// Copies the TOTP secret to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy key'**
  String get actionCopyKey;

  /// Shown after copying the TOTP key.
  ///
  /// In en, this message translates to:
  /// **'Key copied.'**
  String get mfaKeyCopied;

  /// Confirms TOTP enrolment.
  ///
  /// In en, this message translates to:
  /// **'Turn on two-factor sign-in'**
  String get actionEnable;

  /// Shown on the sign-in screen after enrolment.
  ///
  /// In en, this message translates to:
  /// **'Two-factor sign-in is on. Sign in again with your code.'**
  String get mfaEnrolled;

  /// Generates a new TOTP secret.
  ///
  /// In en, this message translates to:
  /// **'Start setup'**
  String get actionStartSetup;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
