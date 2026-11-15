import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web: a sandboxed `<iframe srcdoc>` (no scripts; links may open new
/// tabs). Nothing is fetched from a URL, so the owner's session is not
/// involved and nothing is cached.
Widget buildPlatformMenuHtmlView(String html, String label) => Semantics(
  label: label,
  child: HtmlElementView.fromTagName(
    key: ValueKey(html.hashCode),
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      frame.title = label;
      frame.sandbox.add('allow-popups');
      frame.sandbox.add('allow-popups-to-escape-sandbox');
      frame.style.border = '0';
      frame.style.width = '100%';
      frame.style.height = '100%';
      frame.srcdoc = html.toJS;
    },
  ),
);
