import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../ml/analysis_result.dart';
import '../../ml/explanations.dart';
import '../../ml/risk_indicators.dart';
import '../../ml/risk_label.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/common.dart';
import 'menu_drawer.dart';

/// What the result page returns when it closes: the tab to show next, and
/// whether to clear the message box ("Check another message").
typedef ResultExit = ({AppTab tab, bool clearInput});

/// Figures 4-6: the classification, why, and what to do.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    final e = app.explanations;
    final style = RiskStyle.of(result.label);
    final isFinal = app.analyzer.model.info.isFinal;

    return AppBackground(
      flat: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        endDrawer: const MenuDrawer(),
        bottomNavigationBar: AppBottomNav(
          current: null,
          strings: s,
          onSelect: (tab) =>
              Navigator.of(context)
                  .pop<ResultExit>((tab: tab, clearInput: false)),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Builder(
                builder: (context) => PageHeader(
                  title: s.resultTitle,
                  backTooltip: s.back,
                  menuTooltip: s.menu,
                  onBack: () => Navigator.of(context).pop(),
                  onMenu: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: ContentPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelBanner(
                          result: result,
                          explanations: e,
                          style: style,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                          child: Text(
                            '${e.labelSummary(result.label)} ${s.confidence(result.confidence)}',
                            style: const TextStyle(
                              color: Palette.muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        _MessageCard(
                          result: result,
                          title: s.messageAnalyzed,
                          legend: s.highlightLegend,
                        ),
                        const SizedBox(height: 8),
                        _WhyBox(result: result, explanations: e, style: style),
                        if (result.label == RiskLabel.safe &&
                            result.indicators.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _IndicatorBox(
                            title: e.stillCheckTitle,
                            indicators: result.indicators,
                            explanations: e,
                            style: RiskStyle.of(RiskLabel.suspicious),
                          ),
                        ],
                        const SizedBox(height: 8),
                        InfoBox(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BoxTitle(
                                result.label == RiskLabel.safe
                                    ? s.staySafe
                                    : e.whatToDoTitle,
                              ),
                              for (final action in result.actions)
                                _Bullet(e.action(action)),
                            ],
                          ),
                        ),
                        if (!isFinal)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.science_outlined,
                                  size: 16,
                                  color: Palette.muted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    s.previewNote,
                                    style: const TextStyle(
                                      color: Palette.muted,
                                      fontSize: 11.5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                        PrimaryButton(
                          label: s.checkAnother,
                          icon: Icons.sync_alt_rounded,
                          color: Palette.royal,
                          height: 50,
                          onPressed: () => Navigator.of(context)
                              .pop<ResultExit>((
                                tab: AppTab.home,
                                clearInput: true,
                              )),
                        ),
                      ],
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

class _LabelBanner extends StatelessWidget {
  const _LabelBanner({
    required this.result,
    required this.explanations,
    required this.style,
  });

  final AnalysisResult result;
  final Explanations explanations;
  final RiskStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        '${explanations.labelTitle(result.label)}. ${explanations.labelHeadline(result.label)}',
    excludeSemantics: true,
    child: InfoBox(
      color: style.background,
      border: style.foreground.withValues(alpha: 0.25),
      child: Row(
        children: [
          Icon(style.icon, size: 60, color: style.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    explanations.labelTitle(result.label),
                    style: TextStyle(
                      color: style.foreground,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                Text(
                  explanations.labelHeadline(result.label),
                  style: const TextStyle(color: Palette.navy, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.result,
    required this.title,
    required this.legend,
  });

  final AnalysisResult result;
  final String title;
  final String legend;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Palette.info),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Palette.navy,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText.rich(
          TextSpan(
            style: const TextStyle(
              color: Color(0xFF1B2333),
              fontSize: 14,
              height: 1.45,
            ),
            children: _spans(result),
          ),
        ),
        if (result.highlights.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            legend,
            style: const TextStyle(color: Palette.muted, fontSize: 11.5),
          ),
        ],
      ],
    ),
  );

  static List<TextSpan> _spans(AnalysisResult result) {
    final text = result.message;
    final spans = <TextSpan>[];
    var at = 0;
    for (final h in result.highlights) {
      if (h.span.start > at) {
        spans.add(TextSpan(text: text.substring(at, h.span.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(h.span.start, h.span.end),
          style: _style(h),
        ),
      );
      at = h.span.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return spans;
  }

  static TextStyle _style(TextHighlight h) {
    if (h.isLearnedPattern) {
      return const TextStyle(
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: Palette.heading,
        decorationThickness: 2,
      );
    }
    final (background, foreground) = switch (indicatorSeverity[h.type]!) {
      Severity.high => (const Color(0xFFFFD3D7), const Color(0xFF8E1B24)),
      Severity.medium => (const Color(0xFFFFE6BF), const Color(0xFF7A4600)),
      Severity.low => (const Color(0xFFFFF2B3), const Color(0xFF5C4A00)),
    };
    return TextStyle(
      backgroundColor: background,
      color: foreground,
      fontWeight: FontWeight.w600,
    );
  }
}

class _BoxTitle extends StatelessWidget {
  const _BoxTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: Palette.heading,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(color: Palette.navy, fontSize: 14)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF1B2333), fontSize: 13.5),
          ),
        ),
      ],
    ),
  );
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF2A3346),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: const TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WhyBox extends StatelessWidget {
  const _WhyBox({
    required this.result,
    required this.explanations,
    required this.style,
  });

  final AnalysisResult result;
  final Explanations explanations;
  final RiskStyle style;

  @override
  Widget build(BuildContext context) {
    final e = explanations;
    if (result.label != RiskLabel.safe) {
      return _IndicatorBox(
        title: e.whyTitle(result.label),
        indicators: result.indicators,
        explanations: e,
        style: style,
        learnedTerms: result.learnedTerms,
      );
    }
    return InfoBox(
      color: style.background,
      border: style.foreground.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BoxTitle(e.whyTitle(result.label)),
          for (final check in result.passedChecks)
            _CheckRow(
              icon: Icons.check_circle,
              color: style.foreground,
              title: e.safeCheck(check),
            ),
        ],
      ),
    );
  }
}

class _IndicatorBox extends StatelessWidget {
  const _IndicatorBox({
    required this.title,
    required this.indicators,
    required this.explanations,
    required this.style,
    this.learnedTerms = const [],
  });

  final String title;
  final List<RiskIndicator> indicators;
  final Explanations explanations;
  final RiskStyle style;
  final List<String> learnedTerms;

  @override
  Widget build(BuildContext context) => InfoBox(
    color: style.background,
    border: style.foreground.withValues(alpha: 0.25),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BoxTitle(title),
        for (final indicator in indicators)
          _CheckRow(
            icon: Icons.cancel,
            color: style.foreground,
            title: explanations.indicatorTitle(indicator),
            detail: explanations.indicatorDetail(indicator),
          ),
        if (learnedTerms.isNotEmpty)
          _CheckRow(
            icon: Icons.text_fields_rounded,
            color: style.foreground,
            title: explanations.learnedTermsTitle,
            detail: learnedTerms.map((t) => '"$t"').join(', '),
          ),
      ],
    ),
  );
}
