import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smishield/app/app_controller.dart';
import 'package:smishield/data/accounts.dart';
import 'package:smishield/data/history.dart';
import 'package:smishield/data/settings.dart';
import 'package:smishield/main.dart';
import 'package:smishield/ml/smishield_analyzer.dart';
import 'package:smishield/ui/screens/result_screen.dart';

import 'helpers/memory_store.dart';
import 'helpers/tiny_model.dart';

Future<AppController> newController(MemoryStore store) async {
  final controller = AppController(
    accounts: AccountRepository(store, iterations: 50, runner: runInline),
    history: HistoryRepository(store),
    settingsRepository: SettingsRepository(store),
    analyzer: SmishieldAnalyzer(tinyModel()),
  );
  await controller.load();
  return controller;
}

void main() {
  testWidgets(
    'sign up, analyze a message, see it in history and profile, log out',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      final store = MemoryStore();
      final controller = await newController(store);
      await tester.pumpWidget(SmishieldApp(controller: controller));
      expect(find.text('Are you a new user?'), findsOneWidget);

      // Sign up; the recovery code is shown before the account opens.
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Juan Dela Cruz');
      await tester.enterText(fields.at(1), 'juan@example.com');
      await tester.enterText(fields.at(2), 'secret-pass');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign up'));
      await tester.pumpAndSettle();
      expect(find.text('Save your recovery code'), findsOneWidget);
      await tester.tap(find.text('I saved it'));
      await tester.pumpAndSettle();

      // Home: analyze a message.
      expect(find.text('Paste your message here'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'URGENT verify your OTP at http://bpi-secure-login.xyz',
      );
      await tester.tap(find.text('Analyze Message'));
      await tester.pump();
      expect(find.text('Analyzing message...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Analysis Result'), findsOneWidget);
      expect(find.text('HIGH RISK'), findsOneWidget);
      expect(find.text('Why is this high risk?'), findsOneWidget);
      expect(find.text('Requests sensitive information'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Check another message'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ResultScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Check another message'));
      await tester.pumpAndSettle();
      expect(find.text('Paste your message here'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      // History and profile.
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.textContaining('URGENT verify your OTP'), findsOneWidget);
      expect(
        find.text('History is saved on your device only and is never shared'),
        findsOneWidget,
      );

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('juan@example.com'), findsOneWidget);
      expect(controller.entries, hasLength(1));

      // Log out and back in: the history belongs to the account.
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();
      expect(find.text('Are you a new user?'), findsOneWidget);
      expect(controller.entries, isEmpty);

      final loginFields = find.byType(TextField);
      await tester.enterText(loginFields.at(0), 'JUAN@example.com');
      await tester.enterText(loginFields.at(1), 'wrong-pass');
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect email or password.'), findsOneWidget);

      await tester.enterText(loginFields.at(1), 'secret-pass');
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.text('Paste your message here'), findsOneWidget);
      expect(controller.entries, hasLength(1));

      // The session survives a restart.
      final restarted = await newController(store);
      expect(restarted.account?.email, 'juan@example.com');
      expect(restarted.entries, hasLength(1));
    },
  );

  testWidgets('the menu switches language and dark mode, and clears history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final store = MemoryStore();
    final controller = await newController(store);
    final signUp = await controller.signUp(
      fullName: 'Ana',
      email: 'ana@example.com',
      password: '12345678',
    );
    await controller.startSession(signUp.account);
    await controller.analyze('Salamat sa promo');
    await tester.pumpWidget(SmishieldApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language (English)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filipino'));
    await tester.pumpAndSettle();
    expect(find.text('Wika (Filipino)'), findsOneWidget);
    expect(find.text('Burahin ang History'), findsWidgets);
    expect(find.text('I-paste ang iyong mensahe dito'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(controller.darkMode, isFalse);

    await tester.tap(find.text('Burahin ang History').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Burahin ang History'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Burahin'));
    await tester.pumpAndSettle();
    expect(controller.entries, isEmpty);
    expect(find.text('Nabura na ang history'), findsOneWidget);

    final restarted = await newController(store);
    expect(restarted.darkMode, isFalse);
    expect(restarted.strings.isFilipino, isTrue);
  });
}
