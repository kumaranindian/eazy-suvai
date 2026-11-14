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
  String get actionBack => 'Back';

  @override
  String get actionNext => 'Next';

  @override
  String get actionDone => 'Done';

  @override
  String get actionSaveNow => 'Save now';

  @override
  String get saveAuto => 'Changes save automatically';

  @override
  String get saveSaving => 'Saving…';

  @override
  String get saveSaved => 'Saved';

  @override
  String get saveFailed => 'Couldn\'t save your changes';

  @override
  String get saveInvalid => 'Fix the highlighted fields to save';

  @override
  String get profileTitle => 'Restaurant profile';

  @override
  String get profileSectionBasics => 'Basics';

  @override
  String get profileSectionImages => 'Logo and cover';

  @override
  String get profileSectionContact => 'Contact';

  @override
  String get profileSectionAddress => 'Address';

  @override
  String get profileSectionHours => 'Opening hours';

  @override
  String get profileSectionSocial => 'Social links';

  @override
  String get profileSectionSocialHelp =>
      'Paste a link, or type @yourname for Instagram, X and YouTube.';

  @override
  String get profileSectionVisibility => 'Show on your menu';

  @override
  String get profileSectionVisibilityHelp =>
      'Turn off anything you don\'t want customers to see. Your details stay saved.';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldDescriptionHelper =>
      'What makes your place special? Up to 500 characters.';

  @override
  String get fieldLogo => 'Logo';

  @override
  String get fieldCover => 'Cover image';

  @override
  String get fieldPhone => 'Contact number';

  @override
  String get fieldPhoneHelper => 'Mobile or landline, for customers to call.';

  @override
  String get fieldPublicEmail => 'Public email';

  @override
  String get fieldWebsite => 'Website';

  @override
  String get fieldAddress => 'Street address';

  @override
  String get fieldAddressHelper => 'Building, street and area.';

  @override
  String get fieldCityPlain => 'City';

  @override
  String get fieldSocialHint => 'Link or @handle';

  @override
  String get fieldMapsHint => 'Link from Google Maps → Share';

  @override
  String get fieldCurrency => 'Currency';

  @override
  String get visibilityPhone => 'Contact number';

  @override
  String get visibilityEmail => 'Email';

  @override
  String get visibilityAddress => 'Address';

  @override
  String get visibilityHours => 'Opening hours';

  @override
  String get visibilitySocial => 'Social links';

  @override
  String get previewTitle => 'Menu preview';

  @override
  String get previewNoName => 'Your restaurant';

  @override
  String previewHoursToday(String hours) {
    return 'Today: $hours';
  }

  @override
  String get previewClosedToday => 'Closed today';

  @override
  String previewHidden(String fields) {
    return 'Hidden from customers: $fields';
  }

  @override
  String get hoursTitle => 'Opening hours';

  @override
  String hoursIntro(String zone) {
    return 'Times are in your restaurant\'s time zone ($zone). Add up to 3 time slots a day, or mark a day as closed.';
  }

  @override
  String get hoursNotSet => 'No opening hours yet';

  @override
  String get hoursSet => 'Added';

  @override
  String get hoursEmptyMessage =>
      'Tell customers when you\'re open. We\'ll start with every day 9:00 to 22:00; adjust it to fit.';

  @override
  String get hoursAdd => 'Add opening hours';

  @override
  String get hoursEdit => 'Edit opening hours';

  @override
  String get hoursOpen => 'Open';

  @override
  String get hoursClosed => 'Closed';

  @override
  String get hoursAllDay => 'Open 24 hours';

  @override
  String hoursOpenOn(String day) {
    return 'Open on $day';
  }

  @override
  String get hoursOpens => 'Opens';

  @override
  String get hoursCloses => 'Closes';

  @override
  String get hoursAddSlot => 'Add time slot';

  @override
  String get hoursRemoveSlot => 'Remove time slot';

  @override
  String hoursCopyToAll(String day) {
    return 'Copy $day\'s hours to every day';
  }

  @override
  String hoursSheetTitle(String day) {
    return '$day hours';
  }

  @override
  String get hoursOvernightHint =>
      'A closing time earlier than the opening time runs past midnight.';

  @override
  String get hoursTimeFormat => 'Use 24-hour time, like 09:30';

  @override
  String get hoursRemoveAll => 'Remove opening hours';

  @override
  String get hoursRemoveAllTitle => 'Remove opening hours?';

  @override
  String get hoursRemoveAllMessage =>
      'Your menu will no longer show when you\'re open. You can add hours again at any time.';

  @override
  String get regionalTitle => 'Currency and time zone';

  @override
  String get regionalSectionCountry => 'Country';

  @override
  String get regionalCountryLocked =>
      'Set when you signed up. Contact support to change it.';

  @override
  String get regionalSectionCurrency => 'Currency';

  @override
  String get regionalCurrencyHelp =>
      'Your menu shows every price in this currency.';

  @override
  String get regionalSectionTimezone => 'Time zone';

  @override
  String get regionalTimezoneHelp =>
      'Used for your opening hours and for analytics days.';

  @override
  String get regionalTimezonePick => 'Choose a time zone';

  @override
  String get regionalTimezoneSearch => 'Search, for example Kolkata';

  @override
  String get regionalTimezoneSuggested => 'Suggested for your country';

  @override
  String get regionalTimezoneAll => 'All time zones';

  @override
  String get regionalPricesNeedReview =>
      'You changed the currency after publishing. Prices were not converted: review every price before you publish again.';

  @override
  String currencyOption(String name, String code) {
    return '$name ($code)';
  }

  @override
  String currencyWarningTitle(String code) {
    return 'Switch to $code?';
  }

  @override
  String currencyWarningPublished(String from, String to) {
    return 'Prices are not converted. A price of 100 $from becomes 100 $to. Your live menu keeps $from until you publish, and you\'ll need to review every price before the next publish.';
  }

  @override
  String currencyWarningDraft(String from, String to) {
    return 'Prices are not converted. A price of 100 $from becomes 100 $to. Check your item prices after the change.';
  }

  @override
  String get currencyWarningConfirm => 'Change currency';

  @override
  String get menuLinkTitle => 'Menu link';

  @override
  String get menuLinkCurrent => 'Your menu link';

  @override
  String get menuLinkQrNote =>
      'Your QR code always works, even if you change this link.';

  @override
  String get menuLinkCopy => 'Copy link';

  @override
  String get menuLinkCopied => 'Link copied';

  @override
  String get menuLinkChange => 'Change the link';

  @override
  String get menuLinkRules =>
      '3 to 60 lowercase letters, numbers and hyphens. Your old link will keep working and send customers to the new one.';

  @override
  String get menuLinkNew => 'New link';

  @override
  String get menuLinkChecking => 'Checking…';

  @override
  String get menuLinkAvailable => 'This link is available.';

  @override
  String get menuLinkSave => 'Change link';

  @override
  String get menuLinkConfirmTitle => 'Change your menu link?';

  @override
  String menuLinkConfirmMessage(String newUrl, String oldUrl) {
    return 'Your menu will move to $newUrl. The old link $oldUrl keeps working and redirects there, and your QR code does not change.';
  }

  @override
  String get menuLinkConfirmAction => 'Change link';

  @override
  String get menuLinkChanged => 'Your menu link was changed.';

  @override
  String get checklistTitle => 'Get your menu ready';

  @override
  String get checklistDoneTitle => 'Your menu is set up';

  @override
  String checklistProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get checklistStepDone => 'Done';

  @override
  String get checklistStepTodo => 'To do';

  @override
  String get checklistProfile => 'Complete your profile';

  @override
  String get checklistProfileHint =>
      'Add a description, a phone number or email, and your address.';

  @override
  String get checklistLogo => 'Add your logo';

  @override
  String get checklistLogoHint => 'A square logo, at least 256 × 256 px.';

  @override
  String get checklistCategories => 'Add menu categories';

  @override
  String get checklistCategoriesHint =>
      'For example Starters, Mains, Desserts.';

  @override
  String get checklistItems => 'Add dishes';

  @override
  String get checklistItemsHint => 'Add names, prices and photos.';

  @override
  String get checklistTheme => 'Choose a theme';

  @override
  String get checklistThemeHint =>
      'Pick colours and fonts that match your brand.';

  @override
  String get checklistPublish => 'Publish your menu';

  @override
  String get checklistPublishHint =>
      'Customers see your menu once it\'s published.';

  @override
  String get statusTitle => 'Menu status';

  @override
  String get statusDraft => 'Draft';

  @override
  String statusLive(int version) {
    return 'Live · version $version';
  }

  @override
  String get statusDraftHelp =>
      'Customers can\'t see your menu yet. Changes are saved as a draft until you publish.';

  @override
  String get statusLiveHelp =>
      'Customers see your last published version. New changes wait in the draft until you publish.';

  @override
  String statusCounts(int categories, int items) {
    return 'Categories: $categories · Dishes: $items';
  }

  @override
  String statusLastEdit(String time) {
    return 'Last change: $time';
  }

  @override
  String get statusOpenMenu => 'Open menu';

  @override
  String get qrTitle => 'QR code and link';

  @override
  String get qrHelp =>
      'Customers scan your QR code or open this link to see your menu.';

  @override
  String qrCode(String code) {
    return 'QR code: $code';
  }

  @override
  String get qrOpenShare => 'QR & share';

  @override
  String get qrChangeLink => 'Change link';

  @override
  String get wizardTitle => 'Set up your restaurant';

  @override
  String get wizardSkip => 'Skip for now';

  @override
  String get wizardSkipStep => 'Skip';

  @override
  String wizardStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get wizardStepProfile => 'Your restaurant';

  @override
  String get wizardStepImages => 'Logo and cover';

  @override
  String get wizardStepMenu => 'Build your menu';

  @override
  String get wizardProfileIntro =>
      'Tell customers about your place. You can change everything later in Settings.';

  @override
  String get wizardImagesIntro =>
      'A logo and a wide cover photo make your menu look like yours. Both are optional.';

  @override
  String get wizardMenuIntro => 'Next, build your menu. Here\'s how it works:';

  @override
  String get wizardMenuCategories =>
      'Create categories such as Starters, Mains and Drinks.';

  @override
  String get wizardMenuItems =>
      'Add dishes with prices, photos and dietary labels.';

  @override
  String get wizardMenuTheme => 'Choose a theme to match your brand.';

  @override
  String get wizardMenuPublish =>
      'Preview, then publish. Your QR code starts working at once.';

  @override
  String get wizardToMenu => 'Start my menu';

  @override
  String get wizardToDashboard => 'Go to dashboard';
}
