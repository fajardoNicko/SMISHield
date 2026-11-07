import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A salted PBKDF2-HMAC-SHA256 hash. Only this is stored, never the password.
class PasswordHash {
  const PasswordHash({
    required this.salt,
    required this.iterations,
    required this.hash,
  });

  factory PasswordHash.fromJson(Map<String, dynamic> json) => PasswordHash(
    salt: base64Decode(json['salt'] as String),
    iterations: json['iterations'] as int,
    hash: base64Decode(json['hash'] as String),
  );

  final List<int> salt;
  final int iterations;
  final List<int> hash;

  Map<String, dynamic> toJson() => {
    'salt': base64Encode(salt),
    'iterations': iterations,
    'hash': base64Encode(hash),
  };
}

/// Iterations for new hashes. High enough to slow down guessing on a stolen
/// file, low enough to take well under a second on a phone.
const int defaultIterations = 60000;

/// PBKDF2 with HMAC-SHA256 (RFC 8018), producing [length] bytes.
Uint8List pbkdf2Sha256(
  List<int> password,
  List<int> salt,
  int iterations, {
  int length = 32,
}) {
  final hmac = Hmac(sha256, password);
  final out = Uint8List(length);
  var offset = 0;
  for (var block = 1; offset < length; block++) {
    var u = hmac.convert([
      ...salt,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ]).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    final take = min(t.length, length - offset);
    out.setRange(offset, offset + take, t);
    offset += take;
  }
  return out;
}

PasswordHash hashSecret(
  String secret, {
  List<int>? salt,
  int iterations = defaultIterations,
}) {
  final useSalt = salt ?? _randomBytes(16);
  return PasswordHash(
    salt: useSalt,
    iterations: iterations,
    hash: pbkdf2Sha256(utf8.encode(secret), useSalt, iterations),
  );
}

bool verifySecret(String secret, PasswordHash stored) {
  final candidate = pbkdf2Sha256(
    utf8.encode(secret),
    stored.salt,
    stored.iterations,
    length: stored.hash.length,
  );
  // Compare every byte so the time taken does not reveal where they differ.
  var diff = candidate.length ^ stored.hash.length;
  for (var i = 0; i < candidate.length && i < stored.hash.length; i++) {
    diff |= candidate[i] ^ stored.hash[i];
  }
  return diff == 0;
}

final Random _secureRandom = Random.secure();

List<int> _randomBytes(int n) =>
    List<int>.generate(n, (_) => _secureRandom.nextInt(256));

/// Letters and digits that cannot be confused when read back (no 0/O, 1/I).
const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// A recovery code such as `K7QM-3XRP`, shown once at sign-up.
String newRecoveryCode() {
  final chars = List.generate(
    8,
    (_) => _codeAlphabet[_secureRandom.nextInt(_codeAlphabet.length)],
  );
  return '${chars.take(4).join()}-${chars.skip(4).join()}';
}

/// `k7qm 3xrp` -> `K7QM3XRP`, so the code can be typed loosely.
String normalizeRecoveryCode(String code) =>
    code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
