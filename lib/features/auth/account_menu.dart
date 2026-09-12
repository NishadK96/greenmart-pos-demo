import 'package:flutter/material.dart' hide Text;
import 'package:eazy_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../cash_register/presentation/cash_register_controller.dart';
import '../store/app_store.dart';
import 'account_switch_dialog.dart';
import 'auth_controller.dart';

enum _AccountAction { switchUser, logout }

Future<void> showAccountMenu(BuildContext context, WidgetRef ref) async {
  final app = ref.read(appStoreProvider);
  final user = app.user;
  final compact = MediaQuery.sizeOf(context).width < 700;
  final Future<_AccountAction?> actionFuture;
  if (compact) {
    actionFuture = showModalBottomSheet<_AccountAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AccountMenuContent(
        name: user?.name ?? '',
        username: user?.username ?? '',
        isAdmin: user?.isAdmin ?? false,
      ),
    );
  } else {
    actionFuture = showDialog<_AccountAction>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _AccountMenuContent(
            name: user?.name ?? '',
            username: user?.username ?? '',
            isAdmin: user?.isAdmin ?? false,
          ),
        ),
      ),
    );
  }
  final action = await actionFuture;

  if (!context.mounted || action == null) return;
  switch (action) {
    case _AccountAction.switchUser:
      await showAccountSwitchDialog(context, ref);
    case _AccountAction.logout:
      await _confirmAndLogout(context, ref);
  }
}

Future<void> _confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final app = ref.read(appStoreProvider);
  final register = ref.read(cashRegisterControllerProvider).asData?.value;
  final hasWork = app.cart.isNotEmpty || app.heldCarts.isNotEmpty;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.logout_rounded, color: Color(0xFFC83D3D)),
      title: const Text('Log out of Eazy POS?'),
      content: Text(
        register != null
            ? 'Your register is still open. Logging out clears this device’s cart and held sales, but does not close the register.'
            : hasWork
            ? 'Logging out clears the current cart and held sales from this device.'
            : 'You will need to sign in again to continue using Eazy POS.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC83D3D),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(authControllerProvider.notifier).logout();
    ref.read(appStoreProvider.notifier).clearCashierContext();
    ref.invalidate(cashRegisterControllerProvider);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Unable to log out: $error')));
  }
}

class _AccountMenuContent extends StatelessWidget {
  const _AccountMenuContent({
    required this.name,
    required this.username,
    required this.isAdmin,
  });

  final String name;
  final String username;
  final bool isAdmin;

  String get initials {
    if (name.trim().isEmpty) return '?';
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.accent,
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Signed in user' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isAdmin ? 'Administrator' : 'Cashier',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 8),
        _AccountActionTile(
          icon: Icons.switch_account_outlined,
          title: 'Switch user',
          subtitle: 'Use another saved cashier account',
          onTap: () => Navigator.pop(context, _AccountAction.switchUser),
        ),
        _AccountActionTile(
          icon: Icons.logout_rounded,
          title: 'Log out',
          subtitle: 'End this session on this device',
          destructive: true,
          onTap: () => Navigator.pop(context, _AccountAction.logout),
        ),
      ],
    ),
  );
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFC83D3D) : AppColors.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: color),
      onTap: onTap,
    );
  }
}
