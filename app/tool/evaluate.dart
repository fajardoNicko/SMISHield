// System testing: classify a whole test set with the app's own on-device
// analyzer (the same code and model the APK runs), for the confusion matrix.
//
//   cd app
//   dart run tool/evaluate.dart <test_set.json> <predictions.json>
//
// The input is a JSON list of {"id", "message", "label"}; the output adds the
// app's label and probabilities, or the reason it could not classify.
import 'dart:convert';
import 'dart:io';

import 'package:smishield/ml/analysis_result.dart';
import 'package:smishield/ml/risk_label.dart';
import 'package:smishield/ml/smishield_analyzer.dart';
import 'package:smishield/ml/smishield_model.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/evaluate.dart <test_set.json> <predictions.json>',
    );
    exit(64);
  }
  final model = SmishieldModel.fromJsonString(
    File('assets/model/smishield_model.json').readAsStringSync(),
  );
  final analyzer = SmishieldAnalyzer(model);
  final items = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  final stopwatch = Stopwatch()..start();
  final predictions = [for (final item in items) _classify(analyzer, item)];
  stopwatch.stop();

  File(args[1]).writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      'model_created_at': model.info.createdAt?.toIso8601String(),
      'label_status': model.info.labelStatus,
      'messages': items.length,
      'milliseconds_total': stopwatch.elapsedMilliseconds,
      'predictions': predictions,
    }),
  );
  final classified = predictions.where((p) => p['predicted'] != null).length;
  stdout.writeln(
    'Classified $classified of ${items.length} messages with the app analyzer '
    'in ${stopwatch.elapsedMilliseconds} ms -> ${args[1]}',
  );
}

Map<String, dynamic> _classify(
  SmishieldAnalyzer analyzer,
  Map<String, dynamic> item,
) {
  final base = {'id': item['id'], 'label': item['label']};
  try {
    final result = analyzer.analyze(item['message'] as String);
    return {
      ...base,
      'predicted': result.label.modelName,
      for (final label in RiskLabel.values)
        'p_${label.modelName}': result.probabilities[label],
      'warning_signs': [for (final i in result.indicators) i.type.name],
    };
  } on AnalysisException catch (e) {
    return {...base, 'predicted': null, 'error': e.error.name};
  }
}
