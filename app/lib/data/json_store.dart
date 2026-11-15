import 'dart:convert';
import 'dart:io';

/// Small JSON documents kept in the app's private folder on the device.
/// Nothing is sent anywhere: the app has no internet permission.
class JsonStore {
  JsonStore(this.directory);

  final Directory directory;
  final Map<String, Future<void>> _pending = {};

  File _file(String name) => File('${directory.path}/$name.json');

  Future<Map<String, dynamic>?> read(String name) async {
    await _pending[name];
    final file = _file(name);
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    if (text.trim().isEmpty) return null;
    return jsonDecode(text) as Map<String, dynamic>;
  }

  /// Writes via a temporary file and a rename, so a crash mid-write never
  /// leaves a half-written document. Writes to one document run in order.
  Future<void> write(String name, Map<String, dynamic> data) =>
      _queue(name, () async {
        await directory.create(recursive: true);
        final temp = File('${directory.path}/$name.json.tmp');
        await temp.writeAsString(jsonEncode(data), flush: true);
        await temp.rename(_file(name).path);
      });

  Future<void> delete(String name) => _queue(name, () async {
    final file = _file(name);
    if (await file.exists()) await file.delete();
  });

  Future<void> _queue(String name, Future<void> Function() task) {
    final next = (_pending[name] ?? Future.value()).then((_) => task());
    _pending[name] = next.catchError((_) {});
    return next;
  }
}
