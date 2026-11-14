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

  /// Goes to the previous step.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// Goes to the next step.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// Confirms a choice and closes the sheet.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// Saves draft changes immediately instead of waiting for autosave.
  ///
  /// In en, this message translates to:
  /// **'Save now'**
  String get actionSaveNow;

  /// Save indicator before any change.
  ///
  /// In en, this message translates to:
  /// **'Changes save automatically'**
  String get saveAuto;

  /// Save indicator while changes are waiting or being written.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saveSaving;

  /// Save indicator after changes were stored in the draft.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saveSaved;

  /// Save indicator when the last save failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your changes'**
  String get saveFailed;

  /// Save indicator when some fields are not valid.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted fields to save'**
  String get saveInvalid;

  /// Title of the profile editor.
  ///
  /// In en, this message translates to:
  /// **'Restaurant profile'**
  String get profileTitle;

  /// Profile section: name, business type, description.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get profileSectionBasics;

  /// Profile section: images.
  ///
  /// In en, this message translates to:
  /// **'Logo and cover'**
  String get profileSectionImages;

  /// Profile section: phone, email, website.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get profileSectionContact;

  /// Profile section: address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileSectionAddress;

  /// Profile section: opening hours summary.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get profileSectionHours;

  /// Profile section: social network links.
  ///
  /// In en, this message translates to:
  /// **'Social links'**
  String get profileSectionSocial;

  /// Help text for the social links section.
  ///
  /// In en, this message translates to:
  /// **'Paste a link, or type @yourname for Instagram, X and YouTube.'**
  String get profileSectionSocialHelp;

  /// Profile section: which details the public menu shows (FR-013).
  ///
  /// In en, this message translates to:
  /// **'Show on your menu'**
  String get profileSectionVisibility;

  /// Help text for the visibility switches.
  ///
  /// In en, this message translates to:
  /// **'Turn off anything you don\'t want customers to see. Your details stay saved.'**
  String get profileSectionVisibilityHelp;

  /// Field label: restaurant description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// Helper under the description field.
  ///
  /// In en, this message translates to:
  /// **'What makes your place special? Up to 500 characters.'**
  String get fieldDescriptionHelper;

  /// Image field label: restaurant logo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get fieldLogo;

  /// Image field label: wide cover image.
  ///
  /// In en, this message translates to:
  /// **'Cover image'**
  String get fieldCover;

  /// Field label: public phone number.
  ///
  /// In en, this message translates to:
  /// **'Contact number'**
  String get fieldPhone;

  /// Helper under the contact number field.
  ///
  /// In en, this message translates to:
  /// **'Mobile or landline, for customers to call.'**
  String get fieldPhoneHelper;

  /// Field label: public business email.
  ///
  /// In en, this message translates to:
  /// **'Public email'**
  String get fieldPublicEmail;

  /// Field label: website (https).
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get fieldWebsite;

  /// Field label: address line.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get fieldAddress;

  /// Helper under the address field.
  ///
  /// In en, this message translates to:
  /// **'Building, street and area.'**
  String get fieldAddressHelper;

  /// Field label: city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get fieldCityPlain;

  /// Hint in a social link field.
  ///
  /// In en, this message translates to:
  /// **'Link or @handle'**
  String get fieldSocialHint;

  /// Hint in the Google Maps link field.
  ///
  /// In en, this message translates to:
  /// **'Link from Google Maps → Share'**
  String get fieldMapsHint;

  /// Field label: menu currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get fieldCurrency;

  /// Visibility switch and preview label.
  ///
  /// In en, this message translates to:
  /// **'Contact number'**
  String get visibilityPhone;

  /// Visibility switch and preview label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get visibilityEmail;

  /// Visibility switch and preview label.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get visibilityAddress;

  /// Visibility switch and preview label.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get visibilityHours;

  /// Visibility switch and preview label.
  ///
  /// In en, this message translates to:
  /// **'Social links'**
  String get visibilitySocial;

  /// Title of the live preview of the public menu header.
  ///
  /// In en, this message translates to:
  /// **'Menu preview'**
  String get previewTitle;

  /// Preview placeholder when the name is empty.
  ///
  /// In en, this message translates to:
  /// **'Your restaurant'**
  String get previewNoName;

  /// Preview: today's opening hours.
  ///
  /// In en, this message translates to:
  /// **'Today: {hours}'**
  String previewHoursToday(String hours);

  /// Preview: the restaurant is closed today.
  ///
  /// In en, this message translates to:
  /// **'Closed today'**
  String get previewClosedToday;

  /// Preview: which details are hidden (FR-013).
  ///
  /// In en, this message translates to:
  /// **'Hidden from customers: {fields}'**
  String previewHidden(String fields);

  /// Title of the opening hours screen.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get hoursTitle;

  /// Intro on the opening hours screen.
  ///
  /// In en, this message translates to:
  /// **'Times are in your restaurant\'s time zone ({zone}). Add up to 3 time slots a day, or mark a day as closed.'**
  String hoursIntro(String zone);

  /// Shown when no opening hours were added.
  ///
  /// In en, this message translates to:
  /// **'No opening hours yet'**
  String get hoursNotSet;

  /// Settings summary when opening hours exist.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get hoursSet;

  /// Body of the empty opening hours state.
  ///
  /// In en, this message translates to:
  /// **'Tell customers when you\'re open. We\'ll start with every day 9:00 to 22:00; adjust it to fit.'**
  String get hoursEmptyMessage;

  /// Button that adds opening hours.
  ///
  /// In en, this message translates to:
  /// **'Add opening hours'**
  String get hoursAdd;

  /// Button that opens the opening hours editor.
  ///
  /// In en, this message translates to:
  /// **'Edit opening hours'**
  String get hoursEdit;

  /// A day is open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get hoursOpen;

  /// A day is closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get hoursClosed;

  /// A day is open all day.
  ///
  /// In en, this message translates to:
  /// **'Open 24 hours'**
  String get hoursAllDay;

  /// Screen-reader label of the open/closed switch.
  ///
  /// In en, this message translates to:
  /// **'Open on {day}'**
  String hoursOpenOn(String day);

  /// Time field label.
  ///
  /// In en, this message translates to:
  /// **'Opens'**
  String get hoursOpens;

  /// Time field label.
  ///
  /// In en, this message translates to:
  /// **'Closes'**
  String get hoursCloses;

  /// Adds another time slot to a day.
  ///
  /// In en, this message translates to:
  /// **'Add time slot'**
  String get hoursAddSlot;

  /// Removes a time slot.
  ///
  /// In en, this message translates to:
  /// **'Remove time slot'**
  String get hoursRemoveSlot;

  /// Copies one day's hours to all days.
  ///
  /// In en, this message translates to:
  /// **'Copy {day}\'s hours to every day'**
  String hoursCopyToAll(String day);

  /// Title of the bottom sheet with time pickers.
  ///
  /// In en, this message translates to:
  /// **'{day} hours'**
  String hoursSheetTitle(String day);

  /// Hint in the time picker sheet.
  ///
  /// In en, this message translates to:
  /// **'A closing time earlier than the opening time runs past midnight.'**
  String get hoursOvernightHint;

  /// Error for a badly formatted time.
  ///
  /// In en, this message translates to:
  /// **'Use 24-hour time, like 09:30'**
  String get hoursTimeFormat;

  /// Removes all opening hours.
  ///
  /// In en, this message translates to:
  /// **'Remove opening hours'**
  String get hoursRemoveAll;

  /// Confirm dialog title.
  ///
  /// In en, this message translates to:
  /// **'Remove opening hours?'**
  String get hoursRemoveAllTitle;

  /// Confirm dialog body.
  ///
  /// In en, this message translates to:
  /// **'Your menu will no longer show when you\'re open. You can add hours again at any time.'**
  String get hoursRemoveAllMessage;

  /// Title of the regional settings screen.
  ///
  /// In en, this message translates to:
  /// **'Currency and time zone'**
  String get regionalTitle;

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get regionalSectionCountry;

  /// Explains the country is read-only.
  ///
  /// In en, this message translates to:
  /// **'Set when you signed up. Contact support to change it.'**
  String get regionalCountryLocked;

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get regionalSectionCurrency;

  /// Help text for the currency.
  ///
  /// In en, this message translates to:
  /// **'Your menu shows every price in this currency.'**
  String get regionalCurrencyHelp;

  /// Section title.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get regionalSectionTimezone;

  /// Help text for the time zone.
  ///
  /// In en, this message translates to:
  /// **'Used for your opening hours and for analytics days.'**
  String get regionalTimezoneHelp;

  /// Title of the time zone picker.
  ///
  /// In en, this message translates to:
  /// **'Choose a time zone'**
  String get regionalTimezonePick;

  /// Search field in the time zone picker.
  ///
  /// In en, this message translates to:
  /// **'Search, for example Kolkata'**
  String get regionalTimezoneSearch;

  /// Heading in the time zone picker.
  ///
  /// In en, this message translates to:
  /// **'Suggested for your country'**
  String get regionalTimezoneSuggested;

  /// Heading in the time zone picker.
  ///
  /// In en, this message translates to:
  /// **'All time zones'**
  String get regionalTimezoneAll;

  /// Banner when pricesNeedReview is set (FR-103).
  ///
  /// In en, this message translates to:
  /// **'You changed the currency after publishing. Prices were not converted: review every price before you publish again.'**
  String get regionalPricesNeedReview;

  /// Currency dropdown item.
  ///
  /// In en, this message translates to:
  /// **'{name} ({code})'**
  String currencyOption(String name, String code);

  /// FR-103 dialog title.
  ///
  /// In en, this message translates to:
  /// **'Switch to {code}?'**
  String currencyWarningTitle(String code);

  /// FR-103 warning after the first publish.
  ///
  /// In en, this message translates to:
  /// **'Prices are not converted. A price of 100 {from} becomes 100 {to}. Your live menu keeps {from} until you publish, and you\'ll need to review every price before the next publish.'**
  String currencyWarningPublished(String from, String to);

  /// Currency change warning when items exist but the menu was never published.
  ///
  /// In en, this message translates to:
  /// **'Prices are not converted. A price of 100 {from} becomes 100 {to}. Check your item prices after the change.'**
  String currencyWarningDraft(String from, String to);

  /// Confirms the currency change.
  ///
  /// In en, this message translates to:
  /// **'Change currency'**
  String get currencyWarningConfirm;

  /// Title of the menu link (slug) screen.
  ///
  /// In en, this message translates to:
  /// **'Menu link'**
  String get menuLinkTitle;

  /// Section with the current public menu URL.
  ///
  /// In en, this message translates to:
  /// **'Your menu link'**
  String get menuLinkCurrent;

  /// Note that QR codes never change (BR-006).
  ///
  /// In en, this message translates to:
  /// **'Your QR code always works, even if you change this link.'**
  String get menuLinkQrNote;

  /// Copies the menu link.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get menuLinkCopy;

  /// Snackbar after copying the link.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get menuLinkCopied;

  /// Section to change the slug.
  ///
  /// In en, this message translates to:
  /// **'Change the link'**
  String get menuLinkChange;

  /// FR-092/093 rules for the slug.
  ///
  /// In en, this message translates to:
  /// **'3 to 60 lowercase letters, numbers and hyphens. Your old link will keep working and send customers to the new one.'**
  String get menuLinkRules;

  /// Field label: new slug.
  ///
  /// In en, this message translates to:
  /// **'New link'**
  String get menuLinkNew;

  /// Availability check in progress.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get menuLinkChecking;

  /// Availability check succeeded.
  ///
  /// In en, this message translates to:
  /// **'This link is available.'**
  String get menuLinkAvailable;

  /// Saves the new slug.
  ///
  /// In en, this message translates to:
  /// **'Change link'**
  String get menuLinkSave;

  /// Confirm dialog title.
  ///
  /// In en, this message translates to:
  /// **'Change your menu link?'**
  String get menuLinkConfirmTitle;

  /// Confirm dialog body.
  ///
  /// In en, this message translates to:
  /// **'Your menu will move to {newUrl}. The old link {oldUrl} keeps working and redirects there, and your QR code does not change.'**
  String menuLinkConfirmMessage(String newUrl, String oldUrl);

  /// Confirms the slug change.
  ///
  /// In en, this message translates to:
  /// **'Change link'**
  String get menuLinkConfirmAction;

  /// Snackbar after a successful slug change.
  ///
  /// In en, this message translates to:
  /// **'Your menu link was changed.'**
  String get menuLinkChanged;

  /// Setup checklist title.
  ///
  /// In en, this message translates to:
  /// **'Get your menu ready'**
  String get checklistTitle;

  /// Setup checklist title when everything is done.
  ///
  /// In en, this message translates to:
  /// **'Your menu is set up'**
  String get checklistDoneTitle;

  /// Setup checklist progress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String checklistProgress(int done, int total);

  /// Screen-reader label: step done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get checklistStepDone;

  /// Screen-reader label: step not done.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get checklistStepTodo;

  /// Checklist step.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get checklistProfile;

  /// Checklist hint.
  ///
  /// In en, this message translates to:
  /// **'Add a description, a phone number or email, and your address.'**
  String get checklistProfileHint;

  /// Checklist step.
  ///
  /// In en, this message translates to:
  /// **'Add your logo'**
  String get checklistLogo;

  /// Checklist hint.
  ///
  /// In en, this message translates to:
  /// **'A square logo, at least 256 × 256 px.'**
  String get checklistLogoHint;

  /// Checklist step.
  ///
  /// In en, this message translates to:
  /// **'Add menu categories'**
  String get checklistCategories;

  /// Checklist hint.
  ///
  /// In en, this message translates to:
  /// **'For example Starters, Mains, Desserts.'**
  String get checklistCategoriesHint;

  /// Checklist step.
  ///
  /// In en, this message translates to:
  /// **'Add dishes'**
  String get checklistItems;

  /// Checklist hint.
  ///
  /// In en, this message translates to:
  /// **'Add names, prices and photos.'**
  String get checklistItemsHint;

  /// Checklist step.
  ///
  /// In en, this message translates to:
  /// **'Choose a theme'**
  String get checklistTheme;

  /// Checklist hint.
  ///
  /// In en, this message translates to:
  /// **'Pick colours and fonts that match your brand.'**
  String get checklistThemeHint;

  /// Checklist step.
  ///
  /// In en, this message translates to:
  /// **'Publish your menu'**
  String get checklistPublish;

  /// Checklist hint.
  ///
  /// In en, this message translates to:
  /// **'Customers see your menu once it\'s published.'**
  String get checklistPublishHint;

  /// Dashboard card title.
  ///
  /// In en, this message translates to:
  /// **'Menu status'**
  String get statusTitle;

  /// Menu not published yet.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// Menu published.
  ///
  /// In en, this message translates to:
  /// **'Live · version {version}'**
  String statusLive(int version);

  /// Explains the draft state (FR-012).
  ///
  /// In en, this message translates to:
  /// **'Customers can\'t see your menu yet. Changes are saved as a draft until you publish.'**
  String get statusDraftHelp;

  /// Explains the live state.
  ///
  /// In en, this message translates to:
  /// **'Customers see your last published version. New changes wait in the draft until you publish.'**
  String get statusLiveHelp;

  /// Counts of categories and items.
  ///
  /// In en, this message translates to:
  /// **'Categories: {categories} · Dishes: {items}'**
  String statusCounts(int categories, int items);

  /// When the draft was last changed, in the restaurant time zone.
  ///
  /// In en, this message translates to:
  /// **'Last change: {time}'**
  String statusLastEdit(String time);

  /// Button to the menu section.
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get statusOpenMenu;

  /// Dashboard card title.
  ///
  /// In en, this message translates to:
  /// **'QR code and link'**
  String get qrTitle;

  /// Dashboard card body.
  ///
  /// In en, this message translates to:
  /// **'Customers scan your QR code or open this link to see your menu.'**
  String get qrHelp;

  /// The restaurant QR short code.
  ///
  /// In en, this message translates to:
  /// **'QR code: {code}'**
  String qrCode(String code);

  /// Button to the QR section.
  ///
  /// In en, this message translates to:
  /// **'QR & share'**
  String get qrOpenShare;

  /// Button to the menu link screen.
  ///
  /// In en, this message translates to:
  /// **'Change link'**
  String get qrChangeLink;

  /// Setup wizard title.
  ///
  /// In en, this message translates to:
  /// **'Set up your restaurant'**
  String get wizardTitle;

  /// Skips the setup wizard.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get wizardSkip;

  /// Skips an optional wizard step.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get wizardSkipStep;

  /// Wizard progress.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String wizardStepOf(int step, int total);

  /// Wizard step 1 title.
  ///
  /// In en, this message translates to:
  /// **'Your restaurant'**
  String get wizardStepProfile;

  /// Wizard step 2 title.
  ///
  /// In en, this message translates to:
  /// **'Logo and cover'**
  String get wizardStepImages;

  /// Wizard step 3 title.
  ///
  /// In en, this message translates to:
  /// **'Build your menu'**
  String get wizardStepMenu;

  /// Wizard step 1 intro.
  ///
  /// In en, this message translates to:
  /// **'Tell customers about your place. You can change everything later in Settings.'**
  String get wizardProfileIntro;

  /// Wizard step 2 intro.
  ///
  /// In en, this message translates to:
  /// **'A logo and a wide cover photo make your menu look like yours. Both are optional.'**
  String get wizardImagesIntro;

  /// Wizard step 3 intro.
  ///
  /// In en, this message translates to:
  /// **'Next, build your menu. Here\'s how it works:'**
  String get wizardMenuIntro;

  /// Wizard step 3 bullet.
  ///
  /// In en, this message translates to:
  /// **'Create categories such as Starters, Mains and Drinks.'**
  String get wizardMenuCategories;

  /// Wizard step 3 bullet.
  ///
  /// In en, this message translates to:
  /// **'Add dishes with prices, photos and dietary labels.'**
  String get wizardMenuItems;

  /// Wizard step 3 bullet.
  ///
  /// In en, this message translates to:
  /// **'Choose a theme to match your brand.'**
  String get wizardMenuTheme;

  /// Wizard step 3 bullet.
  ///
  /// In en, this message translates to:
  /// **'Preview, then publish. Your QR code starts working at once.'**
  String get wizardMenuPublish;

  /// Finishes the wizard and opens the menu section.
  ///
  /// In en, this message translates to:
  /// **'Start my menu'**
  String get wizardToMenu;

  /// Finishes the wizard and opens the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to dashboard'**
  String get wizardToDashboard;

  /// Button: create the new category or item.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// Button: close a panel or dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Button: delete (moves to Recently deleted).
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Button: throw away unsaved changes.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get actionDiscard;

  /// Menu action: edit this entry.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// Menu action: keyboard alternative to dragging an entry down (FR-019).
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get actionMoveDown;

  /// Menu action: keyboard alternative to dragging an entry up (FR-019).
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get actionMoveUp;

  /// Button: dismiss the upgrade prompt.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get actionNotNow;

  /// Button: restore a deleted category or item.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get actionRestore;

  /// Button: save changes.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Snack bar action: undo the last delete.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// Button: go to the plans screen.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get actionUpgrade;

  /// Heading of the category list.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get menuCategoriesTitle;

  /// Heading of the deleted items list.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get menuItemsTitle;

  /// Button: create a category.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get menuAddCategory;

  /// Button: create an item in the current category.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get menuAddItem;

  /// Category list entry that shows every item.
  ///
  /// In en, this message translates to:
  /// **'All items'**
  String get menuAllItems;

  /// Number of items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String menuItemCount(int count);

  /// Category subtitle: inactive, not on the public menu (FR-020).
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get menuCategoryHidden;

  /// Screen reader label of the category active switch.
  ///
  /// In en, this message translates to:
  /// **'Show {name} on the menu'**
  String menuCategoryActiveLabel(String name);

  /// Tooltip of a row's overflow menu.
  ///
  /// In en, this message translates to:
  /// **'More options for {name}'**
  String menuMoreFor(String name);

  /// Tooltip of a drag handle.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get menuDragToReorder;

  /// Title and button: deleted categories and items (FR-098).
  ///
  /// In en, this message translates to:
  /// **'Recently deleted'**
  String get menuRecentlyDeleted;

  /// Empty state: no categories.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get menuNoCategoriesTitle;

  /// Empty state: no categories.
  ///
  /// In en, this message translates to:
  /// **'Start with sections such as Starters, Main course or Beverages.'**
  String get menuNoCategoriesMessage;

  /// Category dialog title.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get menuCategoryNew;

  /// Category dialog title and button.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get menuCategoryEdit;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get menuFieldCategoryName;

  /// Field hint.
  ///
  /// In en, this message translates to:
  /// **'For example, Starters'**
  String get menuFieldCategoryNameHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get menuFieldDescriptionOptional;

  /// Switch: category active (FR-016, FR-020).
  ///
  /// In en, this message translates to:
  /// **'Show on the menu'**
  String get menuFieldCategoryActive;

  /// Help for the category active switch.
  ///
  /// In en, this message translates to:
  /// **'When off, this category and its items are hidden from customers.'**
  String get menuFieldCategoryActiveHelp;

  /// Image field label.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get menuFieldPhoto;

  /// Shown while creating: an image needs the saved document (M02).
  ///
  /// In en, this message translates to:
  /// **'You can add a photo after saving.'**
  String get menuPhotoAfterSave;

  /// Validation: name empty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get menuErrorNameRequired;

  /// Validation: no category (BR-004).
  ///
  /// In en, this message translates to:
  /// **'Choose a category.'**
  String get menuErrorCategoryRequired;

  /// Validation: no dietary label (FR-023).
  ///
  /// In en, this message translates to:
  /// **'Choose a dietary classification.'**
  String get menuErrorDietaryRequired;

  /// Snack bar after creating a category.
  ///
  /// In en, this message translates to:
  /// **'{name} added.'**
  String menuCategoryAdded(String name);

  /// Delete category dialog title and button label.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String menuDeleteCategoryTitle(String name);

  /// Delete an empty category (FR-018).
  ///
  /// In en, this message translates to:
  /// **'This category has no items. You can restore it from Recently deleted for 30 days.'**
  String get menuDeleteCategoryEmpty;

  /// Delete a category with items (FR-018).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This category has 1 item. What should happen to it?} other{This category has {count} items. What should happen to them?}}'**
  String menuDeleteCategoryHasItems(int count);

  /// Delete category option 1 (FR-018).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Move the item to another category} other{Move the {count} items to another category}}'**
  String menuDeleteModeMove(int count);

  /// Delete category: no other category to move items to.
  ///
  /// In en, this message translates to:
  /// **'Add another category first.'**
  String get menuDeleteModeMoveNone;

  /// Dropdown label: target category.
  ///
  /// In en, this message translates to:
  /// **'Move items to'**
  String get menuDeleteMoveTo;

  /// Delete category option 2 (FR-018).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete the category and its item} other{Delete the category and all {count} items}}'**
  String menuDeleteModeAll(int count);

  /// Typed confirmation (FR-018, AC-027).
  ///
  /// In en, this message translates to:
  /// **'To confirm, type the category name: {name}'**
  String menuDeleteTypeName(String name);

  /// Note in delete dialogs (FR-098).
  ///
  /// In en, this message translates to:
  /// **'Deleted content stays in Recently deleted for 30 days.'**
  String get menuDeleteRestoreNote;

  /// Confirm button: move items then delete the category.
  ///
  /// In en, this message translates to:
  /// **'Move items and delete'**
  String get menuDeleteMoveConfirm;

  /// Confirm button: delete category and items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete category and 1 item} other{Delete category and {count} items}}'**
  String menuDeleteAllConfirm(int count);

  /// Snack bar after a delete.
  ///
  /// In en, this message translates to:
  /// **'{name} moved to Recently deleted.'**
  String menuDeletedToBin(String name);

  /// Snack bar after deleting a category and moving its items.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted. {count, plural, =1{1 item was moved.} other{{count} items were moved.}}'**
  String menuCategoryDeletedMoved(String name, int count);

  /// Search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get menuSearchHint;

  /// Tooltip: clear the search.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get menuSearchClear;

  /// Filter chip: unavailable items only (FRD 5.4).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Sold out} other{Sold out ({count})}}'**
  String menuFilterSoldOut(int count);

  /// Filter chip: featured items only.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get menuFilterFeatured;

  /// Empty state: category without items.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get menuNoItemsTitle;

  /// Empty state: category without items.
  ///
  /// In en, this message translates to:
  /// **'Add the dishes and drinks in this category.'**
  String get menuNoItemsMessage;

  /// Empty state: no items at all.
  ///
  /// In en, this message translates to:
  /// **'Choose a category and add your first item.'**
  String get menuNoItemsAll;

  /// Empty state: search or filters match nothing.
  ///
  /// In en, this message translates to:
  /// **'No matching items'**
  String get menuNoMatchTitle;

  /// Empty state: search or filters match nothing.
  ///
  /// In en, this message translates to:
  /// **'Try another search or clear the filters.'**
  String get menuNoMatchMessage;

  /// Item row: the item is unavailable (FR-026).
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get menuSoldOut;

  /// Screen reader label of an item's availability switch (FR-025).
  ///
  /// In en, this message translates to:
  /// **'{name} available'**
  String menuAvailableLabel(String name);

  /// Screen reader label of an item's bulk-select checkbox.
  ///
  /// In en, this message translates to:
  /// **'Select {name}'**
  String menuSelectItem(String name);

  /// Screen reader label: select every listed item.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get menuSelectAll;

  /// Bulk bar: number of selected items.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String menuSelectedCount(int count);

  /// Bulk action: make items available.
  ///
  /// In en, this message translates to:
  /// **'Mark available'**
  String get menuBulkAvailable;

  /// Bulk action: make items unavailable.
  ///
  /// In en, this message translates to:
  /// **'Mark sold out'**
  String get menuBulkSoldOut;

  /// Action: move items to another category (FR-097).
  ///
  /// In en, this message translates to:
  /// **'Move to category'**
  String get menuMoveToCategory;

  /// Category picker title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Move item to} other{Move {count} items to}}'**
  String menuMoveItemsTitle(int count);

  /// Snack bar after moving items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Item moved to {name}.} other{{count} items moved to {name}.}}'**
  String menuItemsMoved(int count, String name);

  /// Delete items dialog title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete this item?} other{Delete {count} items?}}'**
  String menuDeleteItemsTitle(int count);

  /// Delete items dialog message (FR-098).
  ///
  /// In en, this message translates to:
  /// **'You can restore deleted items from Recently deleted for 30 days.'**
  String get menuDeleteItemsMessage;

  /// Button in the item editor.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get menuDeleteItem;

  /// Item editor title.
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get menuItemNew;

  /// Item editor title.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get menuItemEdit;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get menuFieldItemName;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get menuFieldCategory;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get menuFieldPrice;

  /// Section label: exactly one label (FR-023).
  ///
  /// In en, this message translates to:
  /// **'Dietary classification'**
  String get menuFieldDietary;

  /// Section label: optional tags (FR-033).
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get menuFieldTags;

  /// Switch: item availability (FR-025).
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get menuFieldAvailable;

  /// Help for availability (FR-095).
  ///
  /// In en, this message translates to:
  /// **'Turn off when sold out. Customers see it at once, without publishing.'**
  String get menuFieldAvailableHelp;

  /// Switch and label: featured item (FR-027).
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get menuFieldFeatured;

  /// Help for featured.
  ///
  /// In en, this message translates to:
  /// **'Highlight this item on your menu.'**
  String get menuFieldFeaturedHelp;

  /// Shown when the platform label list is empty.
  ///
  /// In en, this message translates to:
  /// **'Dietary labels are not available right now. Try again later.'**
  String get menuLabelsUnavailable;

  /// Snack bar after creating an item.
  ///
  /// In en, this message translates to:
  /// **'{name} added. You can add a photo now.'**
  String menuItemAdded(String name);

  /// Snack bar after saving an item.
  ///
  /// In en, this message translates to:
  /// **'Changes saved to the draft.'**
  String get menuItemSaved;

  /// Editor footer: there are unsaved edits.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get menuUnsaved;

  /// Dialog: leave the editor with unsaved edits.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get menuDiscardTitle;

  /// Dialog: leave the editor with unsaved edits.
  ///
  /// In en, this message translates to:
  /// **'Your changes to this item will be lost.'**
  String get menuDiscardMessage;

  /// Editor: the item was deleted or moved.
  ///
  /// In en, this message translates to:
  /// **'Item not found'**
  String get menuItemGoneTitle;

  /// Editor: the item was deleted.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted on another device.'**
  String get menuItemGoneMessage;

  /// Category page: deleted elsewhere.
  ///
  /// In en, this message translates to:
  /// **'Category not found'**
  String get menuCategoryGoneTitle;

  /// Category page: deleted elsewhere.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted on another device.'**
  String get menuCategoryGoneMessage;

  /// Editor: no categories exist (BR-004).
  ///
  /// In en, this message translates to:
  /// **'Add a category before adding items.'**
  String get menuItemNeedsCategory;

  /// Editor pane placeholder.
  ///
  /// In en, this message translates to:
  /// **'No item selected'**
  String get menuEditorEmptyTitle;

  /// Editor pane placeholder.
  ///
  /// In en, this message translates to:
  /// **'Choose an item to edit it here, or add a new one.'**
  String get menuEditorEmptyMessage;

  /// Dialog title (BR-011).
  ///
  /// In en, this message translates to:
  /// **'Plan limit reached'**
  String get menuLimitTitle;

  /// Plan limit dialog: items.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =1{Your plan allows 1 item.} other{Your plan allows {max} items.}} Upgrade to add more, or delete items you no longer need.'**
  String menuLimitItems(int max);

  /// Plan limit dialog: categories.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =1{Your plan allows 1 category.} other{Your plan allows {max} categories.}} Upgrade to add more, or delete categories you no longer need.'**
  String menuLimitCategories(int max);

  /// Plan limit dialog without details.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached a limit of your plan. Upgrade to add more.'**
  String get menuLimitGeneric;

  /// Recently deleted intro (FR-098).
  ///
  /// In en, this message translates to:
  /// **'Deleted categories and items can be restored for 30 days. Restored content goes back to your draft; publish to show it to customers.'**
  String get menuDeletedIntro;

  /// Recently deleted empty state.
  ///
  /// In en, this message translates to:
  /// **'Nothing deleted'**
  String get menuDeletedEmptyTitle;

  /// Recently deleted empty state.
  ///
  /// In en, this message translates to:
  /// **'Categories and items you delete appear here for 30 days.'**
  String get menuDeletedEmptyMessage;

  /// Time left to restore (FR-098).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Less than a day left} =1{1 day left} other{{days} days left}}'**
  String menuDeletedDaysLeft(int days);

  /// Deleted category: items that come back with it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{With 1 item} other{With {count} items}}'**
  String menuDeletedWithItems(int count);

  /// Deleted item whose category is deleted too.
  ///
  /// In en, this message translates to:
  /// **'{name} (deleted)'**
  String menuDeletedCategoryGone(String name);

  /// Screen reader label of a Restore button.
  ///
  /// In en, this message translates to:
  /// **'Restore {name}'**
  String menuRestoreLabel(String name);

  /// Category picker title when an item's category is deleted (BR-004).
  ///
  /// In en, this message translates to:
  /// **'Restore {name} into'**
  String menuRestoreInto(String name);

  /// No category to restore an item into.
  ///
  /// In en, this message translates to:
  /// **'Add or restore a category first.'**
  String get menuRestoreNeedsCategory;

  /// Snack bar after a restore.
  ///
  /// In en, this message translates to:
  /// **'{name} restored to your draft.'**
  String menuRestored(String name);

  /// Plans screen title.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get planTitle;

  /// Plans placeholder until M10.
  ///
  /// In en, this message translates to:
  /// **'Upgrading from the app is coming soon. Contact EazySuvai support to change your plan.'**
  String get planComingSoon;
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
