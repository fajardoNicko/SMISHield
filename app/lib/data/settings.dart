import '../ml/explanations.dart';
import 'json_store.dart';

/// App preferences and who is logged in, kept on the device.
class Settings {
  const Settings({
    this.darkMode = true,
    this.language = AppLanguage.english,
    this.sessionAccountId,
  });

  factory Settings.fromJson(Map<String, dynamic>? json) => Settings(
    darkMode: json?['darkMode'] as bool? ?? true,
    language: AppLanguage.values.firstWhere(
      (l) => l.name == json?['language'],
      orElse: () => AppLanguage.english,
    ),
    sessionAccountId: json?['sessionAccountId'] as String?,
  );

  final bool darkMode;
  final AppLanguage language;

  /// The account that stays logged in until it logs out.
  final String? sessionAccountId;

  Settings copyWith({
    bool? darkMode,
    AppLanguage? language,
    String? Function()? sessionAccountId,
  }) => Settings(
    darkMode: darkMode ?? this.darkMode,
    language: language ?? this.language,
    sessionAccountId: sessionAccountId != null
        ? sessionAccountId()
        : this.sessionAccountId,
  );

  Map<String, dynamic> toJson() => {
    'darkMode': darkMode,
    'language': language.name,
    'sessionAccountId': sessionAccountId,
  };
}

class SettingsRepository {
  SettingsRepository(this.store);

  static const String _doc = 'settings';
  final JsonStore store;

  Future<Settings> load() async => Settings.fromJson(await store.read(_doc));

  Future<void> save(Settings settings) => store.write(_doc, settings.toJson());
}
