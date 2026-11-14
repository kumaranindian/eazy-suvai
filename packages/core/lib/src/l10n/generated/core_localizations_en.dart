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
}
