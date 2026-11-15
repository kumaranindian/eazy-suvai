import 'package:flutter/foundation.dart';

/// Where image errors go besides the console. The owner app sets this to
/// Crashlytics (non-fatal) on Android and iOS; tests set it to capture.
typedef MediaErrorSink =
    void Function(Object error, StackTrace stack, String context);

/// Logs an image error instead of swallowing it: always to the console
/// (the browser console on the web, logcat or the Xcode console on a
/// device), and to [mediaErrorSink] when one is set.
abstract final class MediaErrorLog {
  static MediaErrorSink? sink;

  static void record(Object error, StackTrace stack, String context) {
    debugPrint('[media] $context: $error (${error.runtimeType})\n$stack');
    try {
      sink?.call(error, stack, context);
    } on Object catch (e) {
      debugPrint('[media] error sink failed: $e');
    }
  }
}
