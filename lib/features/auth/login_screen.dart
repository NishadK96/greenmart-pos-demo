import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool remember = true, obscure = true;
  final email = TextEditingController(text: 'demo@retailflow.app'),
      password = TextEditingController(text: 'password');
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Row(
              children: [
                if (MediaQuery.sizeOf(context).width >= 900)
                  Expanded(
                    child: Container(
                      height: 560,
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                          const Spacer(),
                          Text(
                            context.tr('Sell smarter.\nStay in control.'),
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.tr(
                              'Fast checkout, accurate stock, and an offline-first workflow for modern retail.',
                            ),
                            style: const TextStyle(
                              color: Color(0xFFD5E8E3),
                              fontSize: 17,
                              height: 1.5,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(Icons.offline_bolt, color: Colors.white70),
                              SizedBox(width: 8),
                              Text(
                                context.tr(
                                  'Ready even when the internet is not',
                                ),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(
                      MediaQuery.sizeOf(context).width >= 900 ? 48 : 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'RETAILFLOW',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'en', label: Text('EN')),
                                ButtonSegment(
                                  value: 'ar',
                                  label: Text('العربية'),
                                ),
                              ],
                              selected: {
                                Localizations.localeOf(context).languageCode,
                              },
                              onSelectionChanged: (value) => ref
                                  .read(localeProvider.notifier)
                                  .setLanguage(value.first),
                              showSelectedIcon: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          context.tr('Welcome back'),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('Sign in to open your store.'),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: email,
                          decoration: InputDecoration(
                            labelText: context.tr('Email or username'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            labelText: context.tr('Password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: remember,
                              onChanged: (v) =>
                                  setState(() => remember = v ?? false),
                            ),
                            Text(context.tr('Remember me')),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context.go('/dashboard'),
                          child: Text(context.tr('Sign in')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
