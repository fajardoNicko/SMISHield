import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smishield/data/accounts.dart';
import 'package:smishield/data/history.dart';
import 'package:smishield/data/json_store.dart';
import 'package:smishield/data/password_hasher.dart';
import 'package:smishield/data/settings.dart';
import 'package:smishield/ml/explanations.dart';
import 'package:smishield/ml/risk_label.dart';

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  late Directory dir;
  late JsonStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('smishield_test_');
    store = JsonStore(dir);
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  group('PBKDF2-HMAC-SHA256', () {
    // Expected values from Python's hashlib.pbkdf2_hmac.
    test('matches known outputs', () {
      expect(
        hex(pbkdf2Sha256(utf8.encode('password'), utf8.encode('salt'), 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        hex(pbkdf2Sha256(utf8.encode('password'), utf8.encode('salt'), 4096)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
      expect(
        hex(
          pbkdf2Sha256(
            utf8.encode('ñandú pass'),
            List.generate(16, (i) => i),
            1000,
          ),
        ),
        '1b42f3d203087a39688fb6302adf1c3da9a22a581985951d30a57bcf111a9b03',
      );
    });

    test('verifies only the right secret, with a fresh salt each time', () {
      final a = hashSecret('correct horse', iterations: 500);
      final b = hashSecret('correct horse', iterations: 500);
      expect(verifySecret('correct horse', a), isTrue);
      expect(verifySecret('correct hors', a), isFalse);
      expect(hex(a.salt), isNot(hex(b.salt)));
      expect(
        verifySecret('correct horse', PasswordHash.fromJson(a.toJson())),
        isTrue,
      );
    });

    test('recovery codes are readable and typed loosely', () {
      final code = newRecoveryCode();
      expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$')));
      expect(normalizeRecoveryCode(' k7qm 3xrp '), 'K7QM3XRP');
      expect(normalizeRecoveryCode('K7QM-3XRP'), 'K7QM3XRP');
    });
  });

  group('AccountRepository', () {
    late AccountRepository accounts;
    setUp(() => accounts = AccountRepository(store, iterations: 200));

    Future<AuthError> errorOf(Future<Object?> Function() action) async {
      try {
        await action();
      } on AuthException catch (e) {
        return e.error;
      }
      fail('expected an AuthException');
    }

    test('signs up, logs in, and stores no plain password', () async {
      final result = await accounts.signUp(
        fullName: '  Juan   Dela Cruz ',
        email: ' Juan@Example.com ',
        password: 'secret-pass',
      );
      expect(result.account.fullName, 'Juan Dela Cruz');
      expect(result.account.email, 'juan@example.com');

      final again = await accounts.logIn('JUAN@example.com', 'secret-pass');
      expect(again.id, result.account.id);
      expect((await accounts.byId(again.id))?.email, 'juan@example.com');

      final file = await File('${dir.path}/accounts.json').readAsString();
      expect(file, isNot(contains('secret-pass')));
      expect(file, isNot(contains(normalizeRecoveryCode(result.recoveryCode))));
    });

    test('validates sign-up details', () async {
      expect(
        await errorOf(
          () => accounts.signUp(
            fullName: ' ',
            email: 'a@b.co',
            password: '12345678',
          ),
        ),
        AuthError.nameRequired,
      );
      expect(
        await errorOf(
          () => accounts.signUp(
            fullName: 'A',
            email: 'not-an-email',
            password: '12345678',
          ),
        ),
        AuthError.invalidEmail,
      );
      expect(
        await errorOf(
          () => accounts.signUp(
            fullName: 'A',
            email: 'a@b.co',
            password: 'short',
          ),
        ),
        AuthError.weakPassword,
      );
      await accounts.signUp(
        fullName: 'A',
        email: 'a@b.co',
        password: '12345678',
      );
      expect(
        await errorOf(
          () => accounts.signUp(
            fullName: 'B',
            email: 'A@B.CO',
            password: '12345678',
          ),
        ),
        AuthError.emailTaken,
      );
    });

    test('rejects a wrong password or unknown email the same way', () async {
      await accounts.signUp(
        fullName: 'A',
        email: 'a@b.co',
        password: '12345678',
      );
      expect(
        await errorOf(() => accounts.logIn('a@b.co', '1234567x')),
        AuthError.wrongCredentials,
      );
      expect(
        await errorOf(() => accounts.logIn('x@b.co', '12345678')),
        AuthError.wrongCredentials,
      );
    });

    test(
      'resets the password with the recovery code, which then changes',
      () async {
        final signUp = await accounts.signUp(
          fullName: 'A',
          email: 'a@b.co',
          password: '12345678',
        );
        expect(
          await errorOf(
            () => accounts.resetPassword(
              email: 'a@b.co',
              recoveryCode: 'AAAA-AAAA',
              newPassword: 'newpass99',
            ),
          ),
          AuthError.wrongRecoveryCode,
        );
        final newCode = await accounts.resetPassword(
          email: 'a@b.co',
          recoveryCode: signUp.recoveryCode.toLowerCase().replaceAll('-', ' '),
          newPassword: 'newpass99',
        );
        expect(
          await errorOf(() => accounts.logIn('a@b.co', '12345678')),
          AuthError.wrongCredentials,
        );
        expect((await accounts.logIn('a@b.co', 'newpass99')).email, 'a@b.co');
        expect(
          await errorOf(
            () => accounts.resetPassword(
              email: 'a@b.co',
              recoveryCode: signUp.recoveryCode,
              newPassword: 'x' * 9,
            ),
          ),
          AuthError.wrongRecoveryCode,
        );
        expect(newCode, isNot(signUp.recoveryCode));
      },
    );
  });

  group('HistoryRepository', () {
    test('keeps each account\'s entries apart, newest first', () async {
      final history = HistoryRepository(store);
      await history.add(
        'u1',
        message: 'old',
        label: RiskLabel.safe,
        confidence: .9,
        analyzedAt: DateTime(2026, 1, 1),
      );
      await history.add(
        'u1',
        message: 'new',
        label: RiskLabel.highRisk,
        confidence: .8,
        analyzedAt: DateTime(2026, 2, 1),
      );
      await history.add(
        'u2',
        message: 'other',
        label: RiskLabel.suspicious,
        confidence: .7,
        analyzedAt: DateTime(2026, 3, 1),
      );

      final reopened = HistoryRepository(JsonStore(dir));
      final u1 = await reopened.list('u1');
      expect(u1.map((e) => e.message), ['new', 'old']);
      expect(u1.first.label, RiskLabel.highRisk);
      expect((await reopened.list('u2')).single.message, 'other');

      await reopened.remove('u1', u1.first.id);
      expect((await reopened.list('u1')).map((e) => e.message), ['old']);
      await reopened.clear('u1');
      expect(await reopened.list('u1'), isEmpty);
      expect(await reopened.list('u2'), hasLength(1));
    });
  });

  test('settings round-trip and default to dark mode in English', () async {
    final settings = SettingsRepository(store);
    final initial = await settings.load();
    expect(initial.darkMode, isTrue);
    expect(initial.language, AppLanguage.english);
    expect(initial.sessionAccountId, isNull);

    await settings.save(
      initial.copyWith(
        darkMode: false,
        language: AppLanguage.filipino,
        sessionAccountId: () => 'u1',
      ),
    );
    final loaded = await SettingsRepository(JsonStore(dir)).load();
    expect(loaded.darkMode, isFalse);
    expect(loaded.language, AppLanguage.filipino);
    expect(loaded.sessionAccountId, 'u1');
    expect(
      loaded.copyWith(sessionAccountId: () => null).sessionAccountId,
      isNull,
    );
  });
}
