import '../ml/risk_label.dart';
import 'json_store.dart';

/// One saved analysis: the message, its classification and when it was made.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.message,
    required this.label,
    required this.confidence,
    required this.analyzedAt,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    message: json['message'] as String,
    label: RiskLabel.fromModelName(json['label'] as String),
    confidence: (json['confidence'] as num).toDouble(),
    analyzedAt: DateTime.parse(json['analyzedAt'] as String),
  );

  final String id;
  final String message;
  final RiskLabel label;
  final double confidence;
  final DateTime analyzedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
    'label': label.modelName,
    'confidence': confidence,
    'analyzedAt': analyzedAt.toIso8601String(),
  };
}

/// Each account's analysis history, stored on the device only.
class HistoryRepository {
  HistoryRepository(this.store);

  final JsonStore store;

  String _doc(String accountId) => 'history_$accountId';

  /// Newest first.
  Future<List<HistoryEntry>> list(String accountId) async {
    final data = await store.read(_doc(accountId));
    final entries = [
      for (final e in (data?['entries'] as List?) ?? const [])
        HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    entries.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
    return entries;
  }

  Future<HistoryEntry> add(
    String accountId, {
    required String message,
    required RiskLabel label,
    required double confidence,
    required DateTime analyzedAt,
  }) async {
    final entries = await list(accountId);
    final entry = HistoryEntry(
      id: '${analyzedAt.microsecondsSinceEpoch}',
      message: message,
      label: label,
      confidence: confidence,
      analyzedAt: analyzedAt,
    );
    await _save(accountId, [entry, ...entries]);
    return entry;
  }

  Future<void> remove(String accountId, String entryId) async {
    final entries = await list(accountId);
    await _save(accountId, entries.where((e) => e.id != entryId).toList());
  }

  Future<void> clear(String accountId) => store.delete(_doc(accountId));

  Future<void> _save(String accountId, List<HistoryEntry> entries) =>
      store.write(_doc(accountId), {
        'version': 1,
        'entries': [for (final e in entries) e.toJson()],
      });
}
