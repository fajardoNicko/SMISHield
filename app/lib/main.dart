import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app_controller.dart';
import 'data/accounts.dart';
import 'data/history.dart';
import 'data/json_store.dart';
import 'data/settings.dart';
import 'ml/model_loader.dart';
import 'ui/screens/auth_screens.dart';
import 'ui/screens/shell.dart';
import 'ui/theme.dart';
import 'ui/widgets/logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmishieldBootstrap());
}

/// Loads the stored data and the model, showing the logo meanwhile.
class SmishieldBootstrap extends StatefulWidget {
  const SmishieldBootstrap({super.key});

  @override
  State<SmishieldBootstrap> createState() => _SmishieldBootstrapState();
}

class _SmishieldBootstrapState extends State<SmishieldBootstrap> {
  late final Future<AppController> _ready = _load();

  static Future<AppController> _load() async {
    final directory = await getApplicationSupportDirectory();
    final store = JsonStore(directory);
    final controller = AppController(
      accounts: AccountRepository(store),
      history: HistoryRepository(store),
      settingsRepository: SettingsRepository(store),
      analyzer: await loadAnalyzer(),
    );
    await controller.load();
    return controller;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppController>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasData) return SmishieldApp(controller: snapshot.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(dark: true),
        home: Scaffold(
          backgroundColor: Palette.darkTop,
          body: Center(
            child: snapshot.hasError
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'SMISHield could not start: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SmishieldLogo(size: 140),
                      SizedBox(height: 24),
                      CircularProgressIndicator(),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}

class SmishieldApp extends StatelessWidget {
  const SmishieldApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        // A new navigator for every log-in and log-out, so no screen of the
        // previous session stays on the stack.
        key: ValueKey(controller.account?.id),
        title: 'SMISHield',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(dark: controller.darkMode),
        home: controller.account == null
            ? const LoginScreen()
            : const MainShell(),
      ),
    ),
  );
}
