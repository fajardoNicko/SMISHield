import 'dart:math' as math;

import 'package:smishield/ml/preprocessor.dart';
import 'package:smishield/ml/smishield_model.dart';

/// A tiny hand-made model, so these tests do not depend on the trained one.
SmishieldModel tinyModel() {
  final log = math.log;
  return SmishieldModel.fromJson({
    'format': 'smishield-mnb',
    'preprocessing_version': preprocessingVersion,
    'created_at': '2026-10-22T00:00:00+00:00',
    'dataset': {'source': 'test', 'label_status': 'placeholder'},
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
