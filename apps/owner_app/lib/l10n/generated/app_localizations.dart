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
  /// **'EazySuvai'**
  String get appTitle;

  /// Navigation: owner dashboard.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Navigation: categories and items.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get navMenu;

  /// Navigation: QR codes and sharing.
  ///
  /// In en, this message translates to:
  /// **'QR & share'**
  String get navShare;

  /// Navigation: restaurant profile and account settings.
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

  /// Button that returns to the home screen.
  ///
  /// In en, this message translates to:
  /// **'Go to home'**
  String get actionGoHome;

  /// Tagline in the brand panel of the sign-in and sign-up screens.
  ///
  /// In en, this message translates to:
  /// **'Your menu, live in minutes. Scan, browse, enjoy.'**
  String get authTagline;

  /// Subtitle of the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Welcome back. Sign in to manage your menu.'**
  String get signInSubtitle;

  /// Email address field label.
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

  /// Link to the password reset screen.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get actionForgotPassword;

  /// Text before the link to sign up.
  ///
  /// In en, this message translates to:
  /// **'New to EazySuvai?'**
  String get signInNoAccount;

  /// Link or button to the sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get actionSignUp;

  /// Signs the user out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// Title of the sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpTitle;

  /// Subtitle of the sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Start free. Your restaurant gets its own menu link and QR code.'**
  String get signUpSubtitle;

  /// Sign-up section heading for restaurant details.
  ///
  /// In en, this message translates to:
  /// **'Your restaurant'**
  String get signUpSectionRestaurant;

  /// Sign-up section heading for the owner's details.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get signUpSectionOwner;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Restaurant name'**
  String get fieldRestaurantName;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get fieldBusinessType;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get fieldCountry;

  /// Field label for the optional city.
  ///
  /// In en, this message translates to:
  /// **'City (optional)'**
  String get fieldCity;

  /// Helper text explaining why we ask for the city (slug suffix, FR-092).
  ///
  /// In en, this message translates to:
  /// **'Helps keep your menu link unique.'**
  String get fieldCityHelper;

  /// Field label for the owner's name.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get fieldOwnerName;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get fieldMobile;

  /// Password rule shown under the new-password field.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get fieldPasswordHelper;

  /// Submit button of the sign-up form.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get actionCreateAccount;

  /// Text before the link to sign in.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get signUpHaveAccount;

  /// Title when a signed-in owner still needs to add restaurant details.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up'**
  String get signUpCompleteTitle;

  /// Subtitle of the complete-registration form.
  ///
  /// In en, this message translates to:
  /// **'Add your restaurant details to finish creating your account.'**
  String get signUpCompleteSubtitle;

  /// Submit button of the complete-registration form.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get actionFinishSetup;

  /// Title of the verify-email screen.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get verifyTitle;

  /// Verify-email message.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}. Open it to activate your account, then sign in.'**
  String verifyBody(String email);

  /// Verify-email message when the address is unknown.
  ///
  /// In en, this message translates to:
  /// **'We sent you a verification link. Open it to activate your account, then sign in.'**
  String get verifyBodyNoEmail;

  /// Shown when an unverified owner tries to sign in (FR-091).
  ///
  /// In en, this message translates to:
  /// **'Verify your email address before you sign in. Didn\'t get the email? Send it again.'**
  String get verifyRequired;

  /// Help text on the verify-email screen.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find it? Check your spam folder. Unverified accounts are removed after 7 days.'**
  String get verifyHint;

  /// Button that sends the verification email again.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get actionResend;

  /// Disabled resend button with countdown.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String actionResendIn(int seconds);

  /// Confirmation after resending the verification email.
  ///
  /// In en, this message translates to:
  /// **'We sent a new verification link.'**
  String get verifySent;

  /// Shown when the resend button cannot be used (for example after a page reload).
  ///
  /// In en, this message translates to:
  /// **'To get a new link, sign in again.'**
  String get verifySignInToResend;

  /// Button that returns to the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get actionBackToSignIn;

  /// Title of the forgot-password screen.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// Subtitle of the forgot-password screen.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email. We\'ll send you a link to choose a new password.'**
  String get forgotSubtitle;

  /// Button that sends the password reset email.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get actionSendResetLink;

  /// Confirmation after requesting a reset (does not reveal whether the account exists).
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, we\'ve sent a reset link. It works once and expires in 1 hour.'**
  String forgotSent(String email);

  /// Title while the app waits for the account to be ready.
  ///
  /// In en, this message translates to:
  /// **'Finishing setup…'**
  String get finishingTitle;

  /// Body while waiting for the account claims.
  ///
  /// In en, this message translates to:
  /// **'We\'re getting your restaurant ready. This takes a few seconds.'**
  String get finishingBody;

  /// Title of the developer-only page for trying image uploads (not in production).
  ///
  /// In en, this message translates to:
  /// **'Image upload test'**
  String get devMediaTitle;

  /// Intro text on the developer-only image upload page.
  ///
  /// In en, this message translates to:
  /// **'Developer page. Images uploaded here become your restaurant\'s logo and cover.'**
  String get devMediaIntro;

  /// Label of the logo image field.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get devMediaLogo;

  /// Label of the cover image field.
  ///
  /// In en, this message translates to:
  /// **'Cover image'**
  String get devMediaCover;
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
