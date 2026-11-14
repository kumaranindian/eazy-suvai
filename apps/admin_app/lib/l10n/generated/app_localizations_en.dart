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
}
