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

  @override
  String get actionAdd => 'Add';

  @override
  String get actionClose => 'Close';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionDiscard => 'Discard';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionMoveDown => 'Move down';

  @override
  String get actionMoveUp => 'Move up';

  @override
  String get actionNotNow => 'Not now';

  @override
  String get actionRestore => 'Restore';

  @override
  String get actionSave => 'Save';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionUpgrade => 'Upgrade';

  @override
  String get menuCategoriesTitle => 'Categories';

  @override
  String get menuItemsTitle => 'Items';

  @override
  String get menuAddCategory => 'Add category';

  @override
  String get menuAddItem => 'Add item';

  @override
  String get menuAllItems => 'All items';

  @override
  String menuItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get menuCategoryHidden => 'Hidden';

  @override
  String menuCategoryActiveLabel(String name) {
    return 'Show $name on the menu';
  }

  @override
  String menuMoreFor(String name) {
    return 'More options for $name';
  }

  @override
  String get menuDragToReorder => 'Drag to reorder';

  @override
  String get menuRecentlyDeleted => 'Recently deleted';

  @override
  String get menuNoCategoriesTitle => 'No categories yet';

  @override
  String get menuNoCategoriesMessage =>
      'Start with sections such as Starters, Main course or Beverages.';

  @override
  String get menuCategoryNew => 'New category';

  @override
  String get menuCategoryEdit => 'Edit category';

  @override
  String get menuFieldCategoryName => 'Category name';

  @override
  String get menuFieldCategoryNameHint => 'For example, Starters';

  @override
  String get menuFieldDescriptionOptional => 'Description (optional)';

  @override
  String get menuFieldCategoryActive => 'Show on the menu';

  @override
  String get menuFieldCategoryActiveHelp =>
      'When off, this category and its items are hidden from customers.';

  @override
  String get menuFieldPhoto => 'Photo';

  @override
  String get menuPhotoAfterSave => 'You can add a photo after saving.';

  @override
  String get menuErrorNameRequired => 'Enter a name.';

  @override
  String get menuErrorCategoryRequired => 'Choose a category.';

  @override
  String get menuErrorDietaryRequired => 'Choose a dietary classification.';

  @override
  String menuCategoryAdded(String name) {
    return '$name added.';
  }

  @override
  String menuDeleteCategoryTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get menuDeleteCategoryEmpty =>
      'This category has no items. You can restore it from Recently deleted for 30 days.';

  @override
  String menuDeleteCategoryHasItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This category has $count items. What should happen to them?',
      one: 'This category has 1 item. What should happen to it?',
    );
    return '$_temp0';
  }

  @override
  String menuDeleteModeMove(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move the $count items to another category',
      one: 'Move the item to another category',
    );
    return '$_temp0';
  }

  @override
  String get menuDeleteModeMoveNone => 'Add another category first.';

  @override
  String get menuDeleteMoveTo => 'Move items to';

  @override
  String menuDeleteModeAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete the category and all $count items',
      one: 'Delete the category and its item',
    );
    return '$_temp0';
  }

  @override
  String menuDeleteTypeName(String name) {
    return 'To confirm, type the category name: $name';
  }

  @override
  String get menuDeleteRestoreNote =>
      'Deleted content stays in Recently deleted for 30 days.';

  @override
  String get menuDeleteMoveConfirm => 'Move items and delete';

  @override
  String menuDeleteAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete category and $count items',
      one: 'Delete category and 1 item',
    );
    return '$_temp0';
  }

  @override
  String menuDeletedToBin(String name) {
    return '$name moved to Recently deleted.';
  }

  @override
  String menuCategoryDeletedMoved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items were moved.',
      one: '1 item was moved.',
    );
    return '$name deleted. $_temp0';
  }

  @override
  String get menuSearchHint => 'Search items';

  @override
  String get menuSearchClear => 'Clear search';

  @override
  String menuFilterSoldOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sold out ($count)',
      zero: 'Sold out',
    );
    return '$_temp0';
  }

  @override
  String get menuFilterFeatured => 'Featured';

  @override
  String get menuNoItemsTitle => 'No items yet';

  @override
  String get menuNoItemsMessage =>
      'Add the dishes and drinks in this category.';

  @override
  String get menuNoItemsAll => 'Choose a category and add your first item.';

  @override
  String get menuNoMatchTitle => 'No matching items';

  @override
  String get menuNoMatchMessage => 'Try another search or clear the filters.';

  @override
  String get menuSoldOut => 'Sold out';

  @override
  String menuAvailableLabel(String name) {
    return '$name available';
  }

  @override
  String menuSelectItem(String name) {
    return 'Select $name';
  }

  @override
  String get menuSelectAll => 'Select all';

  @override
  String menuSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get menuBulkAvailable => 'Mark available';

  @override
  String get menuBulkSoldOut => 'Mark sold out';

  @override
  String get menuMoveToCategory => 'Move to category';

  @override
  String menuMoveItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Move $count items to',
      one: 'Move item to',
    );
    return '$_temp0';
  }

  @override
  String menuItemsMoved(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items moved to $name.',
      one: 'Item moved to $name.',
    );
    return '$_temp0';
  }

  @override
  String menuDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count items?',
      one: 'Delete this item?',
    );
    return '$_temp0';
  }

  @override
  String get menuDeleteItemsMessage =>
      'You can restore deleted items from Recently deleted for 30 days.';

  @override
  String get menuDeleteItem => 'Delete item';

  @override
  String get menuItemNew => 'New item';

  @override
  String get menuItemEdit => 'Edit item';

  @override
  String get menuFieldItemName => 'Item name';

  @override
  String get menuFieldCategory => 'Category';

  @override
  String get menuFieldPrice => 'Price';

  @override
  String get menuFieldDietary => 'Dietary classification';

  @override
  String get menuFieldTags => 'Tags';

  @override
  String get menuFieldAvailable => 'Available';

  @override
  String get menuFieldAvailableHelp =>
      'Turn off when sold out. Customers see it at once, without publishing.';

  @override
  String get menuFieldFeatured => 'Featured';

  @override
  String get menuFieldFeaturedHelp => 'Highlight this item on your menu.';

  @override
  String get menuLabelsUnavailable =>
      'Dietary labels are not available right now. Try again later.';

  @override
  String menuItemAdded(String name) {
    return '$name added. You can add a photo now.';
  }

  @override
  String get menuItemSaved => 'Changes saved to the draft.';

  @override
  String get menuUnsaved => 'Unsaved changes';

  @override
  String get menuDiscardTitle => 'Discard changes?';

  @override
  String get menuDiscardMessage => 'Your changes to this item will be lost.';

  @override
  String get menuItemGoneTitle => 'Item not found';

  @override
  String get menuItemGoneMessage =>
      'It may have been deleted on another device.';

  @override
  String get menuCategoryGoneTitle => 'Category not found';

  @override
  String get menuCategoryGoneMessage =>
      'It may have been deleted on another device.';

  @override
  String get menuItemNeedsCategory => 'Add a category before adding items.';

  @override
  String get menuEditorEmptyTitle => 'No item selected';

  @override
  String get menuEditorEmptyMessage =>
      'Choose an item to edit it here, or add a new one.';

  @override
  String get menuLimitTitle => 'Plan limit reached';

  @override
  String menuLimitItems(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Your plan allows $max items.',
      one: 'Your plan allows 1 item.',
    );
    return '$_temp0 Upgrade to add more, or delete items you no longer need.';
  }

  @override
  String menuLimitCategories(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Your plan allows $max categories.',
      one: 'Your plan allows 1 category.',
    );
    return '$_temp0 Upgrade to add more, or delete categories you no longer need.';
  }

  @override
  String get menuLimitGeneric =>
      'You\'ve reached a limit of your plan. Upgrade to add more.';

  @override
  String get menuDeletedIntro =>
      'Deleted categories and items can be restored for 30 days. Restored content goes back to your draft; publish to show it to customers.';

  @override
  String get menuDeletedEmptyTitle => 'Nothing deleted';

  @override
  String get menuDeletedEmptyMessage =>
      'Categories and items you delete appear here for 30 days.';

  @override
  String menuDeletedDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'Less than a day left',
    );
    return '$_temp0';
  }

  @override
  String menuDeletedWithItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'With $count items',
      one: 'With 1 item',
    );
    return '$_temp0';
  }

  @override
  String menuDeletedCategoryGone(String name) {
    return '$name (deleted)';
  }

  @override
  String menuRestoreLabel(String name) {
    return 'Restore $name';
  }

  @override
  String menuRestoreInto(String name) {
    return 'Restore $name into';
  }

  @override
  String get menuRestoreNeedsCategory => 'Add or restore a category first.';

  @override
  String menuRestored(String name) {
    return '$name restored to your draft.';
  }

  @override
  String get planTitle => 'Plans';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeEditorTitle => 'Customize theme';

  @override
  String get themeCurrent => 'Your theme';

  @override
  String get themeNotChosen => 'No theme chosen yet';

  @override
  String themeCustomizedName(String name) {
    return '$name (customized)';
  }

  @override
  String get themeChooseHint =>
      'Pick a theme below. You can change its colours, font and layout afterwards.';

  @override
  String get themeCustomizeHint =>
      'Change colours, font, layouts and light or dark mode. Changes save automatically.';

  @override
  String get themeCustomize => 'Customize';

  @override
  String get themePreview => 'Preview';

  @override
  String get themePreviewTitle => 'Menu preview';

  @override
  String get themePreviewClose => 'Close preview';

  @override
  String get themePreviewNote =>
      'An approximation of your public menu. Check the exact page in Preview before you publish.';

  @override
  String get themePreviewSample =>
      'Sample dishes are shown until you add items.';

  @override
  String get themePreviewSoldOut => 'Sold out';

  @override
  String get themePreviewFeatured => 'Featured';

  @override
  String get themePremium => 'Premium';

  @override
  String get themeSelected => 'Selected';

  @override
  String get themeFontSample => 'Aa';

  @override
  String get themeEmpty =>
      'No themes are available yet. Please try again later.';

  @override
  String get themeReplaceTitle => 'Switch theme?';

  @override
  String themeReplaceBody(String name) {
    return 'Your custom colours, font and layouts will be replaced by the $name theme.';
  }

  @override
  String get themeReplaceConfirm => 'Switch theme';

  @override
  String get themeChooseFirst => 'Choose a theme first, then customize it.';

  @override
  String get themeChooseAction => 'Choose a theme';

  @override
  String themeEditorBasedOn(String name) {
    return 'Based on the $name theme.';
  }

  @override
  String get themeSectionColours => 'Colours';

  @override
  String get themeSectionFont => 'Font';

  @override
  String get themeSectionLayout => 'Layout';

  @override
  String get themeSectionMode => 'Appearance';

  @override
  String get themePrimary => 'Primary colour';

  @override
  String get themePrimaryHelp =>
      'Buttons, the selected category, headings and prices.';

  @override
  String get themeSecondary => 'Secondary colour';

  @override
  String get themeSecondaryHelp => 'Image placeholders and accents.';

  @override
  String get themeBackground => 'Background colour';

  @override
  String get themeBackgroundHelp => 'Behind the whole menu.';

  @override
  String themeHexLabel(String field) {
    return '$field (hex)';
  }

  @override
  String get themeHexInvalid => 'Enter a colour like #A8550A.';

  @override
  String get themeResetColour => 'Use theme colour';

  @override
  String get themeResetAll => 'Reset to theme defaults';

  @override
  String themeSwatch(String hex) {
    return 'Colour $hex';
  }

  @override
  String get themeFont => 'Menu font';

  @override
  String get themeLayout => 'Menu layout';

  @override
  String get themeLayoutList => 'List';

  @override
  String get themeLayoutGrid => 'Grid';

  @override
  String get themeCardLayout => 'Item cards';

  @override
  String get themeCardCompact => 'Compact, no image';

  @override
  String get themeCardImageTop => 'Image on top';

  @override
  String get themeCardImageLeft => 'Image at the side';

  @override
  String get themeDarkMode => 'Dark mode';

  @override
  String get themeDarkModeHelp => 'Light text on a dark background.';

  @override
  String get themeDevicePhone => 'Phone';

  @override
  String get themeDeviceDesktop => 'Desktop';

  @override
  String get themeContrastOk => 'All text is easy to read (WCAG AA contrast).';

  @override
  String get themeContrastTitle => 'Some text would be hard to read';

  @override
  String themeContrastText(String ratio, String colour) {
    return 'Text on your background has a contrast of $ratio:1; at least 4.5:1 is needed. Your menu will use $colour text instead.';
  }

  @override
  String themeContrastSurfaceText(String ratio, String colour) {
    return 'Text on item cards has a contrast of $ratio:1; at least 4.5:1 is needed. Cards will use $colour text instead.';
  }

  @override
  String themeContrastAccent(String ratio) {
    return 'Your primary colour has a contrast of $ratio:1 as text; at least 4.5:1 is needed. Headings and prices will use an adjusted shade.';
  }

  @override
  String get themeColourWhite => 'white';

  @override
  String get themeColourBlack => 'black';

  @override
  String get sampleStarters => 'Starters';

  @override
  String get sampleMains => 'Mains';

  @override
  String get sampleItemPaneer => 'Paneer tikka';

  @override
  String get sampleItemPaneerDesc =>
      'Cottage cheese marinated in yogurt and spices, grilled in a tandoor.';

  @override
  String get sampleItemChicken => 'Chicken 65';

  @override
  String get sampleItemChickenDesc =>
      'Crispy fried chicken with curry leaves and chillies.';

  @override
  String get sampleItemDosa => 'Masala dosa';

  @override
  String get sampleItemDosaDesc =>
      'Rice and lentil crepe with spiced potato, sambar and chutney.';

  @override
  String get sampleItemBiryani => 'Vegetable biryani';

  @override
  String get sampleItemBiryaniDesc =>
      'Basmati rice slow-cooked with vegetables and whole spices.';

  @override
  String get publishBarDraft => 'Not published yet';

  @override
  String get publishBarChanges => 'Unpublished changes';

  @override
  String get actionPreview => 'Preview';

  @override
  String get actionPublish => 'Publish';

  @override
  String get publishTitle => 'Publish your menu';

  @override
  String get publishChecking => 'Checking your menu…';

  @override
  String get publishProblemsTitle => 'Fix these before publishing';

  @override
  String get publishChangesTitle => 'What changes for customers';

  @override
  String publishFirstSummary(int categories, int items) {
    String _temp0 = intl.Intl.pluralLogic(
      categories,
      locale: localeName,
      other: '$categories categories',
      one: '1 category',
    );
    String _temp1 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items items',
      one: '1 item',
    );
    return '$_temp0 and $_temp1 go live at your menu link and QR code.';
  }

  @override
  String publishNoChanges(int version) {
    return 'Nothing has changed since version $version. You can still publish it again.';
  }

  @override
  String publishAddedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added',
      one: '1 item added',
    );
    return '$_temp0';
  }

  @override
  String publishChangedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items changed',
      one: '1 item changed',
    );
    return '$_temp0';
  }

  @override
  String publishRemovedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items removed',
      one: '1 item removed',
    );
    return '$_temp0';
  }

  @override
  String publishAddedCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories added',
      one: '1 category added',
    );
    return '$_temp0';
  }

  @override
  String publishChangedCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories changed',
      one: '1 category changed',
    );
    return '$_temp0';
  }

  @override
  String publishRemovedCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories removed',
      one: '1 category removed',
    );
    return '$_temp0';
  }

  @override
  String publishMoreNames(int count) {
    return 'and $count more';
  }

  @override
  String get publishProfileChanged => 'Restaurant details changed';

  @override
  String get publishThemeChanged => 'Theme changed';

  @override
  String publishPricesCheckbox(String currency) {
    return 'I have checked that every price is in $currency.';
  }

  @override
  String publishDone(int version) {
    return 'Version $version is live.';
  }

  @override
  String publishNextVersion(int version) {
    return 'This becomes version $version.';
  }

  @override
  String get actionFix => 'Fix';

  @override
  String get problemEmailNotVerified =>
      'Verify your email address before publishing.';

  @override
  String get problemMenuEmpty =>
      'Your menu is empty. Add at least one active category with an item in it.';

  @override
  String get problemRestaurantName => 'Your restaurant needs a name.';

  @override
  String get problemCurrency => 'Choose your menu\'s currency.';

  @override
  String get problemTimezone => 'Choose your time zone.';

  @override
  String problemHours(String day) {
    return 'Check the opening hours for $day: the times overlap or are out of order.';
  }

  @override
  String get problemCategoryName => 'A category has no name.';

  @override
  String get problemItemName => 'An item has no name.';

  @override
  String problemItemPrice(String name) {
    return '$name: enter a price.';
  }

  @override
  String problemItemLabel(String name) {
    return '$name: choose a dietary label.';
  }

  @override
  String problemItemLabelGone(String name) {
    return '$name: its dietary label is no longer available. Choose another.';
  }

  @override
  String problemLimitItems(int count, int max) {
    return 'You have $count items and your plan allows $max. Delete some or upgrade your plan.';
  }

  @override
  String problemLimitCategories(int count, int max) {
    return 'You have $count categories and your plan allows $max. Delete some or upgrade your plan.';
  }

  @override
  String get problemPrices =>
      'Your currency changed since the last publish. Check your prices, then tick the box below.';

  @override
  String get problemTooLarge =>
      'Your menu is too large to publish. Shorten some descriptions or remove items.';

  @override
  String get problemUnknown => 'Something needs fixing before you can publish.';

  @override
  String get problemUnnamedItem => 'Unnamed item';

  @override
  String get menuPreviewTitle => 'Preview';

  @override
  String get menuPreviewNote =>
      'This is your draft. Customers see it only after you publish.';

  @override
  String get menuPreviewPhone => 'Phone';

  @override
  String get menuPreviewDesktop => 'Desktop';

  @override
  String get menuPreviewRefresh => 'Refresh preview';

  @override
  String menuPreviewBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problems must be fixed before you can publish.',
      one: '1 problem must be fixed before you can publish.',
    );
    return '$_temp0';
  }

  @override
  String menuPreviewFrame(String frame) {
    return 'Menu preview, $frame';
  }

  @override
  String get versionsTitle => 'Version history';

  @override
  String get versionsEmpty =>
      'Nothing is published yet. Each time you publish, a version is kept here, up to the last 10.';

  @override
  String get versionsHelp =>
      'The last 10 published versions are kept. Restoring one publishes it again as a new version.';

  @override
  String versionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get versionLive => 'Live';

  @override
  String versionRestoredFrom(int version) {
    return 'Restored from version $version';
  }

  @override
  String get versionByYou => 'You';

  @override
  String get versionBySupport => 'EazySuvai support';

  @override
  String get versionNoContentChanges => 'No menu changes';

  @override
  String versionSummary(int added, int changed, int removed) {
    return '$added added · $changed changed · $removed removed';
  }

  @override
  String get versionColumnVersion => 'Version';

  @override
  String get versionColumnPublished => 'Published';

  @override
  String get versionColumnBy => 'By';

  @override
  String get versionColumnChanges => 'Changes';

  @override
  String restoreTitle(int version) {
    return 'Restore version $version?';
  }

  @override
  String restoreBody(int version, int next) {
    return 'Customers will see version $version again. It is published as version $next; the versions in between are kept.';
  }

  @override
  String restoreReplaceDraft(int version) {
    return 'Also replace my draft with version $version. Unpublished changes are lost; new categories and items go to Recently deleted.';
  }

  @override
  String restoreDone(int version, int next) {
    return 'Version $version is live again as version $next.';
  }

  @override
  String get discardTitle => 'Discard unpublished changes?';

  @override
  String discardBody(int version) {
    return 'Your draft goes back to version $version, the menu customers see. Categories and items added since then go to Recently deleted.';
  }

  @override
  String get actionDiscardChanges => 'Discard changes';

  @override
  String discardDone(int version) {
    return 'Your draft matches version $version again.';
  }

  @override
  String settingsVersionsLive(int version) {
    return 'Live · version $version';
  }

  @override
  String get statusActionHistory => 'Version history';

  @override
  String get qrPreviewHeading => 'Your QR code';

  @override
  String qrImageLabel(String url) {
    return 'QR code that opens $url';
  }

  @override
  String qrPermanentNote(String shortUrl) {
    return 'The code opens $shortUrl and always leads to your current menu, even after you change your menu link. Print it once.';
  }

  @override
  String get qrNotPublishedNote =>
      'Your menu isn\'t published yet. Until you publish, scanning shows a \"Menu coming soon\" page.';

  @override
  String get qrGenerating => 'Making your QR code…';

  @override
  String qrImageInfo(int size) {
    return '$size × $size px PNG';
  }

  @override
  String qrImageInfoLogo(int size) {
    return '$size × $size px PNG · with your logo';
  }

  @override
  String get qrLogoToggle => 'Add my logo to the centre';

  @override
  String get qrLogoToggleHelp =>
      'Uses extra error correction. We check that the code still scans before offering it.';

  @override
  String get qrLogoNone =>
      'Upload a logo in your profile to add it to the code.';

  @override
  String get qrLogoRejected =>
      'With your logo the code didn\'t scan reliably, so we\'re offering the plain code instead.';

  @override
  String get qrLogoLoadFailed =>
      'We couldn\'t load your logo, so we\'re offering the plain code.';

  @override
  String get qrDownloadHeading => 'Download and print';

  @override
  String get qrDownloadPng => 'Download PNG';

  @override
  String get qrTemplateLabel => 'Print template';

  @override
  String get qrTemplatePoster => 'A4 poster';

  @override
  String get qrTemplateCard => 'A6 table card';

  @override
  String get qrPreviewPdf => 'Preview';

  @override
  String get qrDownloadPdf => 'Download PDF';

  @override
  String qrTemplatePreviewTitle(String template) {
    return '$template preview';
  }

  @override
  String get qrShareHeading => 'Share your menu';

  @override
  String get qrCopyLink => 'Copy link';

  @override
  String get qrShareWhatsApp => 'WhatsApp';

  @override
  String get qrShareMore => 'Share…';

  @override
  String qrShareMessage(String name, String url) {
    return 'Take a look at the menu of $name: $url';
  }

  @override
  String qrShareSubject(String name) {
    return '$name – Menu';
  }

  @override
  String get qrShareUnsupported =>
      'This browser has no share menu, so we copied the link instead.';

  @override
  String get qrWhatsAppFailed =>
      'Couldn\'t open WhatsApp. We copied the link so you can paste it.';

  @override
  String qrDownloadStarted(String file) {
    return 'Downloading $file';
  }

  @override
  String qrFileShared(String file) {
    return '$file is ready to save or share';
  }

  @override
  String get qrSaveFailed => 'Couldn\'t save the file. Please try again.';

  @override
  String get qrPdfScanToView => 'Scan to view our menu';

  @override
  String get qrPdfOrVisit => 'or visit';

  @override
  String get qrClose => 'Close';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get analyticsRange7 => '7 days';

  @override
  String get analyticsRange30 => '30 days';

  @override
  String get analyticsRangeCustom => 'Custom';

  @override
  String analyticsRangeLabel(String start, String end) {
    return '$start – $end';
  }

  @override
  String get analyticsViews => 'Menu views';

  @override
  String get analyticsQrVisits => 'QR visits';

  @override
  String get analyticsQrShare => 'From the QR code';

  @override
  String get analyticsItemOpens => 'Item interest';

  @override
  String get analyticsChartTitle => 'Daily views';

  @override
  String analyticsChartSemantics(int views, int qr, String start, String end) {
    return 'Chart of daily views: $views views and $qr QR visits from $start to $end.';
  }

  @override
  String get analyticsTopCategories => 'Top categories';

  @override
  String get analyticsTopItems => 'Top items';

  @override
  String get analyticsTopEmpty => 'Nothing yet in this period.';

  @override
  String analyticsTaps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taps',
      one: '1 tap',
    );
    return '$_temp0';
  }

  @override
  String analyticsOpens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opens',
      one: '1 open',
    );
    return '$_temp0';
  }

  @override
  String get analyticsRemoved => 'Removed from the menu';

  @override
  String get analyticsMonthly => 'Monthly totals';

  @override
  String analyticsMonthRow(int views, int qr) {
    return '$views views · $qr QR visits';
  }

  @override
  String get analyticsEmptyTitle => 'No visits in this period';

  @override
  String get analyticsEmptyMessage =>
      'Share your QR code or menu link and visits will show here.';

  @override
  String get analyticsEmptyAction => 'QR & share';

  @override
  String get analyticsNotPublished =>
      'Publish your menu to start counting visits.';

  @override
  String get analyticsUpgradeTitle => 'See more history on Pro';

  @override
  String analyticsUpgradeMessage(int days) {
    return 'Your plan shows the last $days days. Upgrade to see up to a year.';
  }

  @override
  String get analyticsUpgradeAction => 'See plans';

  @override
  String get analyticsPrivacyNote =>
      'Counted without cookies or personal data. A visitor\'s views count once every 30 minutes, and bots are left out.';

  @override
  String analyticsLocked(String label) {
    return '$label (Pro)';
  }

  @override
  String get planCurrent => 'Your plan';

  @override
  String planFreeForever(String plan) {
    return '$plan · never expires';
  }

  @override
  String planActiveUntil(String plan, String date) {
    return '$plan · paid until $date';
  }

  @override
  String planGraceUntil(String plan, String expired, String date) {
    return '$plan expired on $expired. Everything keeps working until $date.';
  }

  @override
  String get planUsage => 'Usage';

  @override
  String planUsageItems(int count, String max) {
    return 'Items: $count of $max';
  }

  @override
  String planUsageCategories(int count, String max) {
    return 'Categories: $count of $max';
  }

  @override
  String get planUnlimited => 'unlimited';

  @override
  String get planCompare => 'Plans';

  @override
  String get planCurrentBadge => 'Current plan';

  @override
  String planFeatureItems(int count) {
    return 'Up to $count items';
  }

  @override
  String planFeatureCategories(int count) {
    return 'Up to $count categories';
  }

  @override
  String get planFeatureCategoriesUnlimited => 'Unlimited categories';

  @override
  String get planFeatureThemesAll => 'All themes, including premium';

  @override
  String get planFeatureThemesBasic => '2 standard themes';

  @override
  String planFeatureAnalytics(int days) {
    return '$days days of analytics history';
  }

  @override
  String get planFeatureQrLogo => 'Your logo in the QR code';

  @override
  String get planFeatureNoQrLogo => 'Plain QR code';

  @override
  String get planFeatureNoBranding => 'No \"Powered by EazySuvai\" footer';

  @override
  String get planFeatureBranding => '\"Powered by EazySuvai\" footer';

  @override
  String planRequest(String plan) {
    return 'Request $plan';
  }

  @override
  String planRequestTitle(String plan) {
    return 'Request $plan';
  }

  @override
  String planRequestBody(String plan) {
    return 'We\'ll contact you with payment details. Once we receive the payment, $plan starts at once. There is no online payment yet.';
  }

  @override
  String get planBillingMonthly => 'Monthly';

  @override
  String get planBillingAnnual => 'Annual';

  @override
  String get planRequestSend => 'Send request';

  @override
  String get planRequestSent => 'Request sent. We\'ll contact you soon.';

  @override
  String get planRequestPending =>
      'Upgrade requested – we\'ll contact you with payment details.';

  @override
  String planPrice(String price, String period) {
    return '$price / $period';
  }

  @override
  String get planPriceOnRequest => 'Price on request';

  @override
  String get planSwitchToFree => 'Switch to Free';

  @override
  String get planManageHidden => 'Choose hidden items';

  @override
  String bannerGrace(String plan, String date) {
    return 'Your $plan plan has expired. Renew before $date to keep your Pro features.';
  }

  @override
  String bannerExpiring(String plan, int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$plan ends in $_temp0 ($date).';
  }

  @override
  String bannerOverLimit(int count) {
    return 'Your menu is over the plan limit: $count hidden. They are kept, not deleted.';
  }

  @override
  String get bannerRestored =>
      'Hidden content is back in your draft. Publish to show it.';

  @override
  String get bannerRenew => 'Renew';

  @override
  String get bannerManage => 'Manage';

  @override
  String get bannerPublish => 'Publish';

  @override
  String get hiddenTitle => 'Hidden items';

  @override
  String get hiddenDowngradeTitle => 'Switch to Free';

  @override
  String hiddenIntro(String max) {
    return 'Your plan shows up to $max items. Choose which ones customers see; the others are kept, not deleted.';
  }

  @override
  String hiddenDowngradeIntro(int max, int cats) {
    return 'Free shows up to $max items and $cats categories. Choose what stays visible. The rest is hidden, not deleted, and comes back if you upgrade again.';
  }

  @override
  String hiddenVisible(int count, String max) {
    return 'Visible ($count of $max)';
  }

  @override
  String hiddenHidden(int count) {
    return 'Hidden ($count)';
  }

  @override
  String get hiddenCategories => 'Categories';

  @override
  String get hiddenItems => 'Items';

  @override
  String hiddenShow(String name) {
    return 'Show $name';
  }

  @override
  String hiddenHide(String name) {
    return 'Hide $name';
  }

  @override
  String hiddenOver(int count) {
    return '$count too many visible. Hide some to save.';
  }

  @override
  String get hiddenSave => 'Save';

  @override
  String get hiddenSaved => 'Saved. Publish to update your menu.';

  @override
  String get hiddenConfirmDowngrade => 'Switch to Free now';

  @override
  String get hiddenDowngradeConfirmTitle => 'Switch to Free?';

  @override
  String get hiddenDowngradeConfirmBody =>
      'Your paid plan ends now and is not refunded. The hidden content leaves your menu at once.';

  @override
  String get hiddenDowngraded => 'You\'re on the Free plan now.';

  @override
  String get hiddenNone => 'Nothing is hidden.';

  @override
  String get themePremiumLockedTitle => 'Premium theme';

  @override
  String themePremiumLockedBody(String name) {
    return '$name is part of Pro. Upgrade to use premium themes.';
  }

  @override
  String get qrLogoPro => 'Adding your logo to the QR code is part of Pro.';

  @override
  String get seePlans => 'See plans';

  @override
  String get problemPremiumTheme =>
      'Your theme is a premium theme. Choose a standard theme, or upgrade to Pro.';

  @override
  String get blockedSuspendedTitle => 'Your account is suspended';

  @override
  String get blockedSuspendedBody =>
      'You can\'t make changes while the account is suspended. Customers see a \"temporarily unavailable\" page.';

  @override
  String get blockedDeactivatedTitle => 'Your account is deactivated';

  @override
  String get blockedDeactivatedBody =>
      'Your menu is no longer available. The account can be reactivated within 90 days of deactivation.';

  @override
  String blockedContact(String email) {
    return 'Contact EazySuvai support: $email';
  }

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSubtitle => 'Export your menu, delete your account';

  @override
  String get exportTitle => 'Export your menu';

  @override
  String get exportHelp =>
      'Download every category and item with prices, as a spreadsheet (CSV) or a data file (JSON).';

  @override
  String get exportCsv => 'Download CSV';

  @override
  String get exportJson => 'Download JSON';

  @override
  String exportDone(String file) {
    return '$file is ready';
  }

  @override
  String get deleteTitle => 'Delete account';

  @override
  String get deleteHelp =>
      'Your menu goes offline at once. Everything is deleted after 90 days; until then support can reopen the account.';

  @override
  String get deleteStart => 'Delete my account…';

  @override
  String get deleteStepExport => 'Keep a copy';

  @override
  String get deleteExportOffer =>
      'Download your menu before you go. You can\'t get it back after the account is deleted.';

  @override
  String get deleteContinue => 'Continue';

  @override
  String get deleteStepName => 'Confirm the restaurant';

  @override
  String deleteTypeName(String name) {
    return 'Type \"$name\" to confirm.';
  }

  @override
  String get deleteNameLabel => 'Restaurant name';

  @override
  String get deleteStepConfirm => 'Delete';

  @override
  String get deleteConsequences =>
      'Your menu and QR code stop working now and customers see \"Menu no longer available\". You are signed out. All data, photos and analytics are deleted after 90 days. Payment records are kept as tax law requires.';

  @override
  String get deleteConfirm => 'Delete my account';

  @override
  String get legalAgreePrefix => 'By creating an account, you agree to the';

  @override
  String get legalAnd => 'and the';

  @override
  String get legalTerms => 'Terms of service';

  @override
  String get legalPrivacy => 'Privacy policy';
}
