import 'dart:convert';
import 'dart:io';

import 'package:smishield/data/json_store.dart';

/// A [JsonStore] kept in memory, for widget tests (real file access does not
/// run inside the test's fake clock).
class MemoryStore extends JsonStore {
  MemoryStore() : super(Directory('unused'));

  final Map<String, String> documents = {};

  @override
  Future<Map<String, dynamic>?> read(String name) async {
    final text = documents[name];
    return text == null ? null : jsonDecode(text) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String name, Map<String, dynamic> data) async {
    documents[name] = jsonEncode(data);
  }

  @override
  Future<void> delete(String name) async {
    documents.remove(name);
  }
}
