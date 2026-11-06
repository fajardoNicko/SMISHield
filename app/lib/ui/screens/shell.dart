import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../ml/analysis_result.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'menu_drawer.dart';
import 'result_screen.dart';
import 'tabs.dart';

/// The logged-in app: four tabs, the title bar and the side menu.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppTab _tab = AppTab.home;
  final _home = GlobalKey<HomeTabState>();

  void _select(AppTab tab) => setState(() => _tab = tab);

  Future<void> _openResult(AnalysisResult result) async {
    final exit = await Navigator.of(context).push<ResultExit>(
      MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
    );
    if (exit == null || !mounted) return;
    if (exit.clearInput) _home.currentState?.clear();
    _select(exit.tab);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    final title = switch (_tab) {
      AppTab.home => s.home,
      AppTab.history => s.history,
      AppTab.tips => s.tips,
      AppTab.profile => s.profile,
    };
    return PopScope(
      canPop: _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(AppTab.home);
      },
      child: AppBackground(
        flat: _tab != AppTab.home,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          endDrawer: const MenuDrawer(),
          bottomNavigationBar: AppBottomNav(
            current: _tab,
            onSelect: _select,
            strings: s,
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Builder(
                  builder: (context) => PageHeader(
                    title: title,
                    backTooltip: s.back,
                    menuTooltip: s.menu,
                    onBack: _tab == AppTab.home
                        ? null
                        : () => _select(AppTab.home),
                    onMenu: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tab.index,
                    children: [
                      HomeTab(key: _home, onResult: _openResult),
                      HistoryTab(onOpen: _openResult),
                      const TipsTab(),
                      const ProfileTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Figure 3: paste a message and analyse it.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onResult});

  final Future<void> Function(AnalysisResult result) onResult;

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  final _input = TextEditingController();
  bool _busy = false;
  AnalysisError? _error;

  void clear() {
    _input.clear();
    setState(() => _error = null);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppScope.read(context).strings.clipboardEmpty)),
      );
      return;
    }
    _input.text = text;
    setState(() => _error = null);
  }

  Future<void> _analyze() async {
    FocusScope.of(context).unfocus();
    final app = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // A short pause so the loading indicator is seen (research plan, C1).
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final result = await app.analyze(_input.text);
      if (!mounted) return;
      setState(() => _busy = false);
      await widget.onResult(result);
    } on AnalysisException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    final onPage = context.onPage;
    final dark = context.isDark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        children: [
          const SmishieldLogo(size: 128),
          const SizedBox(height: 4),
          Wordmark(strings: s, scale: 0.95),
          const SizedBox(height: 10),
          Text(
            s.homeIntro,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onPage.withValues(alpha: 0.8),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_rounded,
                      color: Palette.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.pasteHere,
                        style: TextStyle(
                          color: onPage,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _SmallAction(
                      icon: Icons.content_paste_rounded,
                      label: s.paste,
                      onTap: _paste,
                    ),
                    ListenableBuilder(
                      listenable: _input,
                      builder: (context, _) => _input.text.isEmpty
                          ? const SizedBox.shrink()
                          : _SmallAction(
                              icon: Icons.close_rounded,
                              label: s.clear,
                              onTap: clear,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _input,
                  minLines: 4,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(color: onPage, fontSize: 14),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? Palette.darkMiddle : Palette.lightField,
                    hintText: s.inputHint,
                    hintStyle: TextStyle(
                      color: onPage.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: dark
                            ? Palette.darkBorder.withValues(alpha: 0.6)
                            : Palette.info,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: dark
                            ? Palette.darkBorder.withValues(alpha: 0.6)
                            : Palette.info,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Palette.primary,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      app.explanations.error(_error!),
                      style: TextStyle(
                        color: dark
                            ? const Color(0xFFFFB4A9)
                            : const Color(0xFFB3261E),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: s.analyze,
                  onPressed: _analyze,
                  busy: _busy,
                  height: 44,
                ),
                if (_busy)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Text(
                        s.analyzing,
                        style: TextStyle(
                          color: onPage.withValues(alpha: 0.75),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.howItWorks,
            style: TextStyle(
              color: onPage,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Step(icon: Icons.sms_rounded, label: s.stepPaste),
              ),
              _chevron(context),
              Expanded(
                child: _Step(icon: Icons.search_rounded, label: s.stepAnalyze),
              ),
              _chevron(context),
              Expanded(
                child: _Step(
                  icon: Icons.verified_user_rounded,
                  label: s.stepResult,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chevron(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Icon(
      Icons.chevron_right_rounded,
      color: Palette.brandBlue,
      size: 28,
    ),
  );
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: context.isDark ? const Color(0xFF8DB8FF) : Palette.royal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 34),
      textStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    ),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedPanel(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
    child: Column(
      children: [
        Icon(icon, size: 38, color: Palette.brandBlue),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.onPage,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ],
    ),
  );
}
