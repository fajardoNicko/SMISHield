import 'package:flutter/foundation.dart';

import 'json_store.dart';
import 'password_hasher.dart';

/// A local account. It exists only on this phone; there is no server.
class Account {
  const Account({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final DateTime createdAt;
}

enum AuthError {
  nameRequired,
  invalidEmail,
  weakPassword,
  emailTaken,
  wrongCredentials,
  wrongRecoveryCode,
}

class AuthException implements Exception {
  const AuthException(this.error);

  final AuthError error;

  @override
  String toString() => 'AuthException(${error.name})';
}

/// The result of signing up: the new account and its one-time recovery code.
class SignUpResult {
  const SignUpResult(this.account, this.recoveryCode);

  final Account account;
  final String recoveryCode;
}

const int minPasswordLength = 8;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String normalizeEmail(String email) => email.trim().toLowerCase();

/// Runs [callback] off the UI thread; [compute] in the app.
typedef BackgroundRunner = Future<R> Function<M, R>(
  ComputeCallback<M, R> callback,
  M message,
);

/// Runs [callback] directly, for tests.
Future<R> runInline<M, R>(ComputeCallback<M, R> callback, M message) async =>
    await callback(message);

/// Sign-up, log-in and password reset for accounts stored on the device.
/// Passwords and recovery codes are kept only as salted PBKDF2 hashes.
class AccountRepository {
  AccountRepository(
    this.store, {
    this.iterations = defaultIterations,
    BackgroundRunner? runner,
  }) : _run = runner ?? compute;

  static const String _doc = 'accounts';

  final JsonStore store;
  final int iterations;
  final BackgroundRunner _run;

  Future<List<Map<String, dynamic>>> _records() async {
    final data = await store.read(_doc);
    return [
      for (final r in (data?['accounts'] as List?) ?? const [])
        Map<String, dynamic>.from(r as Map),
    ];
  }

  Future<void> _save(List<Map<String, dynamic>> records) =>
      store.write(_doc, {'version': 1, 'accounts': records});

  static Account _account(Map<String, dynamic> r) => Account(
    id: r['id'] as String,
    fullName: r['fullName'] as String,
    email: r['email'] as String,
    createdAt: DateTime.parse(r['createdAt'] as String),
  );

  Future<Account?> byId(String id) async {
    for (final r in await _records()) {
      if (r['id'] == id) return _account(r);
    }
    return null;
  }

  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final name = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final mail = normalizeEmail(email);
    if (name.isEmpty) throw const AuthException(AuthError.nameRequired);
    if (!_emailPattern.hasMatch(mail)) {
      throw const AuthException(AuthError.invalidEmail);
    }
    if (password.length < minPasswordLength) {
      throw const AuthException(AuthError.weakPassword);
    }
    final records = await _records();
    if (records.any((r) => r['email'] == mail)) {
      throw const AuthException(AuthError.emailTaken);
    }

    final code = newRecoveryCode();
    final hashes = await _run(_hashBoth, [
      password,
      normalizeRecoveryCode(code),
      iterations,
    ]);
    final now = DateTime.now();
    final record = {
      'id': '${now.microsecondsSinceEpoch}',
      'fullName': name,
      'email': mail,
      'createdAt': now.toIso8601String(),
      'password': hashes[0],
      'recovery': hashes[1],
    };
    await _save([...records, record]);
    return SignUpResult(_account(record), code);
  }

  Future<Account> logIn(String email, String password) async {
    final mail = normalizeEmail(email);
    final record = (await _records()).where((r) => r['email'] == mail);
    if (record.isEmpty) {
      throw const AuthException(AuthError.wrongCredentials);
    }
    final ok = await _run(_verify, [
      password,
      record.first['password'] as Map<String, dynamic>,
    ]);
    if (!ok) throw const AuthException(AuthError.wrongCredentials);
    return _account(record.first);
  }

  /// Sets a new password when the recovery code matches; issues a new code.
  Future<String> resetPassword({
    required String email,
    required String recoveryCode,
    required String newPassword,
  }) async {
    final mail = normalizeEmail(email);
    final records = await _records();
    final index = records.indexWhere((r) => r['email'] == mail);
    if (index < 0) throw const AuthException(AuthError.wrongRecoveryCode);
    final ok = await _run(_verify, [
      normalizeRecoveryCode(recoveryCode),
      records[index]['recovery'] as Map<String, dynamic>,
    ]);
    if (!ok) throw const AuthException(AuthError.wrongRecoveryCode);
    if (newPassword.length < minPasswordLength) {
      throw const AuthException(AuthError.weakPassword);
    }
    final code = newRecoveryCode();
    final hashes = await _run(_hashBoth, [
      newPassword,
      normalizeRecoveryCode(code),
      iterations,
    ]);
    records[index] = {
      ...records[index],
      'password': hashes[0],
      'recovery': hashes[1],
    };
    await _save(records);
    return code;
  }
}

// Hashing runs on a background isolate so the screen does not freeze.
List<Map<String, dynamic>> _hashBoth(List<Object> args) {
  final iterations = args[2] as int;
  return [
    hashSecret(args[0] as String, iterations: iterations).toJson(),
    hashSecret(args[1] as String, iterations: iterations).toJson(),
  ];
}

bool _verify(List<Object> args) => verifySecret(
  args[0] as String,
  PasswordHash.fromJson(args[1] as Map<String, dynamic>),
);
