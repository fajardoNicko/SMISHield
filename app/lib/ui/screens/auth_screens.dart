import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../app/strings.dart';
import '../../data/accounts.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

/// Shared layout: logo and wordmark above a form card.
class _AuthLayout extends StatelessWidget {
  const _AuthLayout({required this.children, this.showBack = false});

  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.of(context).strings;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        const SmishieldLogo(size: 140),
                        const SizedBox(height: 6),
                        Wordmark(strings: strings),
                        const SizedBox(height: 22),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
              if (showBack)
                Positioned(
                  left: 4,
                  top: 4,
                  child: IconButton(
                    tooltip: strings.back,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: context.onPage,
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

class _FormTitle extends StatelessWidget {
  const _FormTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        color: context.onPage,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    final color = context.isDark
        ? const Color(0xFFFF8A8A)
        : const Color(0xFFB3261E);
    return message == null
        ? const SizedBox(height: 14)
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message!,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}

class _SwitchPrompt extends StatelessWidget {
  const _SwitchPrompt({
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        question,
        style: TextStyle(
          color: context.onPage,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text(
          action,
          style: const TextStyle(
            color: Palette.brandBlue,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  AuthError? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).logIn(_email.text, _password.text);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    return _AuthLayout(
      children: [
        OutlinedPanel(
          child: AutofillGroup(
            child: Column(
              children: [
                _FormTitle(s.login),
                LabeledField(
                  label: s.emailLabel,
                  hint: s.emailHint,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: s.passwordLabel,
                  hint: s.passwordHint,
                  controller: _password,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  toggleTooltip: _obscure ? s.showPassword : s.hidePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ResetPasswordScreen(),
                    ),
                  ),
                  child: Text(
                    s.forgotPassword,
                    style: const TextStyle(
                      color: Palette.brandBlue,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _ErrorText(_error == null ? null : s.authError(_error!)),
        PrimaryButton(label: s.login, onPressed: _submit, busy: _busy),
        const SizedBox(height: 22),
        _SwitchPrompt(
          question: s.newUser,
          action: s.signUp,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SignUpScreen())),
        ),
      ],
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  AuthError? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final controller = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await controller.signUp(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await showRecoveryCode(context, controller.strings, result.recoveryCode);
      await controller.startSession(result.account);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    return _AuthLayout(
      showBack: true,
      children: [
        OutlinedPanel(
          child: AutofillGroup(
            child: Column(
              children: [
                _FormTitle(s.signUp),
                LabeledField(
                  label: s.fullNameLabel,
                  hint: s.fullNameHint,
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: s.emailLabel,
                  hint: s.emailHint,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: s.passwordLabel,
                  hint: s.passwordHint,
                  helper: s.passwordRule,
                  controller: _password,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  toggleTooltip: _obscure ? s.showPassword : s.hidePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Text(
                  s.localAccountNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.onPage.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        _ErrorText(_error == null ? null : s.authError(_error!)),
        PrimaryButton(label: s.signUp, onPressed: _submit, busy: _busy),
        const SizedBox(height: 22),
        _SwitchPrompt(
          question: s.alreadyUser,
          action: s.login,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

/// Shows a recovery code with a copy button; returns when it is dismissed.
Future<void> showRecoveryCode(
  BuildContext context,
  Strings s,
  String code, {
  String? title,
  String? body,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    title: Text(
      title ?? s.recoveryTitle,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          body ?? s.recoveryBody,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Palette.info,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      color: Palette.navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_rounded, color: Palette.navy),
                onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(s.recoverySaved),
      ),
    ],
  ),
);

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  AuthError? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final controller = AppScope.read(context);
    final s = controller.strings;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await controller.accounts.resetPassword(
        email: _email.text,
        recoveryCode: _code.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await showRecoveryCode(
        context,
        s,
        code,
        title: s.resetDoneTitle,
        body: s.resetDoneBody,
      );
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    return _AuthLayout(
      showBack: true,
      children: [
        OutlinedPanel(
          child: Column(
            children: [
              _FormTitle(s.resetTitle),
              Text(
                s.resetIntro,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.onPage.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: s.emailLabel,
                hint: s.emailHint,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: s.recoveryCodeLabel,
                hint: s.recoveryCodeHint,
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: s.newPasswordLabel,
                hint: s.passwordHint,
                helper: s.passwordRule,
                controller: _password,
                obscure: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                toggleTooltip: _obscure ? s.showPassword : s.hidePassword,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        _ErrorText(_error == null ? null : s.authError(_error!)),
        PrimaryButton(label: s.resetButton, onPressed: _submit, busy: _busy),
      ],
    );
  }
}
