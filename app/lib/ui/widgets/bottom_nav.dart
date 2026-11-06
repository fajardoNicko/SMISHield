import 'package:flutter/material.dart';

import '../../app/strings.dart';
import '../theme.dart';

enum AppTab { home, history, tips, profile }

/// The four-tab bar at the bottom of the mock-ups.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
    required this.strings,
  });

  /// Null when no tab is selected (e.g. on the result page).
  final AppTab? current;
  final ValueChanged<AppTab> onSelect;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final items = [
      (AppTab.home, Icons.home_rounded, strings.home),
      (AppTab.history, Icons.history_rounded, strings.history),
      (AppTab.tips, Icons.lightbulb_outline_rounded, strings.tips),
      (AppTab.profile, Icons.person_rounded, strings.profile),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: dark ? Palette.darkMiddle : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: dark
                ? Palette.darkBorder.withValues(alpha: 0.7)
                : Palette.info,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final (tab, icon, label) in items)
              Expanded(
                child: _NavItem(
                  icon: icon,
                  label: label,
                  selected: tab == current,
                  onTap: () => onSelect(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final idle = dark ? const Color(0xFFB9C3D3) : Palette.muted;
    final active = dark ? const Color(0xFF3D8BFF) : Palette.royal;
    final color = selected ? active : idle;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: dark && !selected ? Colors.white : color,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
