// Renders every screen to a PNG with the real fonts and the bundled model,
// for previews and the manuscript's figures. Not part of the normal test run.
//
//   cd app
//   flutter test --update-goldens screenshots/screens_test.dart
//
// The images are written to app/screenshots/shots/ (not committed).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smishield/app/app_controller.dart';
import 'package:smishield/data/accounts.dart';
import 'package:smishield/data/history.dart';
import 'package:smishield/data/settings.dart';
import 'package:smishield/main.dart';
import 'package:smishield/ml/explanations.dart';
import 'package:smishield/ml/risk_label.dart';
import 'package:smishield/ml/smishield_analyzer.dart';
import 'package:smishield/ml/smishield_model.dart';
import 'package:smishield/ui/screens/result_screen.dart';

import '../test/helpers/memory_store.dart';

const highRisk =
    '[BDO-ALERT] Your account is on hold please verify here: www.onlinebdo-banking.online '
    'if your registered number is still active.';
const suspicious =
    'Congrats! Nanalo ka ng P10,000 sa aming raffle. I-claim na sa bit.ly/claim-prize bago mag 5PM';
const safe =
    'Your delivery from Lazada has been shipped. Track your order here: https://lazada.com.ph/track/123456';

Future<void> loadFonts() async {
  final poppins = FontLoader('Poppins');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Poppins-$weight.ttf').readAsBytesSync();
    poppins.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await poppins.load();
  final root = Platform.environment['FLUTTER_ROOT']!;
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

void main() {
  final model = SmishieldModel.fromJsonString(
    File('assets/model/smishield_model.json').readAsStringSync(),
  );

  Future<AppController> controller({
    bool loggedIn = true,
    bool dark = true,
    AppLanguage? language,
  }) async {
    final store = MemoryStore();
    final app = AppController(
      accounts: AccountRepository(store, iterations: 10, runner: runInline),
      history: HistoryRepository(store),
      settingsRepository: SettingsRepository(store),
      analyzer: SmishieldAnalyzer(model),
    );
    await app.load();
    await app.setDarkMode(dark);
    if (language != null) await app.setLanguage(language);
    if (loggedIn) {
      final signUp = await app.signUp(
        fullName: 'Juan Dela Cruz',
        email: 'juan@example.com',
        password: '12345678',
      );
      await app.startSession(signUp.account);
      for (final m in [safe, suspicious, highRisk]) {
        await app.analyze(m);
      }
    }
    return app;
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('shots/$name.png'),
    );
  }

  Future<void> setUpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await loadFonts();
  }

  testWidgets('log in and sign up', (tester) async {
    await setUpView(tester);
    await tester.pumpWidget(
      SmishieldApp(controller: await controller(loggedIn: false)),
    );
    await shoot(tester, '01_login');
    await tester.tap(find.text('Sign up'));
    await shoot(tester, '02_signup');
  });

  testWidgets('home, results, tabs', (tester) async {
    await setUpView(tester);
    final app = await controller();
    await tester.pumpWidget(SmishieldApp(controller: app));
    await shoot(tester, '03_home');
    await tester.enterText(find.byType(TextField), highRisk);
    FocusManager.instance.primaryFocus?.unfocus();
    await shoot(tester, '04_home_filled');

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    for (final (name, message, label) in [
      ('05_result_high_risk', highRisk, RiskLabel.highRisk),
      ('06_result_suspicious', suspicious, RiskLabel.suspicious),
      ('07_result_safe', safe, RiskLabel.safe),
    ]) {
      final result = await app.analyze(message, save: false);
      expect(result.label, label, reason: message);
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => ResultScreen(result: result)),
      );
      await shoot(tester, name);
      navigator.pop();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('History'));
    await shoot(tester, '08_history');
    await tester.tap(find.text('Tips'));
    await shoot(tester, '09_tips');
    await tester.tap(find.text('Profile'));
    await shoot(tester, '10_profile');
  });

  testWidgets('menu', (tester) async {
    await setUpView(tester);
    final app = await controller();
    await tester.pumpWidget(SmishieldApp(controller: app));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await shoot(tester, '11_menu');
    await tester.tap(find.text('About SMISHield'));
    await shoot(tester, '12_menu_about');
    await tester.tap(find.text('About SMISHield'));
    await tester.tap(find.text('Language (English)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filipino'));
    await shoot(tester, '13_menu_filipino');
    await tester.tap(find.text('Patakaran sa Pagkapribado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tingnan ang Patakaran'));
    await shoot(tester, '14_privacy_filipino');
  });

  testWidgets('light mode', (tester) async {
    await setUpView(tester);
    final app = await controller(dark: false);
    await tester.pumpWidget(SmishieldApp(controller: app));
    await shoot(tester, '15_home_light');
    await tester.tap(find.byTooltip('Menu'));
    await shoot(tester, '16_menu_light');
  });
}
