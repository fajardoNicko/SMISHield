import 'analysis_result.dart';
import 'preprocessor.dart';
import 'risk_indicators.dart';
import 'risk_label.dart';
import 'smishield_model.dart';

/// Runs the full analysis of one pasted message: input checks, the Naive
/// Bayes classification, warning-sign detection, highlights and advice.
class SmishieldAnalyzer {
  SmishieldAnalyzer(
    this.model, {
    this.detector = const RiskIndicatorDetector(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Longest accepted input. A long multi-part SMS is about 1,600 characters.
  static const int maxLength = 2000;

  /// How many model-learned words to report and highlight.
  static const int maxLearnedTerms = 5;

  final SmishieldModel model;
  final RiskIndicatorDetector detector;
  final DateTime Function() _clock;

  /// Throws [AnalysisException] when the message cannot be classified.
  AnalysisResult analyze(String message) {
    final text = message.trim();
    if (text.isEmpty) throw const AnalysisException(AnalysisError.empty);
    if (text.length > maxLength) {
      throw const AnalysisException(AnalysisError.tooLong);
    }

    final prediction = model.predict(text);
    if (prediction.tokens.isEmpty) {
      throw const AnalysisException(AnalysisError.noReadableText);
    }
    if (prediction.knownTermCount == 0) {
      throw const AnalysisException(AnalysisError.unrecognizedContent);
    }

    final detection = detector.detect(text);
    final learned = prediction.label == RiskLabel.safe
        ? <String>[]
        : _learnedTerms(prediction);

    return AnalysisResult(
      message: text,
      label: prediction.label,
      probabilities: prediction.probabilities,
      indicators: detection.indicators,
      passedChecks: _passedChecks(detection),
      highlights: _highlights(text, detection.indicators, learned),
      learnedTerms: learned,
      actions: _actions(prediction.label, detection),
      analyzedAt: _clock(),
    );
  }

  List<String> _learnedTerms(ModelPrediction prediction) => prediction.evidence
      .map((e) => e.term)
      .where(
        (term) =>
            !term.contains(' ') &&
            term.length >= 3 &&
            !markerTokens.contains(term) &&
            !_commonWords.contains(term),
      )
      .take(maxLearnedTerms)
      .toList();

  static List<SafeCheck> _passedChecks(DetectionResult d) => [
    if (!d.has(IndicatorType.suspiciousLink) &&
        !d.has(IndicatorType.shortenedLink))
      SafeCheck.noSuspiciousLinks,
    if (!d.has(IndicatorType.sensitiveInfoRequest))
      SafeCheck.noSensitiveInfoRequest,
    if (!d.has(IndicatorType.urgency) && !d.has(IndicatorType.threat))
      SafeCheck.noUrgencyOrThreat,
    if (!d.has(IndicatorType.prizeClaim) &&
        !d.has(IndicatorType.financialOffer) &&
        !d.has(IndicatorType.paymentRequest) &&
        !d.has(IndicatorType.jobOffer) &&
        !d.has(IndicatorType.gambling))
      SafeCheck.noFinancialOrPrizeClaims,
    if (d.hasSecurityReminder) SafeCheck.warnsNotToShareCodes,
  ];

  static List<SafetyAction> _actions(RiskLabel label, DetectionResult d) {
    final imitatesBrand =
        d.has(IndicatorType.impersonation) ||
        (d
                .find(IndicatorType.suspiciousLink)
                ?.linkConcerns
                .contains(LinkConcern.imitatesBrand) ??
            false);
    final actions = <SafetyAction>{
      ...switch (label) {
        RiskLabel.safe => [
          SafetyAction.beCautious,
          SafetyAction.verifyWithOfficialSource,
        ],
        RiskLabel.suspicious => [
          SafetyAction.dontClickLinksRightAway,
          SafetyAction.verifySender,
          SafetyAction.ignoreOrReport,
        ],
        RiskLabel.highRisk => [
          SafetyAction.dontClickAnyLinks,
          SafetyAction.dontShareInfo,
          SafetyAction.reportAndBlock,
        ],
      },
      if (d.has(IndicatorType.sensitiveInfoRequest))
        SafetyAction.neverShareCodes,
      if (label != RiskLabel.safe && d.has(IndicatorType.paymentRequest))
        SafetyAction.dontSendMoney,
      if (label != RiskLabel.safe && imitatesBrand) SafetyAction.useOfficialApp,
      if (label == RiskLabel.highRisk) SafetyAction.reportToCicc,
    };
    return actions.toList();
  }

  /// Highlights rule matches (most severe kept when they overlap), then the
  /// model-learned words that are not already covered.
  static List<TextHighlight> _highlights(
    String text,
    List<RiskIndicator> indicators,
    List<String> learnedTerms,
  ) {
    final candidates = <TextHighlight>[
      for (final indicator in indicators)
        for (final span in indicator.spans) TextHighlight(span, indicator.type),
      for (final term in learnedTerms)
        for (final m in RegExp(
          '(?<![a-z0-9ñ])${RegExp.escape(term)}(?![a-z0-9ñ])',
          caseSensitive: false,
        ).allMatches(text))
          TextHighlight(MessageSpan(m.start, m.end), null),
    ];

    final accepted = <TextHighlight>[];
    for (final candidate in candidates) {
      if (!accepted.any((h) => h.span.overlaps(candidate.span))) {
        accepted.add(candidate);
      }
    }
    accepted.sort((a, b) => a.span.start.compareTo(b.span.start));
    return accepted;
  }
}

/// Everyday words never shown as "learned" warning words.
const Set<String> _commonWords = {
  'ang',
  'mga',
  'ako',
  'ikaw',
  'kayo',
  'kami',
  'tayo',
  'sila',
  'siya',
  'iyo',
  'iyong',
  'inyo',
  'inyong',
  'niyo',
  'nyo',
  'mo',
  'ko',
  'po',
  'opo',
  'yung',
  'ito',
  'iyan',
  'yan',
  'yun',
  'iyon',
  'dito',
  'diyan',
  'doon',
  'para',
  'pero',
  'kung',
  'lang',
  'naman',
  'din',
  'rin',
  'nang',
  'kay',
  'kina',
  'sina',
  'mag',
  'the',
  'and',
  'for',
  'you',
  'your',
  'are',
  'this',
  'that',
  'with',
  'from',
  'our',
  'has',
  'have',
  'been',
  'will',
  'was',
  'not',
  'any',
  'can',
  'all',
  'its',
  'into',
  'out',
  'who',
  'what',
  'here',
  'there',
  'just',
  'now',
};
