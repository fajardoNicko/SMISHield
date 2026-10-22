import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'smishield_analyzer.dart';
import 'smishield_model.dart';

const String modelAssetPath = 'assets/model/smishield_model.json';

/// Loads the bundled model. Parsing runs on a background isolate so the UI
/// does not stutter at start-up.
Future<SmishieldAnalyzer> loadAnalyzer() async {
  final source = await rootBundle.loadString(modelAssetPath);
  final model = await compute(SmishieldModel.fromJsonString, source);
  return SmishieldAnalyzer(model);
}
