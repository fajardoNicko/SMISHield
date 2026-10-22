import 'analysis_result.dart';
import 'risk_indicators.dart';
import 'risk_label.dart';

enum AppLanguage { english, filipino }

/// User-facing wording for analysis results, in English and Filipino.
class Explanations {
  const Explanations(this.language);

  final AppLanguage language;

  String _t(String english, String filipino) =>
      language == AppLanguage.filipino ? filipino : english;

  String labelTitle(RiskLabel label) => switch (label) {
    RiskLabel.safe => _t('SAFE', 'LIGTAS'),
    RiskLabel.suspicious => _t('SUSPICIOUS', 'KAHINA-HINALA'),
    RiskLabel.highRisk => _t('HIGH RISK', 'MAPANGANIB'),
  };

  String labelHeadline(RiskLabel label) => switch (label) {
    RiskLabel.safe => _t(
      'This message appears to be safe',
      'Mukhang ligtas ang mensaheng ito',
    ),
    RiskLabel.suspicious => _t(
      'This message could be suspicious',
      'Maaaring kahina-hinala ang mensaheng ito',
    ),
    RiskLabel.highRisk => _t(
      'This message is likely smishing',
      'Malamang na smishing ang mensaheng ito',
    ),
  };

  String labelSummary(RiskLabel label) => switch (label) {
    RiskLabel.safe => _t(
      'This SMS does not contain common signs of smishing.',
      'Walang karaniwang palatandaan ng smishing ang SMS na ito.',
    ),
    RiskLabel.suspicious => _t(
      'Some elements in this SMS look suspicious. Please be cautious.',
      'May ilang bahagi ng SMS na ito na kahina-hinala. Mag-ingat.',
    ),
    RiskLabel.highRisk => _t(
      'This SMS contains common signs of smishing.',
      'May mga karaniwang palatandaan ng smishing ang SMS na ito.',
    ),
  };

  String whyTitle(RiskLabel label) => switch (label) {
    RiskLabel.safe => _t('Why is this safe?', 'Bakit ito ligtas?'),
    RiskLabel.suspicious => _t(
      'Why is this suspicious?',
      'Bakit ito kahina-hinala?',
    ),
    RiskLabel.highRisk => _t('Why is this high risk?', 'Bakit ito mapanganib?'),
  };

  String get whatToDoTitle =>
      _t('What should you do?', 'Ano ang dapat mong gawin?');

  String get stillCheckTitle =>
      _t('Still worth checking', 'Dapat pa ring suriin');

  String get learnedTermsTitle => _t(
    'Words often seen in smishing messages',
    'Mga salitang madalas makita sa smishing',
  );

  String indicatorTitle(RiskIndicator indicator) {
    final subject = indicator.subject ?? '';
    return switch (indicator.type) {
      IndicatorType.suspiciousLink => _t(
        'Contains a suspicious link',
        'May kahina-hinalang link',
      ),
      IndicatorType.shortenedLink => _t(
        'Contains a shortened link',
        'May pinaikling link',
      ),
      IndicatorType.link => _t('Contains a link', 'May link'),
      IndicatorType.sensitiveInfoRequest => _t(
        'Requests sensitive information',
        'Humihingi ng sensitibong impormasyon',
      ),
      IndicatorType.impersonation => _t(
        'May be impersonating $subject',
        'Maaaring nagpapanggap na $subject',
      ),
      IndicatorType.paymentRequest => _t(
        'Asks you to pay or send money',
        'Pinapabayad o pinapapadala ka ng pera',
      ),
      IndicatorType.threat => _t(
        'Uses threats about your account',
        'Nananakot tungkol sa iyong account',
      ),
      IndicatorType.urgency => _t(
        'Creates a sense of urgency',
        'Minamadali ka',
      ),
      IndicatorType.prizeClaim => _t(
        'Mentions a prize, reward, or freebie',
        'Nag-aalok ng premyo, reward, o libre',
      ),
      IndicatorType.financialOffer => _t(
        'Offers loans, investments, or cash aid',
        'Nag-aalok ng pautang, investment, o ayuda',
      ),
      IndicatorType.jobOffer => _t(
        'Offers easy money or an online job',
        'Nag-aalok ng madaling pera o online na trabaho',
      ),
      IndicatorType.gambling => _t(
        'Promotes online gambling',
        'Nagpo-promote ng online na sugal',
      ),
      IndicatorType.offPlatformContact => _t(
        'Asks you to contact them through another app or number',
        'Pinapakontak ka sa ibang app o numero',
      ),
    };
  }

  String indicatorDetail(RiskIndicator indicator) {
    final subject = indicator.subject ?? '';
    return switch (indicator.type) {
      IndicatorType.suspiciousLink => _linkDetail(
        subject,
        indicator.linkConcerns,
      ),
      IndicatorType.shortenedLink => _t(
        'Shortened links ($subject) hide where they really lead.',
        'Itinatago ng pinaikling link ($subject) kung saan talaga ito papunta.',
      ),
      IndicatorType.link => _t(
        'Check where the link ($subject) leads before opening it.',
        'Alamin muna kung saan papunta ang link ($subject) bago ito buksan.',
      ),
      IndicatorType.sensitiveInfoRequest => _t(
        'Legitimate banks and companies never ask for your OTP, PIN, or password by text.',
        'Hindi kailanman hihingin ng mga lehitimong bangko at kumpanya ang iyong OTP, PIN, o password sa text.',
      ),
      IndicatorType.impersonation => _t(
        'Scammers often pretend to be banks, e-wallets, couriers, or government agencies.',
        'Madalas magpanggap ang mga scammer bilang bangko, e-wallet, courier, o ahensya ng gobyerno.',
      ),
      IndicatorType.paymentRequest => _t(
        'Be careful with messages asking for fees, fines, or money transfers.',
        'Mag-ingat sa mga mensaheng humihingi ng bayad, multa, o padala ng pera.',
      ),
      IndicatorType.threat => _t(
        'Threats of account suspension, fines, or arrest are used to scare you into acting.',
        'Ginagamit ang banta ng pag-suspend ng account, multa, o pag-aresto para takutin ka.',
      ),
      IndicatorType.urgency => _t(
        'Messages that rush you want you to act before you can check.',
        'Minamadali ka para hindi ka na makapag-verify.',
      ),
      IndicatorType.prizeClaim => _t(
        'Unexpected prizes and rewards are common bait.',
        'Karaniwang pain ang mga hindi inaasahang premyo at reward.',
      ),
      IndicatorType.financialOffer => _t(
        'Offers that seem too good to be true usually are.',
        'Kadalasang panloloko ang mga alok na sobrang ganda para maging totoo.',
      ),
      IndicatorType.jobOffer => _t(
        'Jobs that pay a lot for simple tasks are a common scam.',
        'Karaniwang scam ang trabahong malaki ang bayad para sa simpleng gawain.',
      ),
      IndicatorType.gambling => _t(
        'Unsolicited gambling promotions are often illegal or fraudulent.',
        'Kadalasang ilegal o panloloko ang mga hindi hinihinging promo ng sugal.',
      ),
      IndicatorType.offPlatformContact => _t(
        'Scammers move conversations to apps or numbers that are harder to trace.',
        'Inililipat ng mga scammer ang usapan sa mga app o numerong mahirap ma-trace.',
      ),
    };
  }

  String _linkDetail(String host, Set<LinkConcern> concerns) {
    final reasons = [
      for (final concern in LinkConcern.values)
        if (concerns.contains(concern))
          switch (concern) {
            LinkConcern.imitatesBrand => _t(
              'uses a company name but is not its official website',
              'gumagamit ng pangalan ng kumpanya pero hindi nito opisyal na website',
            ),
            LinkConcern.ipAddress => _t(
              'uses a number address instead of a website name',
              'numero ang address sa halip na pangalan ng website',
            ),
            LinkConcern.unusualEnding => _t(
              'ends in an unusual domain such as .xyz or .top',
              'may kakaibang dulo gaya ng .xyz o .top',
            ),
            LinkConcern.baitWords => _t(
              'uses words like "verify", "login", or "claim" to look official',
              'gumagamit ng mga salitang gaya ng "verify", "login", o "claim" para magmukhang opisyal',
            ),
          },
    ];
    return _t(
      'The link $host ${reasons.join('; ')}.',
      'Ang link na $host ay ${reasons.join('; ')}.',
    );
  }

  String safeCheck(SafeCheck check) => switch (check) {
    SafeCheck.noSuspiciousLinks => _t(
      'No suspicious links detected',
      'Walang kahina-hinalang link',
    ),
    SafeCheck.noSensitiveInfoRequest => _t(
      'No request for personal information',
      'Walang hinihinging personal na impormasyon',
    ),
    SafeCheck.noUrgencyOrThreat => _t(
      'No urgency or threatening language',
      'Walang pagmamadali o pananakot',
    ),
    SafeCheck.noFinancialOrPrizeClaims => _t(
      'No financial or prize claims',
      'Walang alok na pera o premyo',
    ),
    SafeCheck.warnsNotToShareCodes => _t(
      'Reminds you not to share your code',
      'Pinapaalalahanan kang huwag ibigay ang iyong code',
    ),
  };

  String action(SafetyAction action) => switch (action) {
    SafetyAction.beCautious => _t(
      'Always be cautious with unexpected messages.',
      'Laging mag-ingat sa mga hindi inaasahang mensahe.',
    ),
    SafetyAction.verifyWithOfficialSource => _t(
      'When in doubt, verify with the official source.',
      'Kapag may duda, i-verify sa opisyal na pinagmulan.',
    ),
    SafetyAction.dontClickLinksRightAway => _t(
      'Do not click on links right away.',
      'Huwag agad i-click ang mga link.',
    ),
    SafetyAction.verifySender => _t(
      'Verify the sender through official channels.',
      'I-verify ang nagpadala sa opisyal na paraan.',
    ),
    SafetyAction.ignoreOrReport => _t(
      'If unsure, ignore or report the message.',
      'Kung hindi sigurado, huwag pansinin o i-report ang mensahe.',
    ),
    SafetyAction.dontClickAnyLinks => _t(
      'Do not click any links.',
      'Huwag i-click ang anumang link.',
    ),
    SafetyAction.dontShareInfo => _t(
      'Do not share personal or banking information.',
      'Huwag ibigay ang personal o banking na impormasyon.',
    ),
    SafetyAction.reportAndBlock => _t(
      'Report this message and block the sender.',
      'I-report ang mensaheng ito at i-block ang nagpadala.',
    ),
    SafetyAction.neverShareCodes => _t(
      'Never give your OTP, PIN, or password to anyone.',
      'Huwag kailanman ibigay ang iyong OTP, PIN, o password kahit kanino.',
    ),
    SafetyAction.dontSendMoney => _t(
      'Do not send money or pay fees to claim anything.',
      'Huwag magpadala ng pera o magbayad para may ma-claim.',
    ),
    SafetyAction.useOfficialApp => _t(
      'Use the official app or type the official website yourself instead of the link.',
      'Gamitin ang opisyal na app o i-type mismo ang opisyal na website sa halip na ang link.',
    ),
    SafetyAction.reportToCicc => _t(
      'You can report scams to the CICC hotline 1326.',
      'Maaari mong i-report ang scam sa CICC hotline 1326.',
    ),
  };

  String error(AnalysisError error) => switch (error) {
    AnalysisError.empty => _t(
      'Please paste or type a message first.',
      'Mag-paste o mag-type muna ng mensahe.',
    ),
    AnalysisError.tooLong => _t(
      'This message is too long. Paste a single SMS (up to 2,000 characters).',
      'Masyadong mahaba ang mensahe. Mag-paste ng isang SMS lang (hanggang 2,000 character).',
    ),
    AnalysisError.noReadableText => _t(
      'This message has no readable words to analyze.',
      'Walang mababasang salita sa mensaheng ito.',
    ),
    AnalysisError.unrecognizedContent => _t(
      'SMISHield did not recognize any words in this message, so it cannot classify it. '
          'It may be in a language the app does not support.',
      'Walang nakilalang salita ang SMISHield sa mensaheng ito kaya hindi ito ma-classify. '
          'Maaaring nasa wikang hindi suportado ng app.',
    ),
  };
}
