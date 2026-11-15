import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'menu_html_view_io.dart'
    if (dart.library.js_interop) 'menu_html_view_web.dart';

/// Shows a rendered menu page (the draft preview, M06): an `<iframe
/// srcdoc>` on web and a web view with JavaScript off on Android and iOS.
/// [label] is the accessible name of the frame.
typedef MenuHtmlViewBuilder = Widget Function(String html, String label);

/// Overridden in widget tests, which cannot host platform views.
final menuHtmlViewBuilderProvider = Provider<MenuHtmlViewBuilder>(
  (ref) => buildPlatformMenuHtmlView,
);
