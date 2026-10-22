import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smishield/ml/analysis_result.dart';
import 'package:smishield/ml/explanations.dart';
import 'package:smishield/ml/preprocessor.dart';
import 'package:smishield/ml/risk_indicators.dart';
import 'package:smishield/ml/risk_label.dart';
import 'package:smishield/ml/smishield_analyzer.dart';
import 'package:smishield/ml/smishield_model.dart';

/// A tiny hand-made model, so these tests do not depend on the trained one.
SmishieldModel tinyModel() {
  final log = math.log;
  return SmishieldModel.fromJson({
    'format': 'smishield-mnb',
    'preprocessing_version': preprocessingVersion,
    'created_at': '2026-10-22T00:00:00+00:00',
    'dataset': {'source': 'test', 'is_placeholder': true},
    'evaluation': <String, dynamic>{},
    'vectorizer': {
      'ngram_range': [1, 1],
      'sublinear_tf': false,
      'norm': 'l2',
      'smooth_idf': true,
    },
    'classifier': {'alpha': 1.0},
    'classes': ['Safe', 'Suspicious', 'High Risk'],
    'class_log_prior': [log(1 / 3), log(1 / 3), log(1 / 3)],
    'terms': ['salamat', 'promo', 'otp', 'verify', urlToken],
    'idf': [1.0, 1.0, 1.0, 1.0, 1.0],
    'feature_log_prob': [
      [log(.6), log(.1), log(.1), log(.1), log(.1)],
      [log(.1), log(.6), log(.1), log(.1), log(.1)],
      [log(.05), log(.05), log(.3), log(.3), log(.3)],
    ],
  });
}

void main() {
  final analyzer = SmishieldAnalyzer(
    tinyModel(),
    clock: () => DateTime(2026, 10, 22, 9, 30),
  );

  AnalysisError errorOf(String message) {
    try {
      analyzer.analyze(message);
    } on AnalysisException catch (e) {
      return e.error;
    }
    fail('expected an AnalysisException for "$message"');
  }

  test('rejects input that cannot be classified', () {
    expect(errorOf(''), AnalysisError.empty);
    expect(errorOf('   \n '), AnalysisError.empty);
    expect(
      errorOf('a' * (SmishieldAnalyzer.maxLength + 1)),
      AnalysisError.tooLong,
    );
    expect(errorOf('!!! ???'), AnalysisError.noReadableText);
    expect(errorOf('qwerty asdf'), AnalysisError.unrecognizedContent);
  });

  test('a safe message passes every check', () {
    final result = analyzer.analyze('  Salamat po!  ');
    expect(result.message, 'Salamat po!');
    expect(result.label, RiskLabel.safe);
    expect(result.indicators, isEmpty);
    expect(result.learnedTerms, isEmpty);
    expect(result.passedChecks, [
      SafeCheck.noSuspiciousLinks,
      SafeCheck.noSensitiveInfoRequest,
      SafeCheck.noUrgencyOrThreat,
      SafeCheck.noFinancialOrPrizeClaims,
    ]);
    expect(result.actions, [
      SafetyAction.beCautious,
      SafetyAction.verifyWithOfficialSource,
    ]);
    expect(result.analyzedAt, DateTime(2026, 10, 22, 9, 30));
    expect(
      result.probabilities.values.reduce((a, b) => a + b),
      closeTo(1, 1e-12),
    );
  });

  test('a phishing message is high risk with explanations and advice', () {
    final result = analyzer.analyze(
      'URGENT: verify your BPI OTP now at bpi-secure-login.com',
    );
    expect(result.label, RiskLabel.highRisk);
    expect(result.confidence, greaterThan(0.5));
    expect(result.learnedTerms, containsAll(['otp', 'verify']));
    expect(
      result.indicators.map((i) => i.type),
      containsAll([IndicatorType.suspiciousLink, IndicatorType.impersonation]),
    );
    expect(
      result.actions,
      containsAll([
        SafetyAction.dontClickAnyLinks,
        SafetyAction.reportAndBlock,
        SafetyAction.useOfficialApp,
        SafetyAction.reportToCicc,
      ]),
    );

    // Highlights are sorted, inside the message and never overlap.
    final spans = result.highlights.map((h) => h.span).toList();
    expect(spans, isNotEmpty);
    for (var i = 0; i < spans.length; i++) {
      expect(spans[i].end, lessThanOrEqualTo(result.message.length));
      if (i > 0) expect(spans[i].start, greaterThanOrEqualTo(spans[i - 1].end));
    }
    expect(result.highlights.any((h) => h.isLearnedPattern), isTrue);
  });

  test(
    'every indicator, check, action and error has text in both languages',
    () {
      final result = analyzer.analyze(
        'URGENT: verify your BPI OTP now at bpi-secure-login.com',
      );
      for (final language in AppLanguage.values) {
        final text = Explanations(language);
        for (final indicator in result.indicators) {
          expect(text.indicatorTitle(indicator), isNotEmpty);
          expect(text.indicatorDetail(indicator), isNotEmpty);
        }
        for (final label in RiskLabel.values) {
          expect(text.labelTitle(label), isNotEmpty);
        }
        for (final check in SafeCheck.values) {
          expect(text.safeCheck(check), isNotEmpty);
        }
        for (final action in SafetyAction.values) {
          expect(text.action(action), isNotEmpty);
        }
        for (final error in AnalysisError.values) {
          expect(text.error(error), isNotEmpty);
        }
      }
    },
  );
}
