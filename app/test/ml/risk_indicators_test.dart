import 'package:flutter_test/flutter_test.dart';
import 'package:smishield/ml/risk_indicators.dart';

void main() {
  const detector = RiskIndicatorDetector();

  Set<IndicatorType> types(String message) =>
      detector.detect(message).indicators.map((i) => i.type).toSet();

  test('flags the bank phishing example from the research plan', () {
    final result = detector.detect(
      'URGENT! Your BPI account has been locked. Verify your identity to avoid '
      'suspension. Login here: http://bpi-secure-login.com. Enter your '
      'username, password and OTP.',
    );
    final found = result.indicators.map((i) => i.type).toSet();
    expect(
      found,
      containsAll([
        IndicatorType.suspiciousLink,
        IndicatorType.sensitiveInfoRequest,
        IndicatorType.impersonation,
        IndicatorType.urgency,
        IndicatorType.threat,
      ]),
    );
    final link = result.find(IndicatorType.suspiciousLink)!;
    expect(link.subject, 'bpi-secure-login.com');
    // The sentence's full stop is not part of the highlighted link.
    final linkSpan = link.spans.single;
    expect(linkSpan.end - linkSpan.start, 'http://bpi-secure-login.com'.length);
    expect(
      link.linkConcerns,
      containsAll([LinkConcern.imitatesBrand, LinkConcern.baitWords]),
    );
    expect(result.find(IndicatorType.impersonation)!.subject, 'BPI');
    // Most severe first.
    expect(result.indicators.first.severity, Severity.high);
  });

  test('a genuine OTP message is a security reminder, not a request', () {
    final result = detector.detect(
      '123456 is your GCash authentication code. Huwag ibigay ang code na ito '
      'kahit kanino.',
    );
    expect(result.has(IndicatorType.sensitiveInfoRequest), isFalse);
    expect(result.has(IndicatorType.impersonation), isFalse);
    expect(result.hasSecurityReminder, isTrue);
  });

  test('official domains are not flagged', () {
    expect(
      types(
        'Your Lazada order has been shipped. Track it at '
        'https://lazada.com.ph/track/123456',
      ),
      isNot(
        anyOf(
          contains(IndicatorType.link),
          contains(IndicatorType.suspiciousLink),
        ),
      ),
    );
    expect(types('Visit https://www.sss.gov.ph for details'), isEmpty);
  });

  test('shortened, unusual and IP links', () {
    expect(
      types('Tingnan dito: bit.ly/abc'),
      contains(IndicatorType.shortenedLink),
    );
    final unusual = detector
        .detect('Promo: mega-sale.xyz')
        .find(IndicatorType.suspiciousLink)!;
    expect(unusual.linkConcerns, contains(LinkConcern.unusualEnding));
    final ip = detector
        .detect('Login at 192.168.1.20/bank')
        .find(IndicatorType.suspiciousLink)!;
    expect(ip.linkConcerns, contains(LinkConcern.ipAddress));
    expect(types('See myblog.com/post'), contains(IndicatorType.link));
  });

  test('family emergency money request', () {
    expect(
      types(
        'Ma, nawala phone ko. Padalhan mo ako ng P5,000 sa GCash, emergency lang.',
      ),
      containsAll([IndicatorType.paymentRequest, IndicatorType.urgency]),
    );
  });

  test('threats to harm or kidnap the reader or their family', () {
    for (final message in [
      'Papatayin ko anak mo penge pera',
      'Sasaksakin kita pag di mo binigay yung pera bukas',
      'Kinidnap namin ang asawa mo. 200k kapalit ng buhay niya',
      'hawak ko anak mo wag kang tatawag sa pulis',
      'Nasa amin ang anak mo. Ihanda ang pantubos',
      'Ipapakalat ko mga pictures mo kapag hindi ka nagbayad ng 5000',
      'Ma tulungan mo ko kinidnap ako, padalhan mo sila ng 50k',
      'I will kill your son if you dont send money',
      'We have your daughter. Send 100k now',
    ]) {
      expect(
        types(message),
        contains(IndicatorType.harmThreat),
        reason: message,
      );
    }
    final threat = detector
        .detect('Papatayin ko anak mo penge pera')
        .find(IndicatorType.harmThreat)!;
    expect(threat.severity, Severity.high);
    expect(threat.spans.single, const MessageSpan(0, 9));
    // "penge pera" asks for money.
    expect(
      types('Papatayin ko anak mo penge pera'),
      contains(IndicatorType.paymentRequest),
    );
  });

  test('everyday uses of violent words are not threats', () {
    for (final message in [
      'papatayin ako ni mama pag late ako umuwi',
      'Lagot ka, papatayin ka ni maam pag di mo pinasa yung project',
      'patayin mo na yung ilaw sa sala bago ka matulog',
      'nasaktan ka ba kanina? ingat ka sa pag uwi',
      'grabe yung exam kanina, pinatay kami ng prof',
      'hawak ko na yung susi, nasa labas na ako',
      'saksakin mo na yung charger lowbat na ako',
      'PNP: Suspek sa pamamaril sa Batangas, arestado na',
    ]) {
      expect(
        types(message),
        isNot(contains(IndicatorType.harmThreat)),
        reason: message,
      );
    }
  });

  test('advice not to send money is not a payment request', () {
    expect(
      types('Huwag magpadala ng pera sa hindi mo kakilala.'),
      isNot(contains(IndicatorType.paymentRequest)),
    );
  });

  test('confirmed payments are not payment requests', () {
    expect(
      types('GCash: You have paid P120.00 to 7-ELEVEN. Ref No. 7001234567.'),
      isNot(contains(IndicatorType.paymentRequest)),
    );
  });

  test('job offers need both a job and a pay term', () {
    expect(
      types(
        'Hiring! Part-time online job, kumita ng P500 kada araw. Message us on Telegram.',
      ),
      containsAll([IndicatorType.jobOffer, IndicatorType.offPlatformContact]),
    );
    expect(
      types('May trabaho pa ako bukas.'),
      isNot(contains(IndicatorType.jobOffer)),
    );
  });

  test('gambling, prizes and loan offers', () {
    expect(
      types('JILI CASINO: 100% bonus sa deposit!'),
      containsAll([IndicatorType.gambling, IndicatorType.prizeClaim]),
    );
    expect(
      types('Pautang mabilis, walang collateral!'),
      contains(IndicatorType.financialOffer),
    );
  });

  test('everyday Filipino words are not mistaken for warning signs', () {
    // "pin location", "kaso" (but) and lowercase "dito" (here).
    expect(types('Pa-send naman ng pin location mo, nandito na ako.'), isEmpty);
    expect(types('Gusto ko sana sumama kaso wala akong pera.'), isEmpty);
    expect(detector.detect('Andito na ako sa may gate.').brands, isEmpty);
  });

  test('reports spans inside the message', () {
    const message = 'Ilagay ang MPIN mo';
    final indicator = detector
        .detect('Pakisend ang OTP. $message')
        .find(IndicatorType.sensitiveInfoRequest)!;
    expect(indicator.spans, isNotEmpty);
    for (final span in indicator.spans) {
      expect(span.end, greaterThan(span.start));
    }
  });
}
