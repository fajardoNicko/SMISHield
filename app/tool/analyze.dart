// Try the analyzer from the terminal, without building the app:
//
//   cd app
//   dart run tool/analyze.dart "URGENT! I-verify ang GCash mo sa gcash-verify.xyz"
//   dart run tool/analyze.dart --fil "..."      (Filipino explanations)
import 'dart:io';

import 'package:smishield/ml/analysis_result.dart';
import 'package:smishield/ml/explanations.dart';
import 'package:smishield/ml/risk_label.dart';
import 'package:smishield/ml/smishield_analyzer.dart';
import 'package:smishield/ml/smishield_model.dart';

void main(List<String> args) {
  final filipino = args.contains('--fil');
  final messages = args.where((a) => a != '--fil').toList();
  if (messages.isEmpty) {
    stderr.writeln('Usage: dart run tool/analyze.dart [--fil] "message" ...');
    exit(64);
  }

  final model = SmishieldModel.fromJsonString(
    File('assets/model/smishield_model.json').readAsStringSync(),
  );
  final analyzer = SmishieldAnalyzer(model);
  final text = Explanations(
    filipino ? AppLanguage.filipino : AppLanguage.english,
  );
  final out = stdout;

  if (model.info.isPlaceholder) {
    out.writeln('(model trained on PLACEHOLDER data)');
  }
  for (final message in messages) {
    out.writeln('\n$message');
    try {
      final result = analyzer.analyze(message);
      final percents = result.probabilities.entries
          .map(
            (e) => '${e.key.modelName} ${(e.value * 100).toStringAsFixed(1)}%',
          )
          .join(', ');
      out.writeln(
        '  ${text.labelTitle(result.label)} - '
        '${text.labelHeadline(result.label)} ($percents)',
      );
      out.writeln('  ${text.whyTitle(result.label)}');
      if (result.label == RiskLabel.safe) {
        for (final check in result.passedChecks) {
          out.writeln('    + ${text.safeCheck(check)}');
        }
      }
      for (final indicator in result.indicators) {
        out.writeln(
          '    ! ${text.indicatorTitle(indicator)}: '
          '${text.indicatorDetail(indicator)}',
        );
      }
      if (result.learnedTerms.isNotEmpty) {
        out.writeln(
          '  ${text.learnedTermsTitle}: ${result.learnedTerms.join(', ')}',
        );
      }
      out.writeln(
        '  Highlighted: ${result.highlights.map((h) => '"${result.message.substring(h.span.start, h.span.end)}"').join(' ')}',
      );
      out.writeln('  ${text.whatToDoTitle}');
      for (final action in result.actions) {
        out.writeln('    - ${text.action(action)}');
      }
    } on AnalysisException catch (e) {
      out.writeln('  ${text.error(e.error)}');
    }
  }
}
