import 'package:flutter/material.dart' hide Text;
import 'package:retailflow_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../apis/api.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool remember = true;
  bool obscure = true;
  String? error;
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final username = email.text.trim();
    if (username.isEmpty || password.text.isEmpty) {
      setState(() => error = context.tr('Enter your username and password.'));
      return;
    }
    setState(() => error = null);
    final result = await ref
        .read(authControllerProvider.notifier)
        .login(username, password.text, remember: remember);
    if (!mounted) return;
    if (result.isSuccess) {
      context.go('/dashboard');
      return;
    }
    setState(() => error = _errorMessage(result));
  }

  String _errorMessage(LoginResult result) => switch (result.failure) {
    LoginFailure.invalidCredentials => context.tr(
      'The username or password is incorrect.',
    ),
    LoginFailure.network => context.tr(
      'Unable to reach the server. Check your connection.',
    ),
    _ =>
      result.message?.trim().isNotEmpty == true
          ? result.message!
          : context.tr('Login failed. Please try again.'),
  };

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    final size = MediaQuery.sizeOf(context);
    final showFeaturePanel = size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 760;
            final panelHeight = compactHeight ? 620.0 : 778.0;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width < 600 ? 18 : 40,
                vertical: compactHeight ? 24 : 84,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1435),
                  child: Container(
                    height: showFeaturePanel ? panelHeight : null,
                    constraints: showFeaturePanel
                        ? const BoxConstraints(minHeight: 620)
                        : const BoxConstraints(maxWidth: 620),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1C193C34),
                          blurRadius: 48,
                          offset: Offset(0, 20),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: showFeaturePanel
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(flex: 47, child: _FeaturePanel()),
                              Expanded(
                                flex: 53,
                                child: _buildLoginForm(loading),
                              ),
                            ],
                          )
                        : _buildLoginForm(loading),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginForm(bool loading) => _LoginForm(
    email: email,
    password: password,
    remember: remember,
    obscure: obscure,
    loading: loading,
    error: error,
    onRememberChanged: (value) => setState(() => remember = value),
    onObscureChanged: () => setState(() => obscure = !obscure),
    onSubmit: _submit,
  );
}

class _FeaturePanel extends StatelessWidget {
  const _FeaturePanel();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF005D50),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(74, 62, 74, 62),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/branding/eazy_pos_icon.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EAZY POS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr('Smart POS for your business'),
                    style: const TextStyle(
                      color: Color(0xFFB9D7D0),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(flex: 2),
          Text(
            context.tr('Run every sale\nwith confidence.'),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 49,
              height: 1.16,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Text(
              context.tr(
                'Check out customers faster, keep stock accurate, and continue selling even when the connection drops.',
              ),
              style: const TextStyle(
                color: Color(0xFFD6E8E4),
                fontSize: 18,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _BenefitPill(
                icon: Icons.point_of_sale_rounded,
                label: context.tr('Fast checkout'),
              ),
              _BenefitPill(
                icon: Icons.inventory_2_outlined,
                label: context.tr('Accurate stock'),
              ),
              _BenefitPill(
                icon: Icons.cloud_done_outlined,
                label: context.tr('Offline ready'),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 435,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF4C8B81)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.offline_bolt_rounded,
                    color: Color(0xFF087769),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    context.tr(
                      'Offline sales are saved and synced when you reconnect.',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

class _BenefitPill extends StatelessWidget {
  const _BenefitPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF0D6B5C),
      border: Border.all(color: const Color(0xFF3D8277)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 17),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _LoginForm extends ConsumerWidget {
  const _LoginForm({
    required this.email,
    required this.password,
    required this.remember,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onRememberChanged,
    required this.onObscureChanged,
    required this.onSubmit,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool remember;
  final bool obscure;
  final bool loading;
  final String? error;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onObscureChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final compact = MediaQuery.sizeOf(context).width < 480;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 66 : 28,
        vertical: wide ? 60 : 34,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: wide
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'EAZY POS',
                  style: TextStyle(
                    color: Color(0xFF087769),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
              _LanguageToggle(
                languageCode: Localizations.localeOf(context).languageCode,
                onChanged: (code) =>
                    ref.read(localeProvider.notifier).setLanguage(code),
              ),
            ],
          ),
          SizedBox(height: wide ? 60 : 42),
          Text(
            context.tr('Start your shift'),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: wide ? 43 : 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'Sign in to access your register, products, and sales for this location.',
            ),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 19,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 38),
          _LoginField(
            controller: email,
            enabled: !loading,
            label: context.tr('Email or username'),
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
          ),
          const SizedBox(height: 22),
          _LoginField(
            controller: password,
            enabled: !loading,
            label: context.tr('Password'),
            icon: Icons.lock_outline_rounded,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => loading ? null : onSubmit(),
            suffixIcon: IconButton(
              tooltip: obscure ? 'Show password' : 'Hide password',
              onPressed: onObscureChanged,
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: remember,
                      visualDensity: VisualDensity.compact,
                      onChanged: loading
                          ? null
                          : (value) => onRememberChanged(value ?? false),
                    ),
                    Text(context.tr('Remember this account')),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Password recovery will be connected with the backend.',
                        ),
                      ),
                    ),
                    child: Text(context.tr('Forgot password?')),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: remember,
                        visualDensity: VisualDensity.compact,
                        onChanged: loading
                            ? null
                            : (value) => onRememberChanged(value ?? false),
                      ),
                      Flexible(
                        child: Text(context.tr('Remember this account')),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Password recovery will be connected with the backend.',
                      ),
                    ),
                  ),
                  child: Text(context.tr('Forgot password?')),
                ),
              ],
            ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x3006A88A),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF087769),
                minimumSize: const Size.fromHeight(68),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              onPressed: loading ? null : onSubmit,
              child: loading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.tr('Continue to Eazy POS')),
            ),
          ),
          if (wide) ...[
            const Spacer(),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 21,
                    color: Color(0xFF6C8D85),
                  ),
                ),
                Flexible(
                  flex: 4,
                  child: Text(
                    'Secure access for your business and saved staff profiles.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.icon,
    required this.textInputAction,
    required this.autofillHints,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final IconData icon;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    obscureText: obscureText,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    onSubmitted: onSubmitted,
    style: const TextStyle(fontSize: 16),
    decoration: InputDecoration(
      hintText: label,
      labelText: null,
      prefixIcon: Icon(icon, size: 25),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      constraints: const BoxConstraints(minHeight: 76),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDDE4E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF087769), width: 1.5),
      ),
    ),
  );
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.languageCode, required this.onChanged});

  final String languageCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFCED8D5)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageOption(
          label: 'EN',
          selected: languageCode == 'en',
          onTap: () => onChanged('en'),
        ),
        _LanguageOption(
          label: 'العربية',
          selected: languageCode == 'ar',
          onTap: () => onChanged('ar'),
        ),
      ],
    ),
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF087769) : Colors.transparent,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
