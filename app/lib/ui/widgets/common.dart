import 'package:flutter/material.dart';

import '../theme.dart';

/// The gradient behind every screen: navy to black in dark mode, pale blue
/// in light mode. [flat] is the plainer navy used behind content pages.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.flat = false});

  final Widget child;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final colors = context.isDark
        ? (flat
              ? const [Palette.darkPage, Palette.darkPage]
              : const [Palette.darkTop, Palette.darkMiddle, Palette.darkBottom])
        : const [Palette.lightTop, Palette.lightBottom];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}

/// Outlined card used on the log-in, sign-up and home screens.
class OutlinedPanel extends StatelessWidget {
  const OutlinedPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.fromLTRB(14, 14, 14, 16),
    decoration: BoxDecoration(
      color: context.isDark
          ? Palette.darkCard.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: context.isDark
            ? Palette.darkBorder.withValues(alpha: 0.7)
            : Palette.info,
      ),
    ),
    child: child,
  );
}

/// The light rounded sheet that holds the content of inner pages.
class ContentPanel extends StatelessWidget {
  const ContentPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.isDark ? Palette.panel : Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

/// A tinted box inside a [ContentPanel].
class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.child,
    this.color = Palette.info,
    this.border,
  });

  final Widget child;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border ?? Colors.black.withValues(alpha: 0.06)),
    ),
    child: child,
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.color = Palette.primary,
    this.height = 46,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: height,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.6),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22),
                  const SizedBox(width: 10),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    ),
  );
}

/// A label above a rounded input, as in the log-in and sign-up mock-ups.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.onToggleObscure,
    this.toggleTooltip,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.helper,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? toggleTooltip;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? helper;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final textColor = dark ? Colors.white : Palette.navy;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: dark ? Palette.darkBorder.withValues(alpha: 0.7) : Palette.info,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          textCapitalization: textCapitalization,
          autocorrect: false,
          enableSuggestions: !obscure,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: dark ? Palette.darkMiddle : Palette.lightField,
            hintText: hint,
            hintStyle: TextStyle(
              color: textColor.withValues(alpha: 0.45),
              fontSize: 13,
            ),
            helperText: helper,
            helperStyle: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 11.5,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: Palette.primary, width: 1.6),
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    tooltip: toggleTooltip,
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Title bar of the inner pages: back arrow, centred title, menu button.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onMenu,
    this.backTooltip,
    this.menuTooltip,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final String? backTooltip;
  final String? menuTooltip;

  @override
  Widget build(BuildContext context) {
    final color = context.onPage;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: onBack == null
                ? null
                : IconButton(
                    tooltip: backTooltip,
                    onPressed: onBack,
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: color),
                  ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: onMenu == null
                ? null
                : IconButton(
                    tooltip: menuTooltip,
                    onPressed: onMenu,
                    icon: Icon(Icons.menu_rounded, color: color, size: 30),
                  ),
          ),
        ],
      ),
    );
  }
}
