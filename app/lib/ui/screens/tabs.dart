import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../data/history.dart';
import '../../ml/analysis_result.dart';
import '../../ml/risk_label.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Figure 7: past analyses, newest first. Tap one to see its full result.
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key, required this.onOpen});

  final Future<void> Function(AnalysisResult result) onOpen;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    final entries = app.entries;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: ContentPanel(
        child: Column(
          children: [
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              size: 56,
                              color: Palette.info,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.historyEmpty,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Palette.muted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _HistoryCard(
                        entry: entries[i],
                        onTap: () async {
                          // Re-run the analysis for the full explanation.
                          final AnalysisResult result;
                          try {
                            result = await app.analyze(
                              entries[i].message,
                              save: false,
                            );
                          } on AnalysisException {
                            return;
                          }
                          await onOpen(result);
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            InfoBox(
              child: Row(
                children: [
                  const Icon(
                    Icons.health_and_safety_rounded,
                    color: Palette.tipIcon,
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.historyPrivacy,
                      style: const TextStyle(
                        color: Palette.heading,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    final style = RiskStyle.of(entry.label);
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFC62F3B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              s.delete,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        app.removeEntry(entry);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.entryDeleted)));
      },
      child: Material(
        color: style.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: style.foreground.withValues(alpha: 0.25)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                Icon(style.icon, size: 46, color: style.foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                app.explanations.labelTitle(entry.label),
                                style: TextStyle(
                                  color: style.foreground,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${s.date(entry.analyzedAt)}\n${s.time(entry.analyzedAt)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Color(0xFF2A3346),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        entry.message.replaceAll(RegExp(r'\s+'), ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2A3346),
                          fontSize: 13,
                        ),
                      ),
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

/// Figure 8: how to stay safe from smishing.
class TipsTab extends StatelessWidget {
  const TipsTab({super.key});

  static const _icons = [
    Icons.link_rounded,
    Icons.lock_rounded,
    Icons.notifications_active_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: ContentPanel(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                s.tipsTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Palette.tipIcon,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final (i, (title, body)) in s.tipItems.indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Palette.tipIcon,
                      child: Icon(
                        _icons[i % _icons.length],
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Palette.tipIcon,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          Text(
                            body,
                            style: const TextStyle(
                              color: Color(0xFF3D5A87),
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            InfoBox(
              child: Text(
                s.tipsFooter,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Palette.tipIcon,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figure 9: the account and how many messages it has analysed.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    final account = app.account;
    if (account == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 62),
            child: ContentPanel(
              child: Column(
                children: [
                  const SizedBox(height: 64),
                  Text(
                    account.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Palette.heading,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    account.email,
                    style: const TextStyle(
                      color: Palette.heading,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    s.memberSince(s.date(account.createdAt)),
                    style: const TextStyle(
                      color: Color(0xFF2A3346),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StatRow(
                    color: Palette.info,
                    count: app.entries.length,
                    child: Text(
                      s.messagesAnalyzed,
                      style: const TextStyle(
                        color: Palette.heading,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final label in RiskLabel.values)
                    _StatRow(
                      color: RiskStyle.of(label).background,
                      border: RiskStyle.of(label).foreground
                          .withValues(alpha: 0.25),
                      count: app.count(label),
                      child: Row(
                        children: [
                          Icon(
                            RiskStyle.of(label).icon,
                            color: RiskStyle.of(label).foreground,
                            size: 36,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                app.explanations.labelTitle(label),
                                style: TextStyle(
                                  color: RiskStyle.of(label).foreground,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => AppScope.read(context).logOut(),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Palette.info,
                        foregroundColor: Palette.heading,
                        side: BorderSide(
                          color: Palette.heading.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(s.logOut),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const CircleAvatar(
            radius: 64,
            backgroundColor: Palette.tipIcon,
            child: Icon(Icons.person_rounded, size: 100, color: Palette.panel),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.color,
    required this.count,
    required this.child,
    this.border,
  });

  final Color color;
  final Color? border;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: InfoBox(
      color: color,
      border: border,
      child: Row(
        children: [
          Expanded(child: child),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(
              color: Palette.heading,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
