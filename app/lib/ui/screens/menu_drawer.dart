import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../ml/explanations.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _Item { about, darkMode, language, privacy, terms, clearHistory }

/// Figures 10-18: the side menu. Each item opens in place to show its
/// description and controls.
class MenuDrawer extends StatefulWidget {
  const MenuDrawer({super.key});

  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  _Item? _open;

  void _toggle(_Item item) =>
      setState(() => _open = _open == item ? null : item);

  Future<void> _clearHistory() async {
    final app = AppScope.read(context);
    final s = app.strings;
    final messenger = ScaffoldMessenger.of(context);
    if (app.entries.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(s.historyAlreadyEmpty)));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          s.clearConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(s.clearConfirmBody(app.entries.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62F3B),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.clear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.clearHistory();
    messenger.showSnackBar(SnackBar(content: Text(s.historyCleared)));
  }

  void _openDocument(String title, List<(String, String)> sections) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentScreen(title: title, sections: sections),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    final dark = context.isDark;
    final info = app.analyzer.model.info;
    const description = TextStyle(
      color: Colors.white,
      fontSize: 12.5,
      fontStyle: FontStyle.italic,
      height: 1.45,
    );

    return Drawer(
      backgroundColor: dark ? Palette.darkDrawer : Palette.lightDrawer,
      width: 300,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: IconButton(
                tooltip: s.menu,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [
                  _MenuButton(
                    icon: Icons.shield_outlined,
                    label: s.about,
                    expanded: _open == _Item.about,
                    onTap: () => _toggle(_Item.about),
                  ),
                  if (_open == _Item.about)
                    _Details(
                      children: [
                        Text(
                          s.aboutText,
                          textAlign: TextAlign.justify,
                          style: description.copyWith(
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.modelInfo(
                            info.trainingMessages ?? 0,
                            info.isFinal,
                            synthetic: info.syntheticMessages,
                          ),
                          style: description,
                        ),
                        Text(s.versionInfo, style: description),
                      ],
                    ),
                  _MenuButton(
                    icon: Icons.dark_mode_rounded,
                    label: s.darkModeLabel,
                    expanded: _open == _Item.darkMode,
                    onTap: () => _toggle(_Item.darkMode),
                    trailing: Switch(
                      value: app.darkMode,
                      onChanged: app.setDarkMode,
                      activeThumbColor: Palette.royal,
                      activeTrackColor: Colors.white,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Palette.royal,
                    ),
                  ),
                  if (_open == _Item.darkMode)
                    _Details(
                      children: [Text(s.darkModeText, style: description)],
                    ),
                  _MenuButton(
                    icon: Icons.language_rounded,
                    label: s.languageLabel,
                    expanded: _open == _Item.language,
                    onTap: () => _toggle(_Item.language),
                  ),
                  if (_open == _Item.language)
                    _Details(
                      children: [
                        Text(s.languageText, style: description),
                        RadioGroup<AppLanguage>(
                          groupValue: app.language,
                          onChanged: (value) {
                            if (value != null) app.setLanguage(value);
                          },
                          child: Column(
                            children: [
                              for (final (language, name) in [
                                (AppLanguage.english, 'English'),
                                (AppLanguage.filipino, 'Filipino'),
                              ])
                                RadioListTile<AppLanguage>(
                                  value: language,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  fillColor: const WidgetStatePropertyAll(
                                    Colors.white,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  _MenuButton(
                    icon: Icons.privacy_tip_outlined,
                    label: s.privacy,
                    expanded: _open == _Item.privacy,
                    onTap: () => _toggle(_Item.privacy),
                  ),
                  if (_open == _Item.privacy)
                    _Details(
                      children: [
                        Text(s.privacyText, style: description),
                        _LinkButton(
                          label: s.viewPolicy,
                          onTap: () =>
                              _openDocument(s.privacy, s.privacyPolicy),
                        ),
                      ],
                    ),
                  _MenuButton(
                    icon: Icons.gavel_rounded,
                    label: s.terms,
                    expanded: _open == _Item.terms,
                    onTap: () => _toggle(_Item.terms),
                  ),
                  if (_open == _Item.terms)
                    _Details(
                      children: [
                        Text(s.termsText, style: description),
                        _LinkButton(
                          label: s.viewTerms,
                          onTap: () =>
                              _openDocument(s.terms, s.termsAndConditions),
                        ),
                      ],
                    ),
                  _MenuButton(
                    icon: Icons.cleaning_services_rounded,
                    label: s.clearHistoryLabel,
                    expanded: _open == _Item.clearHistory,
                    onTap: () => _toggle(_Item.clearHistory),
                  ),
                  if (_open == _Item.clearHistory)
                    _Details(
                      children: [
                        Text(s.clearHistoryText, style: description),
                        _LinkButton(
                          label: s.clearHistoryButton,
                          onTap: _clearHistory,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  app.logOut();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 16,
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 26),
                label: Text(s.logOut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Material(
      color: Palette.royal,
      borderRadius: BorderRadius.circular(6),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Semantics(
          expanded: expanded,
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF9DBBE8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Colors.white70),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            decoration: TextDecoration.underline,
          ),
        ),
        child: Text(label),
      ),
    ),
  );
}

/// The privacy policy or the terms, opened from the menu.
class DocumentScreen extends StatelessWidget {
  const DocumentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    return AppBackground(
      flat: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              PageHeader(
                title: title,
                backTooltip: s.back,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: ContentPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (heading, body) in sections) ...[
                            Text(
                              heading,
                              style: const TextStyle(
                                color: Palette.heading,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: const TextStyle(
                                color: Color(0xFF2A3346),
                                fontSize: 13.5,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
