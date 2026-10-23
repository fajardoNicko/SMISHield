/// Rule-based detection of smishing warning signs, used to explain a result.
///
/// The label itself always comes from the Naive Bayes model. These rules only
/// point out *why* a message may be risky (links, requests for codes or
/// passwords, urgency, prizes, ...) so the app can list and highlight them.
library;

import 'preprocessor.dart';

enum IndicatorType {
  suspiciousLink,
  shortenedLink,
  link,
  sensitiveInfoRequest,
  impersonation,
  paymentRequest,
  threat,
  urgency,
  prizeClaim,
  financialOffer,
  jobOffer,
  gambling,
  offPlatformContact,
}

enum Severity { low, medium, high }

/// Why a link was considered suspicious.
enum LinkConcern { ipAddress, imitatesBrand, unusualEnding, baitWords }

const Map<IndicatorType, Severity> indicatorSeverity = {
  IndicatorType.suspiciousLink: Severity.high,
  IndicatorType.sensitiveInfoRequest: Severity.high,
  IndicatorType.impersonation: Severity.high,
  IndicatorType.paymentRequest: Severity.medium,
  IndicatorType.shortenedLink: Severity.medium,
  IndicatorType.threat: Severity.medium,
  IndicatorType.urgency: Severity.medium,
  IndicatorType.prizeClaim: Severity.medium,
  IndicatorType.financialOffer: Severity.medium,
  IndicatorType.jobOffer: Severity.medium,
  IndicatorType.gambling: Severity.medium,
  IndicatorType.offPlatformContact: Severity.low,
  IndicatorType.link: Severity.low,
};

/// A character range in the original message ([start] inclusive, [end] exclusive).
class MessageSpan {
  const MessageSpan(this.start, this.end);

  final int start;
  final int end;

  bool overlaps(MessageSpan other) => start < other.end && other.start < end;

  @override
  bool operator ==(Object other) =>
      other is MessageSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '[$start, $end)';
}

class RiskIndicator {
  const RiskIndicator(
    this.type, {
    required this.spans,
    this.subject,
    this.linkConcerns = const {},
  });

  final IndicatorType type;

  /// Where the indicator was found, for highlighting.
  final List<MessageSpan> spans;

  /// The brand being imitated or the link's domain, when relevant.
  final String? subject;
  final Set<LinkConcern> linkConcerns;

  Severity get severity => indicatorSeverity[type]!;

  @override
  String toString() =>
      'RiskIndicator(${type.name}${subject == null ? '' : ', $subject'})';
}

class DetectionResult {
  const DetectionResult({
    required this.indicators,
    required this.hasSecurityReminder,
    required this.brands,
  });

  final List<RiskIndicator> indicators;

  /// The message warns *not* to share codes or passwords, as genuine OTP
  /// messages from banks and e-wallets do.
  final bool hasSecurityReminder;

  /// Companies or agencies the message mentions or whose name is in a link.
  final List<String> brands;

  bool has(IndicatorType type) => indicators.any((i) => i.type == type);

  RiskIndicator? find(IndicatorType type) {
    for (final indicator in indicators) {
      if (indicator.type == type) return indicator;
    }
    return null;
  }
}

/// A company or agency often imitated in Philippine smishing messages.
class Brand {
  const Brand(
    this.name,
    this.mention,
    this.hostKeywords,
    this.officialDomains, {
    this.caseSensitive = false,
  });

  final String name;

  /// Regular expression for the name in message text.
  final String mention;

  /// Words that, inside a link's domain, refer to this brand.
  final List<String> hostKeywords;
  final List<String> officialDomains;

  /// For names that are also everyday words (DITO means "here").
  final bool caseSensitive;
}

const List<Brand> brands = [
  Brand('BPI', r'\bbpi\b', ['bpi'], ['bpi.com.ph']),
  Brand('BDO', r'\bbdo\b', ['bdo'], ['bdo.com.ph']),
  Brand('Metrobank', r'\bmetrobank\b', ['metrobank'], ['metrobank.com.ph']),
  Brand(
    'Landbank',
    r'\bland ?bank\b|\blbp\b',
    ['landbank', 'lbp'],
    ['landbank.com'],
  ),
  Brand('PNB', r'\bpnb\b', ['pnb'], ['pnb.com.ph']),
  Brand('UnionBank', r'\bunion ?bank\b', ['unionbank'], ['unionbankph.com']),
  Brand(
    'Security Bank',
    r'\bsecurity ?bank\b',
    ['securitybank'],
    ['securitybank.com'],
  ),
  Brand('RCBC', r'\brcbc\b', ['rcbc'], ['rcbc.com']),
  Brand('China Bank', r'\bchina ?bank\b', ['chinabank'], ['chinabank.ph']),
  Brand('EastWest', r'\beast ?west\b', ['eastwest'], ['eastwestbanker.com']),
  Brand('PSBank', r'\bps ?bank\b', ['psbank'], ['psbank.com.ph']),
  Brand('GCash', r'\bg-?cash\b', ['gcash'], ['gcash.com']),
  Brand(
    'Maya',
    r'\b(?:pay)?maya\b',
    ['maya', 'paymaya'],
    ['maya.ph', 'paymaya.com'],
  ),
  Brand('Coins.ph', r'\bcoins\.?ph\b', ['coinsph'], ['coins.ph']),
  Brand(
    'Shopee',
    r'\bshopee(?: ?pay)?\b',
    ['shopee', 'shopeepay'],
    ['shopee.ph', 'shope.ee', 'shp.ee'],
  ),
  Brand('Lazada', r'\blazada\b', ['lazada'], ['lazada.com.ph']),
  Brand('Grab', r'\bgrab\b', ['grab'], ['grab.com']),
  Brand('LBC', r'\blbc\b', ['lbc'], ['lbcexpress.com']),
  Brand(
    'J&T Express',
    r'\bj ?& ?t\b|\bjnt\b',
    ['jnt', 'jtexpress'],
    ['jtexpress.ph'],
  ),
  Brand('Ninja Van', r'\bninja ?van\b', ['ninjavan'], ['ninjavan.co']),
  Brand(
    'Flash Express',
    r'\bflash express\b',
    ['flashexpress'],
    ['flashexpress.ph'],
  ),
  Brand(
    'PHLPost',
    r'\bph(?:l|il) ?post\b',
    ['phlpost', 'philpost'],
    ['phlpost.gov.ph'],
  ),
  Brand('DHL', r'\bdhl\b', ['dhl'], ['dhl.com']),
  Brand('SSS', r'\bsss\b', ['sss'], ['sss.gov.ph']),
  Brand('GSIS', r'\bgsis\b', ['gsis'], ['gsis.gov.ph']),
  Brand(
    'PhilHealth',
    r'\bphil ?health\b',
    ['philhealth'],
    ['philhealth.gov.ph'],
  ),
  Brand('Pag-IBIG', r'\bpag-?ibig\b', ['pagibig'], ['pagibigfund.gov.ph']),
  Brand('BIR', r'\bbir\b', ['bir'], ['bir.gov.ph']),
  Brand('LTO', r'\blto\b', ['lto'], ['lto.gov.ph']),
  Brand('DFA', r'\bdfa\b', ['dfa'], ['dfa.gov.ph']),
  Brand('DSWD', r'\bdswd\b', ['dswd'], ['dswd.gov.ph']),
  Brand('DTI', r'\bdti\b', ['dti'], ['dti.gov.ph']),
  Brand('PCSO', r'\bpcso\b', ['pcso'], ['pcso.gov.ph']),
  Brand('PAGCOR', r'\bpagcor\b', ['pagcor'], ['pagcor.ph']),
  Brand('PSA', r'\bpsa\b', ['psa'], ['psa.gov.ph']),
  Brand('NTC', r'\bntc\b', ['ntc'], ['ntc.gov.ph']),
  Brand('NBI', r'\bnbi\b', ['nbi'], ['nbi.gov.ph']),
  Brand(
    'Bureau of Customs',
    r'\bbureau of customs\b',
    ['customs'],
    ['customs.gov.ph'],
  ),
  Brand('Globe', r'\bglobe\b', ['globe'], ['globe.com.ph', 'glbe.co']),
  Brand('Smart', r'\bsmart\b', ['smart'], ['smart.com.ph', 'smrt.ph']),
  Brand('DITO', r'\bDITO\b', ['dito'], ['dito.ph'], caseSensitive: true),
  Brand('Meralco', r'\bmeralco\b', ['meralco'], ['meralco.com.ph']),
  Brand('Maynilad', r'\bmaynilad\b', ['maynilad'], ['mayniladwater.com.ph']),
  Brand('PLDT', r'\bpldt\b', ['pldt'], ['pldthome.com', 'pldt.com']),
  Brand('Converge', r'\bconverge\b', ['converge'], ['convergeict.com']),
  Brand('Netflix', r'\bnetflix\b', ['netflix'], ['netflix.com']),
  Brand('PayPal', r'\bpaypal\b', ['paypal'], ['paypal.com']),
  Brand(
    'Apple',
    r'\bapple id\b|\bicloud\b',
    ['apple', 'icloud'],
    ['apple.com', 'icloud.com'],
  ),
  Brand('Google', r'\bgoogle\b|\bgmail\b', ['google', 'gmail'], ['google.com']),
  Brand(
    'Facebook',
    r'\bfacebook\b|\bfb\b',
    ['facebook', 'fb'],
    ['facebook.com', 'fb.com'],
  ),
  Brand('TikTok', r'\btiktok\b', ['tiktok'], ['tiktok.com']),
];

RegExp _re(String source) => RegExp(source, caseSensitive: false);

final List<(Brand, RegExp)> _brandPatterns = [
  for (final b in brands)
    (b, RegExp(b.mention, caseSensitive: b.caseSensitive)),
];

const Set<String> _unusualEndings = {
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
  'bet',
  'win',
  'bid',
  'vin',
  'cfd',
  'rest',
  'bar',
  'lat',
  'mom',
  'monster',
  'quest',
  'golf',
  'vegas',
  'auction',
  'cx',
  'su',
};

const Set<String> _baitWords = {
  'secure',
  'security',
  'verify',
  'verification',
  'login',
  'signin',
  'update',
  'account',
  'claim',
  'reward',
  'rewards',
  'prize',
  'promo',
  'bonus',
  'free',
  'refund',
  'support',
  'help',
  'unlock',
  'unfreeze',
  'recover',
  'restore',
  'billing',
  'payment',
  'pay',
  'kyc',
  'release',
  'redeliver',
  'customs',
  'ayuda',
  'grant',
  'raffle',
  'cashback',
  'voucher',
  'renew',
  'cancel',
  'appeal',
  'alert',
  'transfer',
  'receive',
  'reactivate',
};

const String _trailingPunctuation = '.,!?;:)]}\'"';

final RegExp _ipHost = RegExp(r'^[0-9]{1,3}(?:\.[0-9]{1,3}){3}$');
final RegExp _hostParts = RegExp(r'[.-]+');

// Sentence or clause boundaries: punctuation followed by a space, or a newline.
final RegExp _clauseEnd = RegExp(r'[.!?;]+(?=\s|$)|\n+');

final RegExp _sensitiveTerm = _re(
  r"\b(?:otp|one[- ]?time[- ]?(?:pin|password|code)|m-?pin|pin code"
  r"|pin(?! ?(?:location|loc)\b)|passwords?|passcode|cvv|cvc"
  r"|card (?:number|no|details)|credit card (?:number|details)"
  r"|account (?:number|no|details|info|information)|bank (?:account|details|login)"
  r"|online banking login|log-?in details|banking app login|username|user ?id"
  r"|(?:valid|government|philhealth|sss|gsis|umid|national) id|id card|selfie"
  r"|(?:sss|gsis|philhealth|pag-?ibig|tin) (?:number|no)"
  r"|birthday|birth ?date|date of birth|full name|mother'?s maiden name|expiry date"
  r"|personal (?:info|information|details)"
  r"|(?:verification|security|authentication|auth|access|[0-9]-digit|6 digit) code"
  r"|code (?:na |you )(?:just )?(?:natanggap|received|pinadala|ipinadala|sent))\b",
);

final RegExp _requestVerb = _re(
  r"\b(?:send|enter|input|type|provide|share|give|reply|submit|confirm|verify"
  r"|update|log ?in|sign ?in|needed|need|required?|kailangan|i-?send|pakisend"
  r"|paki-?send|ipadala|ibigay|pakibigay|i-?type|ilagay|i-?reply|i-?confirm"
  r"|i-?verify|i-?update|i-?submit|i-?share|ipasa|sabihin|i-?text|mag-?log ?in"
  r"|gamit ang|gamitin ang|using|with your|with the|pagbibigay|entering"
  r"|confirming|logging in)\b",
);

final RegExp _protective = _re(
  r"\b(?:do not|don'?t|dont|never|huwag|wag|hindi)\b[^.!?\n]{0,40}?"
  r"\b(?:share|give|send|disclose|ask|reveal|ibigay|ibahagi|i-?share|ipaalam"
  r"|sabihin|ipakita|hihingi|hihingin|hinihingi|humingi)",
);

final RegExp _anyCode = _re(r'\bcode\b');

final RegExp _urgency = _re(
  r"\b(?:urgent(?:ly)?|immediately|right away|asap|as soon as possible|act now"
  r"|(?:click|tap|reply|claim|call|verify|update|log ?in|pay|register|apply"
  r"|join|text|order|shop|redeem) (?:it |here |na )?now|now na|today only"
  r"|ngayong araw lang|ngayon lang|ngayon din|ngayon na|ngayon mismo"
  r"|within (?:the day|today|[0-9]+ ?(?:hours?|hrs?|minutes?|mins?|days?))"
  r"|in [0-9]+ ?(?:hours?|hrs?|minutes?|mins?)"
  r"|sa loob ng [0-9]+ ?(?:oras|araw|minuto)|expires? (?:today|soon|tonight)"
  r"|will expire|mag-?e-?expire|ma-?e-?expire|bago mag-?expire|last chance"
  r"|final (?:notice|warning|reminder)|limited (?:time|slots?)|agad|agaran"
  r"|kaagad|bilisan|huling (?:araw|pagkakataon|abiso|paalala|babala)|emergency)\b",
);

final RegExp _threat = _re(
  r"\b(?:suspend(?:ed|ion)?|ma-?suspend|deactivat(?:e|ed|ion)|ma-?(?:de-?)?deactivate"
  r"|blocked|(?:ma|na)-?block|mablock|banned|locked|(?:ma|naka)-?lock|frozen|freeze"
  r"|terminat(?:e|ed|ion)|ma-?te-?terminate|disabled|restricted|(?:is|been) limited"
  r"|(?:will be|is|has been) (?:closed|deleted|cancell?ed)|permanently deleted"
  r"|isasara|ipapasara|puputulin|putulin|disconnect(?:ed|ion)?|mabubura|buburahin"
  r"|kakasuhan|kasuhan|demanda|legal action|warrant|arrest(?:ed)?|maaresto"
  r"|makulong|penalty|penalties|multa|(?:pay|a|the) fine|violation"
  r"|unauthori[sz]ed|suspicious (?:activity|login|transaction)|unusual activity"
  r"|kahina-?hinala(?:ng)?|hindi awtorisado(?:ng)?|compromised|hacked|na-?hack"
  r"|ipapahiya|irereport)\b",
);

final RegExp _prize = _re(
  r"\b(?:congrat(?:s|ulations)?|winners?|you (?:have )?won|won(?!['’]t)"
  r"|nanalo|panalo|manalo|napili ka|napiling|(?:have been |been )?selected"
  r"|lucky|swerte|suwerte|prizes?|premyo|raffle|jackpot|rewards?|gantimpala"
  r"|bonus|free|libre(?:ng)?|gifts?|regalo|i-?claim|claim|voucher|giveaway"
  r"|cashback|surprise gift)\b",
);

final RegExp _financialOffer = _re(
  r"\b(?:loans?|pautang|pa-?utang|lending|credit line|pre-?approved"
  r"|pre-?qualified|cash (?:assistance|aid|grant|gift)|ayuda|subsidy"
  r"|financial (?:aid|assistance)|refund|rebate|invest(?:ment|or|ing)?|crypto"
  r"|bitcoin|forex|trading|double your money|doble ang pera|guaranteed"
  r"|tubo|interest|walang interes|no collateral|walang collateral"
  r"|no requirements?|walang requirements?|paluwagan|grant)\b",
);

final RegExp _payVerb = _re(
  r"\b(?:pay|magbayad|bayaran|i-?settle|settle|send|magpadala|ipadala"
  r"|padalhan|padala|i-?transfer|transfer|deposit|mag-?deposit|i-?deposit"
  r"|cash ?in|bilhan|buy)\b",
);

final RegExp _payObject = _re(
  r"\b(?:fees?|bayad|payment|penalty|penalties|multa|tax|buwis|customs"
  r"|processing|release|redelivery|storage|registration|piyansa|bail"
  r"|google play|gift ?cards?|codes|gcash|maya|account (?:na ito|number)"
  r"|balance|bill)\b",
);

final RegExp _paymentDone = _re(
  r"\b(?:successful(?:ly)?|has been (?:paid|received|credited|posted)"
  r"|you have (?:paid|received)|thank you for (?:your )?payment"
  r"|nabayaran ko na|natanggap|ref(?:erence)?\.? ?(?:no|number|#))",
);

final RegExp _jobTerm = _re(
  r"\b(?:hiring|part[- ]?time|full[- ]?time|work from home|wfh|home[- ]?based"
  r"|online (?:job|work|trabaho|agents?|selling)|job (?:offer|opening|vacancy)"
  r"|trabaho|raket|tasks?|like and follow|like & follow|recruit(?:er|ing)?"
  r"|data encoder|franchise|business opportunity|extra income|passive income)\b",
);

final RegExp _payTerm = _re(
  r"\b(?:salary|sahod|sweldo|earn|kumita|kikita|income|commission|komisyon"
  r"|per (?:day|task|hour)|kada (?:araw|oras|linggo|referral)|daily|weekly|monthly)\b",
);

final RegExp _gambling = _re(
  r"\b(?:casino|jili\w*|slots?|slot games?|e-?sabong|sabong|tumaya|taya na"
  r"|betting|online bet|place (?:a |your )?bets?|sugal|free spins?"
  r"|spin the wheel|poker|baccarat|scatter|pg ?soft|ph ?365|online lotto)\b",
);

final RegExp _messagingApp = _re(
  r"\b(?:telegram|whats ?app|viber|wechat|signal app|line app)\b|\bt\.me/",
);

final RegExp _contactVerb = _re(
  r"\b(?:call|text|tawagan|tumawag|i-?text|contact|message|mag-?text|reply)\b",
);

final RegExp _replyKeyword = _re(r'\breply (?:with )?(?:yes|y|1|ok|go|join)\b');

/// Finds the [RiskIndicator]s in a message.
class RiskIndicatorDetector {
  const RiskIndicatorDetector();

  DetectionResult detect(String message) {
    final indicators = <RiskIndicator>[];
    void addIf(IndicatorType type, List<MessageSpan> spans, {String? subject}) {
      if (spans.isNotEmpty) {
        indicators.add(RiskIndicator(type, spans: spans, subject: subject));
      }
    }

    final mentioned = <String, List<MessageSpan>>{};
    for (final (brand, pattern) in _brandPatterns) {
      final spans = _find(pattern, message);
      if (spans.isNotEmpty) mentioned[brand.name] = spans;
    }

    final links = _analyzeLinks(message);
    indicators.addAll(links.indicators);

    final clauses = _clauses(message);
    final sensitive = <MessageSpan>[];
    final payment = <MessageSpan>[];
    for (final clause in clauses) {
      final text = message.substring(clause.start, clause.end);
      final terms = _find(_sensitiveTerm, text, clause.start);
      if (terms.isNotEmpty &&
          _requestVerb.hasMatch(text) &&
          !_protective.hasMatch(text)) {
        sensitive.addAll(terms);
      }
      final payVerbs = _find(_payVerb, text, clause.start);
      if (payVerbs.isNotEmpty && !_paymentDone.hasMatch(text)) {
        final objects = [
          ..._find(_payObject, text, clause.start),
          ..._find(moneyPattern, text.toLowerCase(), clause.start),
        ];
        if (objects.isNotEmpty) payment.addAll([...payVerbs, ...objects]);
      }
    }
    addIf(IndicatorType.sensitiveInfoRequest, sensitive);
    addIf(IndicatorType.paymentRequest, payment);

    final threat = _find(_threat, message);
    addIf(IndicatorType.threat, threat);
    addIf(IndicatorType.urgency, _find(_urgency, message));
    addIf(IndicatorType.prizeClaim, _find(_prize, message));
    addIf(IndicatorType.financialOffer, _find(_financialOffer, message));
    addIf(IndicatorType.gambling, _find(_gambling, message));

    final jobTerms = _find(_jobTerm, message);
    final payTerms = [
      ..._find(_payTerm, message),
      ..._find(moneyPattern, message.toLowerCase()),
    ];
    if (jobTerms.isNotEmpty && payTerms.isNotEmpty) {
      addIf(IndicatorType.jobOffer, [...jobTerms, ...payTerms]);
    }

    final phones = _find(phonePattern, message);
    final contact = [
      ..._find(_messagingApp, message),
      ..._find(_replyKeyword, message),
      if (phones.isNotEmpty && _contactVerb.hasMatch(message)) ...phones,
    ];
    addIf(IndicatorType.offPlatformContact, contact);

    // Impersonation: a known name combined with a risky link, a request for
    // codes or passwords, or a threat.
    final brandNames = {...mentioned.keys, ...links.brandsInLinks}.toList();
    final riskyContext =
        sensitive.isNotEmpty ||
        threat.isNotEmpty ||
        indicators.any(
          (i) =>
              i.type == IndicatorType.suspiciousLink ||
              i.type == IndicatorType.shortenedLink,
        );
    if (brandNames.isNotEmpty && riskyContext) {
      indicators.add(
        RiskIndicator(
          IndicatorType.impersonation,
          spans: [for (final spans in mentioned.values) ...spans],
          subject: brandNames.first,
        ),
      );
    }

    indicators.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return DetectionResult(
      indicators: indicators,
      hasSecurityReminder:
          _protective.hasMatch(message) &&
          (_sensitiveTerm.hasMatch(message) || _anyCode.hasMatch(message)),
      brands: brandNames,
    );
  }

  _LinkAnalysis _analyzeLinks(String message) {
    final suspicious = <MessageSpan>[];
    final shortened = <MessageSpan>[];
    final plain = <MessageSpan>[];
    final concerns = <LinkConcern>{};
    final brandsInLinks = <String>{};
    String? suspiciousHost;
    String? shortenedHost;
    String? plainHost;

    for (final match in linkPatternAnyCase.allMatches(message)) {
      // A link at the end of a sentence picks up the full stop; leave it out
      // of the highlight.
      var end = match.end;
      while (end > match.start &&
          _trailingPunctuation.contains(message[end - 1])) {
        end--;
      }
      final span = MessageSpan(match.start, end);
      final host = linkHost(match[0]!);
      if (shortenerDomains.contains(host)) {
        shortened.add(span);
        shortenedHost ??= host;
        continue;
      }
      if (_isOfficial(host)) continue;

      final found = <LinkConcern>{};
      if (_ipHost.hasMatch(host)) found.add(LinkConcern.ipAddress);
      final parts = host.split(_hostParts);
      for (final brand in brands) {
        if (brand.hostKeywords.any((k) => _hostMentions(host, parts, k))) {
          brandsInLinks.add(brand.name);
          found.add(LinkConcern.imitatesBrand);
        }
      }
      if (_unusualEndings.contains(parts.last)) {
        found.add(LinkConcern.unusualEnding);
      }
      if (_baitWords.any((w) => _hostMentions(host, parts, w))) {
        found.add(LinkConcern.baitWords);
      }

      if (found.isEmpty) {
        plain.add(span);
        plainHost ??= host;
      } else {
        suspicious.add(span);
        suspiciousHost ??= host;
        concerns.addAll(found);
      }
    }

    return _LinkAnalysis(
      indicators: [
        if (suspicious.isNotEmpty)
          RiskIndicator(
            IndicatorType.suspiciousLink,
            spans: suspicious,
            subject: suspiciousHost,
            linkConcerns: concerns,
          ),
        if (shortened.isNotEmpty)
          RiskIndicator(
            IndicatorType.shortenedLink,
            spans: shortened,
            subject: shortenedHost,
          ),
        if (plain.isNotEmpty)
          RiskIndicator(IndicatorType.link, spans: plain, subject: plainHost),
      ],
      brandsInLinks: brandsInLinks,
    );
  }

  static bool _isOfficial(String host) {
    if (host.endsWith('.gov.ph')) return true;
    return brands.any(
      (b) => b.officialDomains.any((d) => host == d || host.endsWith('.$d')),
    );
  }

  /// Short words (BDO, SSS) must be a whole part of the domain; longer ones
  /// may appear inside a part (gcashverify.com).
  static bool _hostMentions(String host, List<String> parts, String word) =>
      word.length <= 3 ? parts.contains(word) : host.contains(word);

  static List<MessageSpan> _clauses(String text) {
    final clauses = <MessageSpan>[];
    var start = 0;
    for (final m in _clauseEnd.allMatches(text)) {
      if (m.start > start) clauses.add(MessageSpan(start, m.start));
      start = m.end;
    }
    if (start < text.length) clauses.add(MessageSpan(start, text.length));
    return clauses;
  }

  static List<MessageSpan> _find(
    RegExp pattern,
    String text, [
    int offset = 0,
  ]) => [
    for (final m in pattern.allMatches(text))
      if (m.end > m.start) MessageSpan(offset + m.start, offset + m.end),
  ];
}

class _LinkAnalysis {
  const _LinkAnalysis({required this.indicators, required this.brandsInLinks});

  final List<RiskIndicator> indicators;
  final Set<String> brandsInLinks;
}
