// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'EazySuvai Admin';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navRestaurants => 'Restaurants';

  @override
  String get navPlans => 'Plans';

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
  String get actionGoHome => 'Go to dashboard';

  @override
  String get authTagline =>
      'Platform administration. Two-factor sign-in is required.';

  @override
  String get signInSubtitle => 'Sign in with your administrator account.';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get mfaCodeTitle => 'Enter your code';

  @override
  String get mfaCodeSubtitle =>
      'Open your authenticator app and enter the 6-digit code for EazySuvai Admin.';

  @override
  String get fieldMfaCode => '6-digit code';

  @override
  String get validationMfaCode =>
      'Enter the 6 digits from your authenticator app.';

  @override
  String get actionVerify => 'Verify';

  @override
  String get mfaSetupTitle => 'Set up two-factor sign-in';

  @override
  String get mfaSetupSubtitle =>
      'Administrators must use an authenticator app, such as Google Authenticator or Microsoft Authenticator.';

  @override
  String get mfaSetupStep1 =>
      '1. Scan this QR code with your authenticator app.';

  @override
  String get mfaSetupStep2 => 'Or enter this key by hand:';

  @override
  String get mfaSetupStep3 => '2. Enter the 6-digit code the app shows.';

  @override
  String get mfaQrLabel => 'QR code for your authenticator app';

  @override
  String get actionCopyKey => 'Copy key';

  @override
  String get mfaKeyCopied => 'Key copied.';

  @override
  String get actionEnable => 'Turn on two-factor sign-in';

  @override
  String get mfaEnrolled =>
      'Two-factor sign-in is on. Sign in again with your code.';

  @override
  String get actionStartSetup => 'Start setup';

  @override
  String get navUpgrades => 'Upgrades';

  @override
  String get readOnlyNotice =>
      'Read-only on small screens. Use a tablet or computer to make changes.';

  @override
  String get upgradesPending => 'Pending';

  @override
  String get upgradesActivated => 'Activated';

  @override
  String get upgradesClosed => 'Declined';

  @override
  String get upgradesEmpty => 'No requests here.';

  @override
  String get colRestaurant => 'Restaurant';

  @override
  String get colContact => 'Contact';

  @override
  String get colPlan => 'Plan';

  @override
  String get colBilling => 'Billing';

  @override
  String get colRequested => 'Requested';

  @override
  String get colActions => 'Actions';

  @override
  String get billingMonthly => 'Monthly';

  @override
  String get billingAnnual => 'Annual';

  @override
  String get recordPayment => 'Record payment';

  @override
  String get decline => 'Decline';

  @override
  String recordPaymentTitle(String name) {
    return 'Record payment – $name';
  }

  @override
  String recordPaymentPlan(String plan) {
    return 'Plan: $plan';
  }

  @override
  String get paymentAmount => 'Amount';

  @override
  String get paymentAmountInvalid => 'Enter the amount received.';

  @override
  String get paymentCurrency => 'Currency';

  @override
  String get paymentMethod => 'Method';

  @override
  String paymentMethodName(String method) {
    String _temp0 = intl.Intl.selectLogic(method, {
      'bankTransfer': 'Bank transfer',
      'upi': 'UPI',
      'cash': 'Cash',
      'cheque': 'Cheque',
      'card': 'Card',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String get paymentReference => 'Reference (transaction or receipt number)';

  @override
  String get paymentPaidAt => 'Paid on';

  @override
  String get paymentStartAt => 'Plan starts';

  @override
  String get paymentEndAt => 'Plan ends';

  @override
  String get paymentNote => 'Note (optional, kept in the audit log)';

  @override
  String get recordAndActivate => 'Record and activate';

  @override
  String get paymentRecorded =>
      'Payment recorded. The plan is active and the owner has been emailed.';

  @override
  String get declineTitle => 'Decline request';

  @override
  String get reasonLabel => 'Reason';

  @override
  String get reasonHelp => 'Required. Saved in the audit log.';

  @override
  String get requestDeclined => 'Request declined.';

  @override
  String get fieldRequired => 'Required.';

  @override
  String get navCatalog => 'Catalog';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved.';

  @override
  String get none => 'None yet.';

  @override
  String get premium => 'Premium';

  @override
  String get retired => 'Retired';

  @override
  String get retiredHelp => 'Hidden from new choices; existing menus keep it.';

  @override
  String planSummary(String items, String categories, String days) {
    return 'Items $items · categories $categories · analytics $days days';
  }

  @override
  String planPrices(String prices) {
    return 'Prices (monthly / annual, minor units): $prices';
  }

  @override
  String get planInactive => 'Inactive: not offered to owners.';

  @override
  String get pricesFormat =>
      'Write one currency per line: code, monthly, annual (for example INR 49900 499900).';

  @override
  String get pricesHelp =>
      'One per line: INR 49900 499900 (minor units: 49900 = ₹499.00).';

  @override
  String editPlan(String id) {
    return 'Edit plan $id';
  }

  @override
  String get fieldName => 'Name';

  @override
  String get fieldMaxItems => 'Maximum items';

  @override
  String get fieldMaxCategories => 'Maximum categories';

  @override
  String get emptyUnlimited => 'Leave empty for unlimited.';

  @override
  String get fieldAnalyticsDays => 'Analytics history (days)';

  @override
  String get fieldPremiumThemes => 'Premium themes';

  @override
  String get fieldQrLogo => 'Logo in the QR code';

  @override
  String get fieldRemoveBranding => 'No \"Powered by EazySuvai\" footer';

  @override
  String get fieldActive => 'Offered to owners';

  @override
  String get fieldPrices => 'Prices';

  @override
  String get applyToSubscribers => 'Apply to current subscribers now';

  @override
  String get applyToSubscribersHelp =>
      'Otherwise the change reaches restaurants at their next plan change.';

  @override
  String get tabLabels => 'Dietary labels';

  @override
  String get tabTags => 'Tags';

  @override
  String get tabThemes => 'Themes';

  @override
  String sortOrder(int n) {
    return 'Order $n';
  }

  @override
  String get addEntry => 'Add';

  @override
  String editEntry(String name) {
    return 'Edit $name';
  }

  @override
  String get fieldId => 'Id';

  @override
  String get idHelp =>
      'Lower-case letters, digits and dashes. Can\'t be changed later.';

  @override
  String get fieldIcon => 'Icon';

  @override
  String get fieldColor => 'Colour (#RRGGBB)';

  @override
  String get fieldSort => 'Order';

  @override
  String get fieldFont => 'Font (Google Fonts family)';

  @override
  String get fieldLayout => 'Layout';

  @override
  String get fieldCardLayout => 'Card layout';

  @override
  String get fieldMode => 'Mode';

  @override
  String get previewHeading => 'Starters';

  @override
  String get previewBody => 'Idli, sambar and chutney';

  @override
  String contrastIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count text colours fail',
      one: '1 text colour fails',
    );
    return '$_temp0 WCAG AA. The menu would adjust it automatically.';
  }

  @override
  String get acceptContrastFixes => 'Save anyway, with the automatic fix';

  @override
  String get dashRestaurants => 'Restaurants';

  @override
  String get dashActive => 'Active';

  @override
  String get dashSuspended => 'Suspended';

  @override
  String get dashDeactivated => 'Deactivated';

  @override
  String get dashFree => 'Free plans';

  @override
  String get dashPaid => 'Paid plans';

  @override
  String get dashGrace => 'In grace';

  @override
  String get dashExpired => 'Expired (to date)';

  @override
  String get dashPending => 'Upgrade requests';

  @override
  String get dashItems => 'Menu items';

  @override
  String get dashViews => 'Menu views';

  @override
  String get dashQrVisits => 'QR visits';

  @override
  String get dashRecent => 'Recent sign-ups';

  @override
  String get dashRecompute => 'Recalculate';

  @override
  String get dashRecomputed => 'Counters recalculated.';

  @override
  String get dashNoSignups => 'No restaurants yet.';

  @override
  String statusName(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'active': 'Active',
      'suspended': 'Suspended',
      'deactivated': 'Deactivated',
      'deleted': 'Deleted',
      'other': '$status',
    });
    return '$_temp0';
  }

  @override
  String subscriptionStatusName(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'free': 'Free',
      'active': 'Paid',
      'grace': 'In grace',
      'other': '$status',
    });
    return '$_temp0';
  }

  @override
  String get filterAny => 'Any';

  @override
  String get searchRestaurants => 'Name, slug, email or mobile';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterPlan => 'Plan';

  @override
  String get filterCountry => 'Country';

  @override
  String get filterDates => 'Registered between';

  @override
  String get noRestaurants => 'No restaurants match.';

  @override
  String pageNumber(int n) {
    return 'Page $n';
  }

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get colSlug => 'Slug';

  @override
  String get colCountry => 'Country';

  @override
  String get colStatus => 'Status';

  @override
  String get colItems => 'Items';

  @override
  String get colRegistered => 'Registered';

  @override
  String get restaurantDetail => 'Restaurant';

  @override
  String statusActionTitle(String to) {
    String _temp0 = intl.Intl.selectLogic(to, {
      'suspended': 'Suspend this restaurant?',
      'deactivated': 'Deactivate this restaurant?',
      'other': 'Activate this restaurant?',
    });
    return '$_temp0';
  }

  @override
  String statusActionMessage(String to) {
    String _temp0 = intl.Intl.selectLogic(to, {
      'suspended':
          'The owner is signed out and can\'t log in to edit. The public menu shows \"temporarily unavailable\" (503).',
      'deactivated':
          'The owner is signed out. The menu shows \"no longer available\" (410) and leaves the sitemap. It can be reactivated within 90 days.',
      'other': 'The owner can sign in again and the menu goes live.',
    });
    return '$_temp0';
  }

  @override
  String statusActionLabel(String to) {
    String _temp0 = intl.Intl.selectLogic(to, {
      'suspended': 'Suspend',
      'deactivated': 'Deactivate',
      'reactivate': 'Reactivate',
      'other': 'Activate',
    });
    return '$_temp0';
  }

  @override
  String get statusChanged => 'Status changed and logged.';

  @override
  String get extendPick => 'New expiry date';

  @override
  String get extendTitle => 'Extend the subscription';

  @override
  String get extend => 'Extend';

  @override
  String get subscriptionChanged => 'Subscription changed and logged.';

  @override
  String get downgradeTitle => 'Move to Free now?';

  @override
  String get downgradeMessage =>
      'Content over the Free limits is hidden (not deleted) and a new version is published. The owner is emailed.';

  @override
  String get downgrade => 'Downgrade to Free';

  @override
  String get detailProfile => 'Profile';

  @override
  String get detailStatus => 'Account status';

  @override
  String get detailSubscription => 'Subscription';

  @override
  String get detailPayments => 'Payments';

  @override
  String get detailHistory => 'Plan history';

  @override
  String get detailActivity => 'Activity';

  @override
  String get fieldOwner => 'Owner';

  @override
  String get fieldMobile => 'Mobile';

  @override
  String get fieldCountry => 'Country, city';

  @override
  String get fieldBusiness => 'Business type';

  @override
  String get fieldCurrency => 'Currency, time zone';

  @override
  String get fieldMenu => 'Categories / items';

  @override
  String get notPublished => 'not published';

  @override
  String publishedVersion(int n, String date) {
    return 'version $n on $date';
  }

  @override
  String get fieldQrCode => 'QR code';

  @override
  String get fieldRegistered => 'Registered';

  @override
  String get fieldLastSignIn => 'Last sign-in';

  @override
  String get copyLink => 'Copy link';

  @override
  String get fieldReason => 'Reason';

  @override
  String get fieldDeactivated => 'Deactivated on';

  @override
  String get fieldStarts => 'Starts';

  @override
  String get fieldExpires => 'Expires';

  @override
  String get fieldGraceEnds => 'Grace ends';

  @override
  String get activitySignIn => 'Last sign-in';

  @override
  String get settingsPlatform => 'Platform settings';

  @override
  String get fieldReservedSlugs => 'Reserved slugs';

  @override
  String get commaSeparated => 'Separate with commas.';

  @override
  String get fieldGraceDays => 'Grace period (days, 0–30)';

  @override
  String get graceDaysHelp =>
      'After a paid plan expires, everything keeps working this long.';

  @override
  String get fieldFonts => 'Fonts owners can choose';

  @override
  String get fieldCurrencies => 'Currencies';

  @override
  String get currenciesHelp =>
      'Code=decimals, separated by commas (INR=2, KWD=3).';

  @override
  String get fieldSupportEmail => 'Support email (shown to suspended owners)';

  @override
  String get fieldLiveIdleMinutes =>
      'Live menu updates: stop when idle (minutes, 1–240)';

  @override
  String get liveIdleMinutesHelp =>
      'An open menu stops checking for price and availability changes after this long without a tap or scroll. It checks again as soon as the customer taps, scrolls or comes back to the page.';

  @override
  String get fieldLiveMaxMinutes =>
      'Live menu updates: limit per scan (minutes, 5–720)';

  @override
  String get liveMaxMinutesHelp =>
      'After this long from opening the menu, it stops checking for changes, even if the customer is still using it. Opening the link or scanning the QR code again starts a new session.';

  @override
  String get settingsAnnouncement => 'Announcement';

  @override
  String get announcementHelp =>
      'A short banner every owner sees on their dashboard.';

  @override
  String get fieldAnnouncement => 'Text';

  @override
  String get levelInfo => 'Information';

  @override
  String get levelWarning => 'Warning';

  @override
  String get showToOwners => 'Show to owners';

  @override
  String get settingsAdmins => 'Administrators';

  @override
  String get addAdminHelp =>
      'Add someone who already has an account. They must set up an authenticator app at their next sign-in.';

  @override
  String get grantAdmin => 'Make admin';

  @override
  String get revokeAdmin => 'Remove';

  @override
  String grantAdminTitle(String email) {
    return 'Make $email an administrator?';
  }

  @override
  String revokeAdminTitle(String email) {
    return 'Remove $email as administrator?';
  }

  @override
  String get navAudit => 'Audit log';

  @override
  String get auditActor => 'Actor (uid)';

  @override
  String get auditAction => 'Action (for example restaurant.suspend)';

  @override
  String get auditRestaurant => 'Restaurant id';

  @override
  String get auditApply => 'Filter';

  @override
  String get auditEmpty => 'No entries match.';

  @override
  String get auditTime => 'Time';

  @override
  String get auditTarget => 'Target';

  @override
  String get auditDetails => 'Details';

  @override
  String get auditAnonymized => 'Anonymised';

  @override
  String get auditAnonymizedHelp =>
      'Personal data was removed after the account was deleted.';

  @override
  String get viewAuditLog => 'Full audit log';

  @override
  String get metricsTitle => 'Success metrics';

  @override
  String get metricActivated =>
      'Activated restaurants (published at least once)';

  @override
  String get metricPublished => 'Live published menus';

  @override
  String get metricQrDownloads => 'QR codes downloaded';

  @override
  String get metricMedianPublish => 'Median time from sign-up to first publish';

  @override
  String metricMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String metricMonthViews(String month) {
    return 'Menu views and QR visits, $month';
  }

  @override
  String metricViewsAndQr(String views, String qr) {
    return '$views views · $qr QR visits';
  }

  @override
  String get metricConversion => 'Free-to-paid conversions';

  @override
  String get metricRenewal => 'Subscription renewals (renewal rate)';

  @override
  String get metricChurn => 'Churn (deactivated or deleted)';

  @override
  String get metricAvgItems => 'Average items per restaurant';

  @override
  String get metricSupport => 'Support requests per restaurant';

  @override
  String get metricSupportOutside => 'Tracked in the support inbox';

  @override
  String get changePlan => 'Change plan';

  @override
  String changePlanTitle(String name) {
    return 'Change the plan for $name';
  }

  @override
  String changePlanCurrent(String plan) {
    return 'Current plan: $plan';
  }

  @override
  String get changePlanNew => 'New plan';

  @override
  String get changePlanNoOther => 'There is no other active plan to move to.';

  @override
  String get changePlanPaidNote =>
      'No payment is recorded. Use this for trials, complimentary upgrades and corrections. After a payment, use Record payment instead.';

  @override
  String get changePlanFreeNote =>
      'Content over this plan\'s limits is hidden and the menu is republished.';

  @override
  String get changePlanEndInvalid =>
      'The plan must end after it starts and after today.';

  @override
  String footerCopyright(String year) {
    return '© $year AVAIL404 (OPC) Private Limited';
  }

  @override
  String get footerEnvironmentDev => 'Development';
}
