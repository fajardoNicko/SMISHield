import 'package:flutter_test/flutter_test.dart';
import 'package:smishield/ml/preprocessor.dart';

void main() {
  test('lowercases, strips punctuation and splits Taglish words', () {
    expect(tokenize('I-CLICK mo na, Bes!!! Salamat po.'), [
      'i',
      'click',
      'mo',
      'na',
      'bes',
      'salamat',
      'po',
    ]);
  });

  test('keeps the domain words of a link and drops its path', () {
    expect(tokenize('Login: https://bpi-secure-login.com/verify?id=9'), [
      'login',
      urlToken,
      'bpi',
      'secure',
      'login',
      'com',
    ]);
  });

  test('marks shortened links', () {
    expect(tokenize('bit.ly/3xYz'), [urlToken, shortUrlToken]);
  });

  test('replaces phone numbers, peso amounts and other numbers', () {
    expect(tokenize('Send ₱1,500 to 0917 123 4567 within 24 hrs'), [
      'send',
      moneyToken,
      'to',
      phoneToken,
      'within',
      numberToken,
      'hrs',
    ]);
  });

  test('maps redaction placeholders to the same markers as real details', () {
    expect(
      tokenize('Text [PHONE] or [EMAIL], [NAME] / <NAME> acct [ACCOUNT]'),
      [
        'text',
        phoneToken,
        'or',
        emailToken,
        nameToken,
        nameToken,
        'acct',
        numberToken,
      ],
    );
    expect(tokenize('Call 09171234567'), tokenize('Call [PHONE]'));
  });

  test('undoes disguised dots and knows smishing domain endings', () {
    expect(tokenize('Visit ltoviolation(.)com'), [
      'visit',
      urlToken,
      'ltoviolation',
      'com',
    ]);
    expect(tokenize('come.to/OnlineBDOPh'), [urlToken, 'come', 'to']);
    expect(tokenize('claim at kqlx.uk'), [
      'claim',
      'at',
      urlToken,
      'kqlx',
      'uk',
    ]);
  });

  test('does not treat words joined by a period as a link', () {
    expect(tokenize('salamat.at ingat'), ['salamat', 'at', 'ingat']);
  });

  test('keeps ñ, removes accents and shortens stretched letters', () {
    expect(tokenize('Niño, ÉXITO, grabeeeee'), ['niño', 'exito', 'grabee']);
  });

  test('handles empty and symbol-only input', () {
    expect(tokenize(''), isEmpty);
    expect(tokenize('!!! ???'), isEmpty);
  });

  test('linkHost strips scheme, www, port and path', () {
    expect(linkHost('HTTPS://www.GCash.com:443/x'), 'gcash.com');
    expect(linkHost('gcash.com.'), 'gcash.com');
  });
}
