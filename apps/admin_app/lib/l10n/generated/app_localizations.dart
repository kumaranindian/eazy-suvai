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

  /// Navigation: upgrade requests (M10).
  ///
  /// In en, this message translates to:
  /// **'Upgrades'**
  String get navUpgrades;

  /// Admin app below 600 px (M11).
  ///
  /// In en, this message translates to:
  /// **'Read-only on small screens. Use a tablet or computer to make changes.'**
  String get readOnlyNotice;

  /// Upgrade request status.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get upgradesPending;

  /// Upgrade request status.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get upgradesActivated;

  /// Upgrade request status.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get upgradesClosed;

  /// Upgrade requests: empty.
  ///
  /// In en, this message translates to:
  /// **'No requests here.'**
  String get upgradesEmpty;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get colRestaurant;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get colContact;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get colPlan;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get colBilling;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get colRequested;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get colActions;

  /// Billing period.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get billingMonthly;

  /// Billing period.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get billingAnnual;

  /// Button (FR-106).
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get recordPayment;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Record payment – {name}'**
  String recordPaymentTitle(String name);

  /// Dialog line.
  ///
  /// In en, this message translates to:
  /// **'Plan: {plan}'**
  String recordPaymentPlan(String plan);

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get paymentAmount;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount received.'**
  String get paymentAmountInvalid;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get paymentCurrency;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get paymentMethod;

  /// Payment method names.
  ///
  /// In en, this message translates to:
  /// **'{method, select, bankTransfer{Bank transfer} upi{UPI} cash{Cash} cheque{Cheque} card{Card} other{Other}}'**
  String paymentMethodName(String method);

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Reference (transaction or receipt number)'**
  String get paymentReference;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Paid on'**
  String get paymentPaidAt;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Plan starts'**
  String get paymentStartAt;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Plan ends'**
  String get paymentEndAt;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Note (optional, kept in the audit log)'**
  String get paymentNote;

  /// Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Record and activate'**
  String get recordAndActivate;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded. The plan is active and the owner has been emailed.'**
  String get paymentRecorded;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Decline request'**
  String get declineTitle;

  /// Field: audit reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// Field help.
  ///
  /// In en, this message translates to:
  /// **'Required. Saved in the audit log.'**
  String get reasonHelp;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Request declined.'**
  String get requestDeclined;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Required.'**
  String get fieldRequired;

  /// Navigation: labels, tags and themes.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get navCatalog;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get saved;

  /// Empty list.
  ///
  /// In en, this message translates to:
  /// **'None yet.'**
  String get none;

  /// Theme flag.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// Label, tag or theme flag (FR-104).
  ///
  /// In en, this message translates to:
  /// **'Retired'**
  String get retired;

  /// Retired help (FR-104).
  ///
  /// In en, this message translates to:
  /// **'Hidden from new choices; existing menus keep it.'**
  String get retiredHelp;

  /// Plan card.
  ///
  /// In en, this message translates to:
  /// **'Items {items} · categories {categories} · analytics {days} days'**
  String planSummary(String items, String categories, String days);

  /// Plan card.
  ///
  /// In en, this message translates to:
  /// **'Prices (monthly / annual, minor units): {prices}'**
  String planPrices(String prices);

  /// Plan card.
  ///
  /// In en, this message translates to:
  /// **'Inactive: not offered to owners.'**
  String get planInactive;

  /// Plan editor validation.
  ///
  /// In en, this message translates to:
  /// **'Write one currency per line: code, monthly, annual (for example INR 49900 499900).'**
  String get pricesFormat;

  /// Plan editor help.
  ///
  /// In en, this message translates to:
  /// **'One per line: INR 49900 499900 (minor units: 49900 = ₹499.00).'**
  String get pricesHelp;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Edit plan {id}'**
  String editPlan(String id);

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Maximum items'**
  String get fieldMaxItems;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Maximum categories'**
  String get fieldMaxCategories;

  /// Field help.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for unlimited.'**
  String get emptyUnlimited;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Analytics history (days)'**
  String get fieldAnalyticsDays;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Premium themes'**
  String get fieldPremiumThemes;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Logo in the QR code'**
  String get fieldQrLogo;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'No \"Powered by EazySuvai\" footer'**
  String get fieldRemoveBranding;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Offered to owners'**
  String get fieldActive;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Prices'**
  String get fieldPrices;

  /// Plan editor (FR-077).
  ///
  /// In en, this message translates to:
  /// **'Apply to current subscribers now'**
  String get applyToSubscribers;

  /// Plan editor help (FR-077).
  ///
  /// In en, this message translates to:
  /// **'Otherwise the change reaches restaurants at their next plan change.'**
  String get applyToSubscribersHelp;

  /// Tab.
  ///
  /// In en, this message translates to:
  /// **'Dietary labels'**
  String get tabLabels;

  /// Tab.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tabTags;

  /// Tab.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get tabThemes;

  /// List subtitle.
  ///
  /// In en, this message translates to:
  /// **'Order {n}'**
  String sortOrder(int n);

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addEntry;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editEntry(String name);

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Id'**
  String get fieldId;

  /// Field help.
  ///
  /// In en, this message translates to:
  /// **'Lower-case letters, digits and dashes. Can\'t be changed later.'**
  String get idHelp;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get fieldIcon;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Colour (#RRGGBB)'**
  String get fieldColor;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get fieldSort;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Font (Google Fonts family)'**
  String get fieldFont;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get fieldLayout;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Card layout'**
  String get fieldCardLayout;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get fieldMode;

  /// Theme preview heading.
  ///
  /// In en, this message translates to:
  /// **'Starters'**
  String get previewHeading;

  /// Theme preview text.
  ///
  /// In en, this message translates to:
  /// **'Idli, sambar and chutney'**
  String get previewBody;

  /// Theme editor (FR-060).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 text colour fails} other{{count} text colours fail}} WCAG AA. The menu would adjust it automatically.'**
  String contrastIssues(int count);

  /// Theme editor.
  ///
  /// In en, this message translates to:
  /// **'Save anyway, with the automatic fix'**
  String get acceptContrastFixes;

  /// Dashboard tile (FR-085).
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get dashRestaurants;

  /// Dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get dashActive;

  /// Dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get dashSuspended;

  /// Dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'Deactivated'**
  String get dashDeactivated;

  /// Dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'Free plans'**
  String get dashFree;

  /// Dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'Paid plans'**
  String get dashPaid;

  /// Dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'In grace'**
  String get dashGrace;

  /// Dashboard tile: paid plans that ran out.
  ///
  /// In en, this message translates to:
  /// **'Expired (to date)'**
  String get dashExpired;

  /// Dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'Upgrade requests'**
  String get dashPending;

  /// Dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'Menu items'**
  String get dashItems;

  /// Dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'Menu views'**
  String get dashViews;

  /// Dashboard tile.
  ///
  /// In en, this message translates to:
  /// **'QR visits'**
  String get dashQrVisits;

  /// Dashboard card.
  ///
  /// In en, this message translates to:
  /// **'Recent sign-ups'**
  String get dashRecent;

  /// Dashboard: recompute counters.
  ///
  /// In en, this message translates to:
  /// **'Recalculate'**
  String get dashRecompute;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Counters recalculated.'**
  String get dashRecomputed;

  /// Dashboard empty.
  ///
  /// In en, this message translates to:
  /// **'No restaurants yet.'**
  String get dashNoSignups;

  /// Restaurant status.
  ///
  /// In en, this message translates to:
  /// **'{status, select, active{Active} suspended{Suspended} deactivated{Deactivated} deleted{Deleted} other{{status}}}'**
  String statusName(String status);

  /// Subscription status.
  ///
  /// In en, this message translates to:
  /// **'{status, select, free{Free} active{Paid} grace{In grace} other{{status}}}'**
  String subscriptionStatusName(String status);

  /// Filter value.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterAny;

  /// Search field (FR-086).
  ///
  /// In en, this message translates to:
  /// **'Name, slug, email or mobile'**
  String get searchRestaurants;

  /// Filter.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get filterStatus;

  /// Filter.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get filterPlan;

  /// Filter.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get filterCountry;

  /// Filter.
  ///
  /// In en, this message translates to:
  /// **'Registered between'**
  String get filterDates;

  /// Empty search.
  ///
  /// In en, this message translates to:
  /// **'No restaurants match.'**
  String get noRestaurants;

  /// Pager.
  ///
  /// In en, this message translates to:
  /// **'Page {n}'**
  String pageNumber(int n);

  /// Pager tooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// Pager tooltip.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Slug'**
  String get colSlug;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get colCountry;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get colStatus;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get colItems;

  /// Table column.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get colRegistered;

  /// Detail title while loading.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get restaurantDetail;

  /// Status dialog title (FR-088).
  ///
  /// In en, this message translates to:
  /// **'{to, select, suspended{Suspend this restaurant?} deactivated{Deactivate this restaurant?} other{Activate this restaurant?}}'**
  String statusActionTitle(String to);

  /// Status dialog message (FR-099).
  ///
  /// In en, this message translates to:
  /// **'{to, select, suspended{The owner is signed out and can\'t log in to edit. The public menu shows \"temporarily unavailable\" (503).} deactivated{The owner is signed out. The menu shows \"no longer available\" (410) and leaves the sitemap. It can be reactivated within 90 days.} other{The owner can sign in again and the menu goes live.}}'**
  String statusActionMessage(String to);

  /// Status button.
  ///
  /// In en, this message translates to:
  /// **'{to, select, suspended{Suspend} deactivated{Deactivate} reactivate{Reactivate} other{Activate}}'**
  String statusActionLabel(String to);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Status changed and logged.'**
  String get statusChanged;

  /// Date picker help.
  ///
  /// In en, this message translates to:
  /// **'New expiry date'**
  String get extendPick;

  /// Reason dialog title (FR-081).
  ///
  /// In en, this message translates to:
  /// **'Extend the subscription'**
  String get extendTitle;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Extend'**
  String get extend;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Subscription changed and logged.'**
  String get subscriptionChanged;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Move to Free now?'**
  String get downgradeTitle;

  /// Dialog message (FR-101).
  ///
  /// In en, this message translates to:
  /// **'Content over the Free limits is hidden (not deleted) and a new version is published. The owner is emailed.'**
  String get downgradeMessage;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Downgrade to Free'**
  String get downgrade;

  /// Detail card.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get detailProfile;

  /// Detail card.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get detailStatus;

  /// Detail card.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get detailSubscription;

  /// Detail card (FR-087).
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get detailPayments;

  /// Detail card (FR-087).
  ///
  /// In en, this message translates to:
  /// **'Plan history'**
  String get detailHistory;

  /// Detail card (FR-089).
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get detailActivity;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get fieldOwner;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get fieldMobile;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Country, city'**
  String get fieldCountry;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get fieldBusiness;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Currency, time zone'**
  String get fieldCurrency;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Categories / items'**
  String get fieldMenu;

  /// Detail.
  ///
  /// In en, this message translates to:
  /// **'not published'**
  String get notPublished;

  /// Detail.
  ///
  /// In en, this message translates to:
  /// **'version {n} on {date}'**
  String publishedVersion(int n, String date);

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get fieldQrCode;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get fieldRegistered;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Last sign-in'**
  String get fieldLastSignIn;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get fieldReason;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Deactivated on'**
  String get fieldDeactivated;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get fieldStarts;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get fieldExpires;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Grace ends'**
  String get fieldGraceEnds;

  /// Activity row.
  ///
  /// In en, this message translates to:
  /// **'Last sign-in'**
  String get activitySignIn;

  /// Settings card.
  ///
  /// In en, this message translates to:
  /// **'Platform settings'**
  String get settingsPlatform;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Reserved slugs'**
  String get fieldReservedSlugs;

  /// Field help.
  ///
  /// In en, this message translates to:
  /// **'Separate with commas.'**
  String get commaSeparated;

  /// Field (FR-100).
  ///
  /// In en, this message translates to:
  /// **'Grace period (days, 0–30)'**
  String get fieldGraceDays;

  /// Field help.
  ///
  /// In en, this message translates to:
  /// **'After a paid plan expires, everything keeps working this long.'**
  String get graceDaysHelp;

  /// Field (FR-059).
  ///
  /// In en, this message translates to:
  /// **'Fonts owners can choose'**
  String get fieldFonts;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Currencies'**
  String get fieldCurrencies;

  /// Field help.
  ///
  /// In en, this message translates to:
  /// **'Code=decimals, separated by commas (INR=2, KWD=3).'**
  String get currenciesHelp;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Support email (shown to suspended owners)'**
  String get fieldSupportEmail;

  /// Settings card.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get settingsAnnouncement;

  /// Settings help.
  ///
  /// In en, this message translates to:
  /// **'A short banner every owner sees on their dashboard.'**
  String get announcementHelp;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get fieldAnnouncement;

  /// Level.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get levelInfo;

  /// Level.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get levelWarning;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Show to owners'**
  String get showToOwners;

  /// Settings card.
  ///
  /// In en, this message translates to:
  /// **'Administrators'**
  String get settingsAdmins;

  /// Admins help.
  ///
  /// In en, this message translates to:
  /// **'Add someone who already has an account. They must set up an authenticator app at their next sign-in.'**
  String get addAdminHelp;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get grantAdmin;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get revokeAdmin;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Make {email} an administrator?'**
  String grantAdminTitle(String email);

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Remove {email} as administrator?'**
  String revokeAdminTitle(String email);

  /// Navigation (M12).
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get navAudit;

  /// Filter and column.
  ///
  /// In en, this message translates to:
  /// **'Actor (uid)'**
  String get auditActor;

  /// Filter and column.
  ///
  /// In en, this message translates to:
  /// **'Action (for example restaurant.suspend)'**
  String get auditAction;

  /// Filter and column.
  ///
  /// In en, this message translates to:
  /// **'Restaurant id'**
  String get auditRestaurant;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get auditApply;

  /// Empty audit log.
  ///
  /// In en, this message translates to:
  /// **'No entries match.'**
  String get auditEmpty;

  /// Column.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get auditTime;

  /// Detail.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get auditTarget;

  /// Detail.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get auditDetails;

  /// Detail: personal data removed (§7.7).
  ///
  /// In en, this message translates to:
  /// **'Anonymised'**
  String get auditAnonymized;

  /// Detail help.
  ///
  /// In en, this message translates to:
  /// **'Personal data was removed after the account was deleted.'**
  String get auditAnonymizedHelp;

  /// Link from the restaurant activity card.
  ///
  /// In en, this message translates to:
  /// **'Full audit log'**
  String get viewAuditLog;

  /// Dashboard card title: the FRD success metrics.
  ///
  /// In en, this message translates to:
  /// **'Success metrics'**
  String get metricsTitle;

  /// Metric label.
  ///
  /// In en, this message translates to:
  /// **'Activated restaurants (published at least once)'**
  String get metricActivated;

  /// Metric label.
  ///
  /// In en, this message translates to:
  /// **'Live published menus'**
  String get metricPublished;

  /// Metric label.
  ///
  /// In en, this message translates to:
  /// **'QR codes downloaded'**
  String get metricQrDownloads;

  /// Metric label.
  ///
  /// In en, this message translates to:
  /// **'Median time from sign-up to first publish'**
  String get metricMedianPublish;

  /// A duration in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute} other{{minutes} minutes}}'**
  String metricMinutes(int minutes);

  /// Metric label; month is yyyy-MM.
  ///
  /// In en, this message translates to:
  /// **'Menu views and QR visits, {month}'**
  String metricMonthViews(String month);

  /// Metric value.
  ///
  /// In en, this message translates to:
  /// **'{views} views · {qr} QR visits'**
  String metricViewsAndQr(String views, String qr);

  /// Metric label.
  ///
  /// In en, this message translates to:
  /// **'Free-to-paid conversions'**
  String get metricConversion;

  /// Metric label.
  ///
  /// In en, this message translates to:
  /// **'Subscription renewals (renewal rate)'**
  String get metricRenewal;

  /// Metric label.
  ///
  /// In en, this message translates to:
  /// **'Churn (deactivated or deleted)'**
  String get metricChurn;

  /// Metric label.
  ///
  /// In en, this message translates to:
  /// **'Average items per restaurant'**
  String get metricAvgItems;

  /// Metric label.
  ///
  /// In en, this message translates to:
  /// **'Support requests per restaurant'**
  String get metricSupport;

  /// Metric value: not measured in the app.
  ///
  /// In en, this message translates to:
  /// **'Tracked in the support inbox'**
  String get metricSupportOutside;

  /// Button on the restaurant's subscription card and the dialog's submit (FR-081).
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get changePlan;

  /// Change-plan dialog title.
  ///
  /// In en, this message translates to:
  /// **'Change the plan for {name}'**
  String changePlanTitle(String name);

  /// Change-plan dialog: the restaurant's plan now.
  ///
  /// In en, this message translates to:
  /// **'Current plan: {plan}'**
  String changePlanCurrent(String plan);

  /// Change-plan dialog: plan picker label.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get changePlanNew;

  /// Change-plan dialog: no plan to choose.
  ///
  /// In en, this message translates to:
  /// **'There is no other active plan to move to.'**
  String get changePlanNoOther;

  /// Change-plan dialog: moving to a paid plan.
  ///
  /// In en, this message translates to:
  /// **'No payment is recorded. Use this for trials, complimentary upgrades and corrections. After a payment, use Record payment instead.'**
  String get changePlanPaidNote;

  /// Change-plan dialog: moving to a free plan.
  ///
  /// In en, this message translates to:
  /// **'Content over this plan\'s limits is hidden and the menu is republished.'**
  String get changePlanFreeNote;

  /// Change-plan dialog: bad dates.
  ///
  /// In en, this message translates to:
  /// **'The plan must end after it starts and after today.'**
  String get changePlanEndInvalid;
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
