import 'risk_indicators.dart';
import 'risk_label.dart';

/// Reassuring checks shown under "Why is this safe?".
enum SafeCheck {
  noSuspiciousLinks,
  noSensitiveInfoRequest,
  noUrgencyOrThreat,
  noFinancialOrPrizeClaims,
  warnsNotToShareCodes,
}

/// Recommended next steps shown under "What should you do?".
enum SafetyAction {
  beCautious,
  verifyWithOfficialSource,
  dontClickLinksRightAway,
  verifySender,
  ignoreOrReport,
  dontClickAnyLinks,
  dontShareInfo,
  reportAndBlock,
  neverShareCodes,
  dontSendMoney,
  useOfficialApp,
  reportToCicc,
}

/// Why a message could not be analysed.
enum AnalysisError { empty, tooLong, noReadableText, unrecognizedContent }

class AnalysisException implements Exception {
  const AnalysisException(this.error);

  final AnalysisError error;

  @override
  String toString() => 'AnalysisException(${error.name})';
}

/// A part of the message to highlight. [type] is null for words the model
/// learned to associate with the predicted label (rather than a rule match).
class TextHighlight {
  const TextHighlight(this.span, this.type);

  final MessageSpan span;
  final IndicatorType? type;

  bool get isLearnedPattern => type == null;
}

class AnalysisResult {
  const AnalysisResult({
    required this.message,
    required this.label,
    required this.probabilities,
    required this.indicators,
    required this.passedChecks,
    required this.highlights,
    required this.learnedTerms,
    required this.actions,
    required this.analyzedAt,
  });

  /// The analysed message, trimmed. Highlight spans index into this string.
  final String message;
  final RiskLabel label;
  final Map<RiskLabel, double> probabilities;

  /// Warning signs found, most severe first.
  final List<RiskIndicator> indicators;
  final List<SafeCheck> passedChecks;

  /// Non-overlapping, sorted by position.
  final List<TextHighlight> highlights;

  /// Words in the message that most pushed the model towards [label]
  /// (empty for Safe results).
  final List<String> learnedTerms;
  final List<SafetyAction> actions;
  final DateTime analyzedAt;

  double get confidence => probabilities[label]!;
}
