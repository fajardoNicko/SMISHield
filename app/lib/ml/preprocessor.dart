/// Text preprocessing, identical to ml/smishield_ml/preprocess.py.
///
/// The model only gives correct results if the app cleans a message exactly
/// the way the training script did, so every step below mirrors the Python
/// module (see its docstring for what each step does). If you change either
/// file, change both and bump [preprocessingVersion]; the parity test in
/// test/ml/model_parity_test.dart fails when they drift apart.
library;

const int preprocessingVersion = 1;

const String urlToken = 'tokurl';
const String shortUrlToken = 'tokshorturl';
const String emailToken = 'tokemail';
const String phoneToken = 'tokphone';
const String moneyToken = 'tokmoney';
const String numberToken = 'toknum';

const Set<String> markerTokens = {
  urlToken,
  shortUrlToken,
  emailToken,
  phoneToken,
  moneyToken,
  numberToken,
};

const List<String> shortenerDomains = [
  'bit.ly',
  'bitly.com',
  'bit.do',
  'tinyurl.com',
  'tiny.cc',
  't.co',
  'goo.gl',
  'ow.ly',
  'is.gd',
  'v.gd',
  'buff.ly',
  'cutt.ly',
  'rb.gy',
  'shorturl.at',
  'shorturl.asia',
  's.id',
  'rebrand.ly',
  't.ly',
  'lnkd.in',
  'u.to',
  'qr.ae',
  'surl.li',
  'short.gy',
  'tr.im',
  'x.co',
  'bl.ink',
  'clck.ru',
  'shrtco.de',
];

/// Domain endings recognised in links written without "http://" or "www.".
const List<String> linkTlds = [
  'com',
  'net',
  'org',
  'ph',
  'info',
  'biz',
  'xyz',
  'top',
  'site',
  'online',
  'link',
  'live',
  'icu',
  'buzz',
  'click',
  'club',
  'vip',
  'shop',
  'store',
  'cc',
  'tk',
  'ml',
  'ga',
  'cf',
  'gq',
  'sbs',
  'cyou',
  'lol',
  'pw',
  'ws',
  'io',
  'app',
  'ly',
  'gl',
  'gd',
  'co',
  'me',
  'asia',
  'cloud',
  'mobi',
  'ru',
  'cn',
];

String _alternation(Iterable<String> words) {
  // Longest first so the order is deterministic and identical in Python.
  final ordered = words.toList()
    ..sort((a, b) {
      final byLength = b.length.compareTo(a.length);
      return byLength != 0 ? byLength : a.compareTo(b);
    });
  return ordered.map(RegExp.escape).join('|');
}

final RegExp _whitespace = RegExp('[\t\n\r\f\v \u0085   -​    　﻿]+');

const String _accented = 'áàâäãéèêëíìîïóòôöõúùûü';
const String _unaccented = 'aaaaaeeeeiiiiooooouuuu';
final RegExp _accent = RegExp('[$_accented]');

final RegExp emailPattern = RegExp(
  r'[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+',
);

/// Matches links in lowercased text. Use [linkPatternAnyCase] on raw text.
final RegExp linkPattern = RegExp(_linkSource);
final RegExp linkPatternAnyCase = RegExp(_linkSource, caseSensitive: false);

final String _linkSource = [
  r'(?:https?://|www\.)[^ ]+',
  r'(?<![a-z0-9.@-])(?:' + _alternation(shortenerDomains) + r')(?:/[^ ]*)?',
  r'(?<![a-z0-9.@-])(?:[a-z0-9-]+\.)+(?:' +
      _alternation(linkTlds) +
      r')(?![a-z0-9-])(?:[/?#][^ ]*)?',
  r'(?<![0-9.])[0-9]{1,3}(?:\.[0-9]{1,3}){3}(?![0-9.])(?::[0-9]+)?(?:/[^ ]*)?',
].join('|');

final RegExp phonePattern = RegExp(
  r'(?<![0-9])(?:\+?63[ -]?|0)9[0-9]{2}[ -]?[0-9]{3}[ -]?[0-9]{4}(?![0-9])',
);

final RegExp moneyPattern = RegExp(
  r'(?:₱|(?<![a-z])php|(?<![a-z])p)[ ]?[0-9][0-9,]*(?:\.[0-9]+)?(?:[ ]?k(?![a-z]))?'
  r'|(?<![a-z0-9])[0-9][0-9,]*(?:\.[0-9]+)?[ ]?(?:k|pesos|peso|piso|php)(?![a-z])',
);

final RegExp _number = RegExp(r'[0-9]+');
final RegExp _apostrophe = RegExp("['’‘`]");
final RegExp _elongation = RegExp(r'([a-z])\1{2,}');
final RegExp _nonLetter = RegExp('[^a-zñ]+');

final RegExp _scheme = RegExp(r'^[a-z][a-z0-9+.-]*://');
final RegExp _hostEnd = RegExp(r'[/?#:]');
final RegExp _edgeDots = RegExp(r'^\.+|\.+$');
final RegExp _hostSplit = RegExp(r'[^a-z0-9]+');

/// Returns the lowercase host of a matched link, without "www.".
String linkHost(String url) {
  var host = url.toLowerCase().replaceFirst(_scheme, '');
  final end = host.indexOf(_hostEnd);
  if (end >= 0) host = host.substring(0, end);
  host = host.replaceAll(_edgeDots, '');
  if (host.startsWith('www.')) host = host.substring(4);
  return host;
}

String _replaceLink(String url) {
  final host = linkHost(url);
  if (shortenerDomains.contains(host)) return ' $urlToken $shortUrlToken ';
  final words = host.split(_hostSplit).where((part) => part.isNotEmpty);
  return ' $urlToken ${words.join(' ')} ';
}

String _stripAccents(String text) => text.replaceAllMapped(
  _accent,
  (m) => _unaccented[_accented.indexOf(m[0]!)],
);

/// Returns the cleaned message as one space-separated string of tokens.
String normalize(String text) => tokenize(text).join(' ');

/// Splits a raw SMS message into the tokens the model was trained on.
List<String> tokenize(String text) {
  var t = text.replaceAll(_whitespace, ' ');
  t = _stripAccents(t.toLowerCase());
  t = t.replaceAll(emailPattern, ' $emailToken ');
  t = t.replaceAllMapped(linkPattern, (m) => _replaceLink(m[0]!));
  t = t.replaceAll(phonePattern, ' $phoneToken ');
  t = t.replaceAll(moneyPattern, ' $moneyToken ');
  t = t.replaceAll(_number, ' $numberToken ');
  t = t.replaceAll(_apostrophe, '');
  t = t.replaceAllMapped(_elongation, (m) => '${m[1]}${m[1]}');
  t = t.replaceAll(_nonLetter, ' ');
  return t.split(' ').where((token) => token.isNotEmpty).toList();
}
