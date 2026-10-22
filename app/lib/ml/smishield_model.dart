import 'dart:convert';
import 'dart:math' as math;

import 'preprocessor.dart';
import 'risk_label.dart';

/// Facts about the exported model, read from its JSON header.
class ModelInfo {
  const ModelInfo({
    required this.createdAt,
    required this.datasetSource,
    required this.isPlaceholder,
    required this.testAccuracy,
    required this.termCount,
  });

  final DateTime? createdAt;
  final String datasetSource;

  /// True when the model was trained on the made-up placeholder dataset.
  final bool isPlaceholder;
  final double? testAccuracy;
  final int termCount;
}

/// How much one word or word pair pushed the message towards its label.
class TermEvidence {
  const TermEvidence(this.term, this.weight);

  /// A vocabulary term: one token, or two tokens joined by a space.
  final String term;

  /// Contribution to the log-probability gap between the predicted label and
  /// the competing label(s). Larger means stronger evidence.
  final double weight;

  @override
  String toString() => '$term (${weight.toStringAsFixed(3)})';
}

class ModelPrediction {
  const ModelPrediction({
    required this.label,
    required this.probabilities,
    required this.tokens,
    required this.knownTermCount,
    required this.evidence,
  });

  final RiskLabel label;
  final Map<RiskLabel, double> probabilities;
  final List<String> tokens;

  /// Number of distinct vocabulary terms found in the message. Zero means the
  /// model has never seen any of its words and the prediction is just the
  /// class prior.
  final int knownTermCount;

  /// Terms that supported [label], strongest first.
  final List<TermEvidence> evidence;

  double get confidence => probabilities[label]!;
}

/// TF-IDF + Multinomial Naive Bayes model exported by ml/train.py.
///
/// Inference is the same arithmetic scikit-learn performs: count the n-grams
/// of the preprocessed message, weight them by TF-IDF, L2-normalise, then add
/// each class's log prior to the dot product with its feature log
/// probabilities and apply softmax.
class SmishieldModel {
  SmishieldModel._({
    required this.info,
    required this.classes,
    required List<String> terms,
    required this._idf,
    required this._featureLogProb,
    required this._classLogPrior,
    required this._ngramMin,
    required this._ngramMax,
    required this._sublinearTf,
    required this._l2Normalize,
  }) : _terms = terms,
       _index = {for (var i = 0; i < terms.length; i++) terms[i]: i};

  factory SmishieldModel.fromJsonString(String source) =>
      SmishieldModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory SmishieldModel.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'smishield-mnb') {
      throw const FormatException('Not a SMISHield model file');
    }
    final version = json['preprocessing_version'];
    if (version != preprocessingVersion) {
      throw FormatException(
        'The model was trained with preprocessing v$version but the app uses '
        'v$preprocessingVersion. Retrain the model or update the app.',
      );
    }

    List<double> doubles(Object? list) => [
      for (final v in list as List) (v as num).toDouble(),
    ];

    final terms = (json['terms'] as List).cast<String>();
    final vectorizer = json['vectorizer'] as Map<String, dynamic>;
    final ngrams = (vectorizer['ngram_range'] as List).cast<int>();
    final dataset = json['dataset'] as Map<String, dynamic>? ?? const {};
    final evaluation = json['evaluation'] as Map<String, dynamic>? ?? const {};

    return SmishieldModel._(
      info: ModelInfo(
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        datasetSource: dataset['source'] as String? ?? 'unknown',
        isPlaceholder: dataset['is_placeholder'] as bool? ?? false,
        testAccuracy: (evaluation['accuracy'] as num?)?.toDouble(),
        termCount: terms.length,
      ),
      classes: [
        for (final name in json['classes'] as List)
          RiskLabel.fromModelName(name as String),
      ],
      terms: terms,
      idf: doubles(json['idf']),
      featureLogProb: [
        for (final row in json['feature_log_prob'] as List) doubles(row),
      ],
      classLogPrior: doubles(json['class_log_prior']),
      ngramMin: ngrams[0],
      ngramMax: ngrams[1],
      sublinearTf: vectorizer['sublinear_tf'] as bool,
      l2Normalize: vectorizer['norm'] == 'l2',
    );
  }

  final ModelInfo info;
  final List<RiskLabel> classes;
  final List<String> _terms;
  final Map<String, int> _index;
  final List<double> _idf;
  final List<List<double>> _featureLogProb;
  final List<double> _classLogPrior;
  final int _ngramMin;
  final int _ngramMax;
  final bool _sublinearTf;
  final bool _l2Normalize;

  /// Same n-gram expansion as scikit-learn's CountVectorizer.
  List<String> _ngrams(List<String> tokens) => [
    for (var n = _ngramMin; n <= _ngramMax; n++)
      for (var i = 0; i + n <= tokens.length; i++)
        tokens.sublist(i, i + n).join(' '),
  ];

  /// TF-IDF weights of the vocabulary terms present in [tokens].
  Map<int, double> features(List<String> tokens) {
    final counts = <int, int>{};
    for (final gram in _ngrams(tokens)) {
      final i = _index[gram];
      if (i != null) counts[i] = (counts[i] ?? 0) + 1;
    }
    final weights = <int, double>{
      for (final e in counts.entries)
        e.key:
            (_sublinearTf ? 1 + math.log(e.value) : e.value.toDouble()) *
            _idf[e.key],
    };
    if (_l2Normalize) {
      final norm = math.sqrt(weights.values.fold(0.0, (sum, w) => sum + w * w));
      if (norm > 0) weights.updateAll((_, w) => w / norm);
    }
    return weights;
  }

  ModelPrediction predict(String text) => predictTokens(tokenize(text));

  ModelPrediction predictTokens(List<String> tokens) {
    final weights = features(tokens);
    final scores = [
      for (var c = 0; c < classes.length; c++)
        weights.entries.fold(
          _classLogPrior[c],
          (sum, e) => sum + e.value * _featureLogProb[c][e.key],
        ),
    ];
    final top = scores.reduce(math.max);
    final exps = [for (final s in scores) math.exp(s - top)];
    final total = exps.reduce((a, b) => a + b);

    var best = 0;
    for (var c = 1; c < classes.length; c++) {
      if (scores[c] > scores[best]) best = c;
    }
    return ModelPrediction(
      label: classes[best],
      probabilities: {
        for (var c = 0; c < classes.length; c++) classes[c]: exps[c] / total,
      },
      tokens: tokens,
      knownTermCount: weights.length,
      evidence: _evidence(weights, best),
    );
  }

  /// Ranks the terms by how much they favour class [best]: against Safe when
  /// the prediction is risky, and against the likelier risky class when the
  /// prediction is Safe.
  List<TermEvidence> _evidence(Map<int, double> weights, int best) {
    final safe = classes.indexOf(RiskLabel.safe);
    final evidence = <TermEvidence>[];
    for (final e in weights.entries) {
      final i = e.key;
      final double rival;
      if (best == safe) {
        rival = [
          for (var c = 0; c < classes.length; c++)
            if (c != safe) _featureLogProb[c][i],
        ].reduce(math.max);
      } else {
        rival = _featureLogProb[safe][i];
      }
      final weight = e.value * (_featureLogProb[best][i] - rival);
      if (weight > 0) evidence.add(TermEvidence(_terms[i], weight));
    }
    evidence.sort((a, b) => b.weight.compareTo(a.weight));
    return evidence;
  }
}
