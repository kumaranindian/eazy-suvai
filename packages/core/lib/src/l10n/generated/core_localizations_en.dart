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
  String get errorSlugInvalid =>
      'Use 3 to 60 lowercase letters, numbers and single hyphens, not starting or ending with a hyphen.';

  @override
  String get errorSlugReserved => 'This link is reserved. Choose another one.';

  @override
  String get errorSlugTaken =>
      'Another restaurant already uses this link. Try adding your area or city.';

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

  @override
  String get imageAdd => 'Add image';

  @override
  String get imageReplace => 'Replace';

  @override
  String get imageRemove => 'Remove';

  @override
  String get imageRemoveTitle => 'Remove this image?';

  @override
  String get imageRemoveMessage => 'You can add a new image at any time.';

  @override
  String imageHint(int width, int height) {
    return 'JPEG, PNG or WebP, up to 5 MB, at least $width × $height px.';
  }

  @override
  String get imagePreparing => 'Preparing image…';

  @override
  String imageUploading(int percent) {
    return 'Uploading… $percent%';
  }

  @override
  String get imageCancelUpload => 'Cancel upload';

  @override
  String get imageProcessing => 'Processing image…';

  @override
  String get imageProcessingSlow =>
      'This is taking longer than usual. The image will appear when it\'s ready.';

  @override
  String get imageNone => 'No image';

  @override
  String get imageRejected => 'Image not accepted';

  @override
  String get imageCropTitle => 'Crop image';

  @override
  String get imageCropHint =>
      'Drag to move. Pinch, scroll or use the slider to zoom.';

  @override
  String get imageCropZoom => 'Zoom';

  @override
  String get imageCropDone => 'Use image';

  @override
  String get imageCropArea => 'Crop area. Drag to move the image.';

  @override
  String get imageErrorUnsupportedType =>
      'This file type isn\'t supported. Choose a JPEG, PNG or WebP image.';

  @override
  String get imageErrorTooLarge =>
      'This file is larger than 5 MB. Choose a smaller image.';

  @override
  String imageErrorTooSmall(int width, int height) {
    return 'This image is too small. Use one at least $width × $height px.';
  }

  @override
  String get imageErrorInvalid =>
      'This image couldn\'t be read. It may be damaged. Try another file.';

  @override
  String get imageErrorProcessingFailed =>
      'We couldn\'t process this image. Please try again.';

  @override
  String get imageErrorUploadFailed =>
      'The upload didn\'t finish. Check your connection and try again.';

  @override
  String get imageErrorPickFailed =>
      'We couldn\'t open your photos. Check that the app is allowed to access them.';

  @override
  String get validationPhone =>
      'Enter a valid phone number for your restaurant\'s country.';

  @override
  String get validationHttps =>
      'Use a secure address that starts with https://.';

  @override
  String get validationUrl =>
      'Enter a valid web address, like https://example.com.';

  @override
  String validationSocialLink(String network) {
    return 'Enter a link to your $network page.';
  }

  @override
  String validationPostalCode(String label) {
    return 'Enter a valid $label.';
  }

  @override
  String get addressPostalCode => 'Postal code';

  @override
  String get addressPinCode => 'PIN code';

  @override
  String get addressZipCode => 'ZIP code';

  @override
  String get weekdayMon => 'Monday';

  @override
  String get weekdayTue => 'Tuesday';

  @override
  String get weekdayWed => 'Wednesday';

  @override
  String get weekdayThu => 'Thursday';

  @override
  String get weekdayFri => 'Friday';

  @override
  String get weekdaySat => 'Saturday';

  @override
  String get weekdaySun => 'Sunday';

  @override
  String get hoursErrorSameTime =>
      'Opening and closing times must be different.';

  @override
  String get hoursErrorOverlap =>
      'Time slots overlap. List them in order through the day.';

  @override
  String get hoursErrorOvernightNotLast =>
      'Only the last time slot of a day can run past midnight.';

  @override
  String hoursErrorTooMany(int max) {
    return 'Use at most $max time slots a day.';
  }

  @override
  String get socialInstagram => 'Instagram';

  @override
  String get socialFacebook => 'Facebook';

  @override
  String get socialX => 'X';

  @override
  String get socialYoutube => 'YouTube';

  @override
  String get socialGoogleMaps => 'Google Maps';

  @override
  String get currencyINR => 'Indian rupee';

  @override
  String get currencyAED => 'UAE dirham';

  @override
  String get currencyKWD => 'Kuwaiti dinar';

  @override
  String get currencySAR => 'Saudi riyal';

  @override
  String get currencyQAR => 'Qatari riyal';

  @override
  String get currencyBHD => 'Bahraini dinar';

  @override
  String get currencyOMR => 'Omani rial';

  @override
  String get currencyUSD => 'US dollar';

  @override
  String get errorCategoryDeleted =>
      'That category has been deleted. Choose another category.';

  @override
  String get priceRequired => 'Enter a price.';

  @override
  String priceInvalid(String example) {
    return 'Enter a price like $example.';
  }

  @override
  String get priceTooHigh => 'That price is too high.';

  @override
  String priceDecimalsHelp(String code, int decimals) {
    String _temp0 = intl.Intl.pluralLogic(
      decimals,
      locale: localeName,
      other: '$decimals decimal places',
      one: '1 decimal place',
      zero: 'no decimal places',
    );
    return '$code prices have $_temp0.';
  }
}
