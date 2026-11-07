import 'package:flutter/widgets.dart';

import '../data/accounts.dart';
import '../data/history.dart';
import '../data/settings.dart';
import '../ml/analysis_result.dart';
import '../ml/explanations.dart';
import '../ml/risk_label.dart';
import '../ml/smishield_analyzer.dart';
import 'strings.dart';

/// App-wide state: preferences, the logged-in account and its history, and
/// the on-device analyzer. Screens listen to it through [AppScope].
class AppController extends ChangeNotifier {
  AppController({
    required this.accounts,
    required this.history,
    required this.settingsRepository,
    required this.analyzer,
  });

  final AccountRepository accounts;
  final HistoryRepository history;
  final SettingsRepository settingsRepository;
  final SmishieldAnalyzer analyzer;

  Settings _settings = const Settings();
  Account? _account;
  List<HistoryEntry> _entries = const [];

  Settings get settings => _settings;
  bool get darkMode => _settings.darkMode;
  AppLanguage get language => _settings.language;
  Strings get strings => Strings(_settings.language);
  Explanations get explanations => Explanations(_settings.language);
  Account? get account => _account;
  List<HistoryEntry> get entries => _entries;

  int count(RiskLabel label) => _entries.where((e) => e.label == label).length;

  Future<void> load() async {
    _settings = await settingsRepository.load();
    final id = _settings.sessionAccountId;
    if (id != null) {
      _account = await accounts.byId(id);
      if (_account == null) {
        _settings = _settings.copyWith(sessionAccountId: () => null);
      } else {
        _entries = await history.list(id);
      }
    }
    notifyListeners();
  }

  Future<void> _updateSettings(Settings next) async {
    _settings = next;
    notifyListeners();
    await settingsRepository.save(next);
  }

  Future<void> setDarkMode(bool on) =>
      _updateSettings(_settings.copyWith(darkMode: on));

  Future<void> setLanguage(AppLanguage language) =>
      _updateSettings(_settings.copyWith(language: language));

  /// Creates the account without logging in yet, so the sign-up screen can
  /// show the recovery code first; then call [startSession].
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) => accounts.signUp(fullName: fullName, email: email, password: password);

  Future<void> logIn(String email, String password) async {
    await startSession(await accounts.logIn(email, password));
  }

  Future<void> startSession(Account account) async {
    _account = account;
    _entries = await history.list(account.id);
    await _updateSettings(
      _settings.copyWith(sessionAccountId: () => account.id),
    );
  }

  Future<void> logOut() async {
    _account = null;
    _entries = const [];
    await _updateSettings(_settings.copyWith(sessionAccountId: () => null));
  }

  /// Classifies [message]; saves it to the history unless [save] is false.
  /// Throws [AnalysisException] for input that cannot be classified.
  Future<AnalysisResult> analyze(String message, {bool save = true}) async {
    final result = analyzer.analyze(message);
    final account = _account;
    if (save && account != null) {
      await history.add(
        account.id,
        message: result.message,
        label: result.label,
        confidence: result.confidence,
        analyzedAt: result.analyzedAt,
      );
      _entries = await history.list(account.id);
      notifyListeners();
    }
    return result;
  }

  Future<void> removeEntry(HistoryEntry entry) async {
    final account = _account;
    if (account == null) return;
    await history.remove(account.id, entry.id);
    _entries = await history.list(account.id);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    final account = _account;
    if (account == null) return;
    await history.clear(account.id);
    _entries = const [];
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// For callbacks: reads the controller without rebuilding on changes.
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
