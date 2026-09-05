import 'package:flutter/material.dart' hide Text;
import 'package:retailflow_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../apis/api.dart';
import '../../core/theme/app_theme.dart';
import '../cash_register/presentation/cash_register_controller.dart';
import '../store/app_store.dart';
import 'auth_controller.dart';

Future<void> showAccountSwitchDialog(BuildContext context, WidgetRef ref) =>
    showDialog<void>(
      context: context,
      builder: (_) => const AccountSwitchDialog(),
    );

class AccountSwitchDialog extends ConsumerStatefulWidget {
  const AccountSwitchDialog({super.key});
  @override
  ConsumerState<AccountSwitchDialog> createState() =>
      _AccountSwitchDialogState();
}

class _AccountSwitchDialogState extends ConsumerState<AccountSwitchDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  List<SavedAccountSession> accounts = const [];
  bool loading = true;
  bool submitting = false;
  bool obscure = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      accounts = await ref
          .read(authControllerProvider.notifier)
          .savedAccounts();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<bool> _confirmContextReset() async {
    final app = ref.read(appStoreProvider);
    final register = ref.read(cashRegisterControllerProvider).asData?.value;
    if (app.cart.isEmpty && app.heldCarts.isEmpty && register == null)
      return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Switch cashier?'),
            content: Text(
              register != null
                  ? 'This cashier has an open register. The cart and held sales will be cleared from this device, but the register will remain assigned to the current cashier.'
                  : 'The current cart and held sales will be cleared from this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _switch(SavedAccountSession account) async {
    if (account.active || !await _confirmContextReset()) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .switchAccount(account.sessionId);
      ref.read(appStoreProvider.notifier).clearCashierContext();
      ref.invalidate(cashRegisterControllerProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) return;
    if (!await _confirmContextReset()) return;
    setState(() {
      submitting = true;
      error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .login(_username.text.trim(), _password.text, remember: true);
    if (result.isSuccess) {
      ref.read(appStoreProvider.notifier).clearCashierContext();
      ref.invalidate(cashRegisterControllerProvider);
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      setState(() {
        error = result.message ?? 'Unable to sign in to this account.';
        submitting = false;
      });
    }
  }

  Future<void> _remove(SavedAccountSession account) async {
    try {
      await ref
          .read(authControllerProvider.notifier)
          .removeAccount(account.sessionId);
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE4F2EE),
                    child: Icon(
                      Icons.switch_account_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Switch user',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Select a saved cashier or add another account.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (loading) const Center(child: CircularProgressIndicator()),
              if (!loading && accounts.isNotEmpty) ...[
                const Text(
                  'SIGNED-IN USERS',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = accounts[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          child: Text(
                            item.profile.name.isEmpty
                                ? '?'
                                : item.profile.name[0].toUpperCase(),
                          ),
                        ),
                        title: Text(
                          item.profile.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(item.profile.username),
                        trailing: item.active
                            ? const Chip(label: Text('Current'))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: submitting || item.expired
                                        ? null
                                        : () => _switch(item),
                                    child: Text(
                                      item.expired ? 'Sign in again' : 'Switch',
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: context.tr('Remove saved user'),
                                    onPressed: submitting
                                        ? null
                                        : () => _remove(item),
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
                ),
                const Divider(height: 28),
              ],
              const Text(
                'ADD ANOTHER USER',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                decoration: InputDecoration(
                  labelText: context.tr('Username'),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: obscure,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: context.tr('Password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submitting ? null : _login,
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Add and switch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
