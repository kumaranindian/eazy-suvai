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

  /// Server error: the menu link (slug) breaks the FR-092 format.
  ///
  /// In en, this message translates to:
  /// **'Use 3 to 60 lowercase letters, numbers and single hyphens, not starting or ending with a hyphen.'**
  String get errorSlugInvalid;

  /// Server error: the menu link is a reserved word.
  ///
  /// In en, this message translates to:
  /// **'This link is reserved. Choose another one.'**
  String get errorSlugReserved;

  /// Server error: the menu link is used by another restaurant.
  ///
  /// In en, this message translates to:
  /// **'Another restaurant already uses this link. Try adding your area or city.'**
  String get errorSlugTaken;

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

  /// Button that opens the photo library or file dialog to add an image.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get imageAdd;

  /// Button that picks a new image in place of the current one.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get imageReplace;

  /// Button that removes the current image.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get imageRemove;

  /// Title of the dialog that confirms removing an image.
  ///
  /// In en, this message translates to:
  /// **'Remove this image?'**
  String get imageRemoveTitle;

  /// Body of the dialog that confirms removing an image.
  ///
  /// In en, this message translates to:
  /// **'You can add a new image at any time.'**
  String get imageRemoveMessage;

  /// Help text under an image field (FR-102).
  ///
  /// In en, this message translates to:
  /// **'JPEG, PNG or WebP, up to 5 MB, at least {width} × {height} px.'**
  String imageHint(int width, int height);

  /// Shown while a picked image is checked, cropped or compressed on the device.
  ///
  /// In en, this message translates to:
  /// **'Preparing image…'**
  String get imagePreparing;

  /// Upload progress.
  ///
  /// In en, this message translates to:
  /// **'Uploading… {percent}%'**
  String imageUploading(int percent);

  /// Button that stops a running upload.
  ///
  /// In en, this message translates to:
  /// **'Cancel upload'**
  String get imageCancelUpload;

  /// Shown after the upload while the server checks the image and makes web versions.
  ///
  /// In en, this message translates to:
  /// **'Processing image…'**
  String get imageProcessing;

  /// Shown when server processing takes more than a minute.
  ///
  /// In en, this message translates to:
  /// **'This is taking longer than usual. The image will appear when it\'s ready.'**
  String get imageProcessingSlow;

  /// Accessibility label of an empty image placeholder.
  ///
  /// In en, this message translates to:
  /// **'No image'**
  String get imageNone;

  /// Accessibility label of the placeholder shown for a rejected image.
  ///
  /// In en, this message translates to:
  /// **'Image not accepted'**
  String get imageRejected;

  /// Title of the crop dialog.
  ///
  /// In en, this message translates to:
  /// **'Crop image'**
  String get imageCropTitle;

  /// Instructions in the crop dialog.
  ///
  /// In en, this message translates to:
  /// **'Drag to move. Pinch, scroll or use the slider to zoom.'**
  String get imageCropHint;

  /// Label of the zoom slider in the crop dialog.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get imageCropZoom;

  /// Confirms the crop and starts the upload.
  ///
  /// In en, this message translates to:
  /// **'Use image'**
  String get imageCropDone;

  /// Accessibility label of the crop area.
  ///
  /// In en, this message translates to:
  /// **'Crop area. Drag to move the image.'**
  String get imageCropArea;

  /// Image rejected: not JPEG, PNG or WebP by content (FR-102, AC-005).
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported. Choose a JPEG, PNG or WebP image.'**
  String get imageErrorUnsupportedType;

  /// Image rejected: over 5 MB or too many pixels (FR-102, AC-005).
  ///
  /// In en, this message translates to:
  /// **'This file is larger than 5 MB. Choose a smaller image.'**
  String get imageErrorTooLarge;

  /// Image rejected: below the minimum dimensions for its purpose (FR-102).
  ///
  /// In en, this message translates to:
  /// **'This image is too small. Use one at least {width} × {height} px.'**
  String imageErrorTooSmall(int width, int height);

  /// Image rejected: it has an image signature but cannot be decoded.
  ///
  /// In en, this message translates to:
  /// **'This image couldn\'t be read. It may be damaged. Try another file.'**
  String get imageErrorInvalid;

  /// Image rejected: unexpected server failure.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t process this image. Please try again.'**
  String get imageErrorProcessingFailed;

  /// The image upload failed on the device.
  ///
  /// In en, this message translates to:
  /// **'The upload didn\'t finish. Check your connection and try again.'**
  String get imageErrorUploadFailed;

  /// The photo library or file dialog could not be opened.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open your photos. Check that the app is allowed to access them.'**
  String get imageErrorPickFailed;

  /// Contact number is not valid for the restaurant's country (FR-011).
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number for your restaurant\'s country.'**
  String get validationPhone;

  /// Website entered with http:// (FR-011 needs https).
  ///
  /// In en, this message translates to:
  /// **'Use a secure address that starts with https://.'**
  String get validationHttps;

  /// Website or link is not a valid address.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid web address, like https://example.com.'**
  String get validationUrl;

  /// Social link not recognised for the network.
  ///
  /// In en, this message translates to:
  /// **'Enter a link to your {network} page.'**
  String validationSocialLink(String network);

  /// Postal code is not valid for the country.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid {label}.'**
  String validationPostalCode(String label);

  /// Address field label.
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get addressPostalCode;

  /// Postal code label in India.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get addressPinCode;

  /// Postal code label in the United States.
  ///
  /// In en, this message translates to:
  /// **'ZIP code'**
  String get addressZipCode;

  /// Day name.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMon;

  /// Day name.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTue;

  /// Day name.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWed;

  /// Day name.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThu;

  /// Day name.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFri;

  /// Day name.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySat;

  /// Day name.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySun;

  /// Opening hours: a slot opens and closes at the same time.
  ///
  /// In en, this message translates to:
  /// **'Opening and closing times must be different.'**
  String get hoursErrorSameTime;

  /// Opening hours: slots overlap or are out of order.
  ///
  /// In en, this message translates to:
  /// **'Time slots overlap. List them in order through the day.'**
  String get hoursErrorOverlap;

  /// Opening hours: an overnight slot is not the last one.
  ///
  /// In en, this message translates to:
  /// **'Only the last time slot of a day can run past midnight.'**
  String get hoursErrorOvernightNotLast;

  /// Opening hours: too many slots.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} time slots a day.'**
  String hoursErrorTooMany(int max);

  /// Social network name.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get socialInstagram;

  /// Social network name.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get socialFacebook;

  /// Social network name (formerly Twitter).
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get socialX;

  /// Social network name.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get socialYoutube;

  /// Map service name.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get socialGoogleMaps;

  /// Currency name.
  ///
  /// In en, this message translates to:
  /// **'Indian rupee'**
  String get currencyINR;

  /// Currency name.
  ///
  /// In en, this message translates to:
  /// **'UAE dirham'**
  String get currencyAED;

  /// Currency name.
  ///
  /// In en, this message translates to:
  /// **'Kuwaiti dinar'**
  String get currencyKWD;

  /// Currency name.
  ///
  /// In en, this message translates to:
  /// **'Saudi riyal'**
  String get currencySAR;

  /// Currency name.
  ///
  /// In en, this message translates to:
  /// **'Qatari riyal'**
  String get currencyQAR;

  /// Currency name.
  ///
  /// In en, this message translates to:
  /// **'Bahraini dinar'**
  String get currencyBHD;

  /// Currency name.
  ///
  /// In en, this message translates to:
  /// **'Omani rial'**
  String get currencyOMR;

  /// Currency name.
  ///
  /// In en, this message translates to:
  /// **'US dollar'**
  String get currencyUSD;

  /// Error: the item's category is deleted (M04).
  ///
  /// In en, this message translates to:
  /// **'That category has been deleted. Choose another category.'**
  String get errorCategoryDeleted;

  /// Price field: empty.
  ///
  /// In en, this message translates to:
  /// **'Enter a price.'**
  String get priceRequired;

  /// Price field: not a valid amount.
  ///
  /// In en, this message translates to:
  /// **'Enter a price like {example}.'**
  String priceInvalid(String example);

  /// Price field: above the maximum.
  ///
  /// In en, this message translates to:
  /// **'That price is too high.'**
  String get priceTooHigh;

  /// Price field helper: how many decimals the currency uses (FR-029).
  ///
  /// In en, this message translates to:
  /// **'{code} prices have {decimals, plural, =0{no decimal places} =1{1 decimal place} other{{decimals} decimal places}}.'**
  String priceDecimalsHelp(String code, int decimals);
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
