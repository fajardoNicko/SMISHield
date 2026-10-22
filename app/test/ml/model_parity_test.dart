// Checks that the Dart preprocessing and inference reproduce the Python
// training pipeline exactly. The fixture is written by ml/train.py together
// with the model, so retrain (which refreshes both) if this test fails after
// changing the preprocessing.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smishield/ml/preprocessor.dart';
import 'package:smishield/ml/smishield_model.dart';

void main() {
  final model = SmishieldModel.fromJsonString(
    File('assets/model/smishield_model.json').readAsStringSync(),
  );
  final fixture = jsonDecode(
    File('test/fixtures/model_parity_cases.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

  test('fixture belongs to the bundled model', () {
    expect(fixture['preprocessing_version'], preprocessingVersion);
    expect(
      DateTime.parse(fixture['model_created_at'] as String),
      model.info.createdAt,
    );
    expect(cases, isNotEmpty);
  });

  for (final (i, c) in cases.indexed) {
    final text = c['text'] as String;
    test(
      'case $i: ${text.length > 50 ? '${text.substring(0, 50)}...' : text}',
      () {
        expect(tokenize(text), c['tokens']);

        final prediction = model.predict(text);
        final expected = (c['probabilities'] as List).cast<num>();
        for (var k = 0; k < model.classes.length; k++) {
          expect(
            prediction.probabilities[model.classes[k]],
            closeTo(expected[k].toDouble(), 1e-9),
          );
        }
      },
    );
  }
}
