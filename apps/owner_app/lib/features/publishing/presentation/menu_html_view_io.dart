import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Android and iOS: a web view with the HTML loaded directly. JavaScript is
/// off (the preview page needs none).
Widget buildPlatformMenuHtmlView(String html, String label) =>
    _MenuWebView(key: ValueKey(html.hashCode), html: html, label: label);

class _MenuWebView extends StatefulWidget {
  const _MenuWebView({super.key, required this.html, required this.label});

  final String html;
  final String label;

  @override
  State<_MenuWebView> createState() => _MenuWebViewState();
}

class _MenuWebViewState extends State<_MenuWebView> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.disabled)
    ..loadHtmlString(widget.html);

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: WebViewWidget(controller: _controller),
  );
}
