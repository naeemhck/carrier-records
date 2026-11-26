import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = FontLoader('NotoSansArabic')
    ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
  await font.load();
  await (FontLoader(
    'NotoSansMath',
  )..addFont(rootBundle.load('assets/fonts/NotoSansMath-Regular.ttf'))).load();
  await (FontLoader('NotoSans')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
      .load();
  // The Latin and figure faces are bundled with the app, so tests measure
  // the same glyph widths the office PC renders.
  await (FontLoader('FiraSans')
        ..addFont(rootBundle.load('assets/fonts/FiraSans-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/FiraSans-Medium.ttf'))
        ..addFont(rootBundle.load('assets/fonts/FiraSans-SemiBold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/FiraSans-Bold.ttf')))
      .load();
  await (FontLoader('FiraMono')
        ..addFont(rootBundle.load('assets/fonts/FiraMono-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/FiraMono-Bold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await testMain();
}
