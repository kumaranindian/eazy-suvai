import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in a MaterialApp with the app theme and core localizations.
Widget testApp(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  localizationsDelegates: const [
    CoreLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: CoreLocalizations.supportedLocales,
  home: child,
);

/// Sets the logical window width (height 900) for this test.
Future<void> setSurfaceWidth(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
}
