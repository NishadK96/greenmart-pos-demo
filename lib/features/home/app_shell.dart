import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:eazy_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';
import '../cash_register/domain/cash_register_entities.dart';
import '../cash_register/presentation/cash_register_controller.dart';
import '../cash_register/presentation/cash_register_dialog.dart';
import '../auth/account_menu.dart';
import '../store/app_store.dart';
import '../invoice_layouts/presentation/invoice_layout_controller.dart';

const destinations = [
  ('/pos', 'POS', Icons.point_of_sale_outlined),
  ('/dashboard', 'Dashboard', Icons.space_dashboard_outlined),
  ('/products', 'Products', Icons.inventory_2_outlined),
  ('/categories', 'Categories', Icons.category_outlined),
  ('/purchases', 'Purchases', Icons.shopping_cart_checkout),
  ('/inventory', 'Inventory', Icons.warehouse_outlined),
  ('/customers', 'Customers', Icons.people_outline),
  ('/sales', 'Sales', Icons.receipt_long_outlined),
  ('/reports', 'Reports', Icons.query_stats),
  ('/sync', 'Sync', Icons.sync),
  ('/zatca', 'ZATCA', Icons.verified_user_outlined),
  ('/settings', 'Settings', Icons.settings_outlined),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool expanded = true;
  bool sidebarInitialized = false;
  late final Timer timer;
  DateTime now = DateTime.now();
  @override
  void initState() {
    super.initState();
    _loadSidebarPreference();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  Future<void> _loadSidebarPreference() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getBool('eazy_pos_sidebar_expanded');
    if (!mounted || saved == null) return;
    setState(() {
      expanded = saved;
      sidebarInitialized = true;
    });
  }

  Future<void> _setExpanded(bool value) async {
    setState(() => expanded = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('eazy_pos_sidebar_expanded', value);
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  int index(String path) => destinations
      .indexWhere((e) => path.startsWith(e.$1))
      .clamp(0, destinations.length - 1);
  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStoreProvider);
    // Keep the selected ERP layout manifest and its authenticated assets warm
    // while online so provisional receipts remain available without a network.
    ref.watch(invoiceLayoutControllerProvider);
    final businessName = appState.business?.displayName(context.isArabic) ?? '';
    final userName = appState.user?.name ?? '';
    final locationName = appState.locations.isEmpty
        ? ''
        : appState.locations.first.name;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width > 1100;
    if (desktop && !sidebarInitialized) {
      expanded = width >= 1280;
      sidebarInitialized = true;
    }
    final path = GoRouterState.of(context).uri.path;
    final AsyncValue<CashRegister?> registerState = path == '/pos'
        ? ref.watch(cashRegisterControllerProvider)
        : const AsyncData(null);
    final register = registerState.asData?.value;
    final registerLabel = registerState.isLoading
        ? 'Register…'
        : register == null
        ? 'Open register'
        : 'Register ${register.id}';
    if (!desktop) {
      final mobile = [
        destinations[0],
        destinations[2],
        destinations[7],
        destinations[5],
        ('/settings', 'More', Icons.more_horiz),
      ];
      final phone = width < 700;
      final mobileIndex = mobile.indexWhere((e) => path.startsWith(e.$1));
      return Scaffold(
        key: scaffoldKey,
        drawer: _MobileNavigationDrawer(
          currentPath: path,
          businessName: businessName,
          userName: userName,
          onAccountTap: () => showAccountMenu(context, ref),
          onSelected: (destination) {
            Navigator.pop(context);
            context.go(destination);
          },
        ),
        appBar: phone
            ? PreferredSize(
                preferredSize: const Size.fromHeight(96),
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 5, 8, 6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE4EAE7)),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: context.tr('Menu'),
                              onPressed: () =>
                                  scaffoldKey.currentState?.openDrawer(),
                              icon: const Icon(Icons.menu_rounded),
                            ),
                            const _EazyPosIcon(size: 36, radius: 9),
                            const SizedBox(width: 8),
                            if (path == '/pos')
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      showCashRegisterDialog(context, ref),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 38),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          registerLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      businessName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      context.tr('Point of Sale'),
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 2),
                            IconButton(
                              tooltip: context.tr('Account menu'),
                              onPressed: () => showAccountMenu(context, ref),
                              icon: const Icon(Icons.account_circle_outlined),
                            ),
                            IconButton(
                              tooltip: context.tr('Notifications'),
                              onPressed: () {},
                              icon: const Icon(Icons.notifications_none),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            StatusBadge(context.tr('Online')),
                            const SizedBox(width: 7),
                            StatusBadge(context.tr('Synced')),
                            const Spacer(),
                            PopupMenuButton<String>(
                              tooltip: context.tr('Language'),
                              onSelected: (code) => ref
                                  .read(localeProvider.notifier)
                                  .setLanguage(code),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'en',
                                  child: Text('English'),
                                ),
                                PopupMenuItem(
                                  value: 'ar',
                                  child: Text('العربية'),
                                ),
                              ],
                              child: Row(
                                children: [
                                  const Icon(Icons.language, size: 16),
                                  const SizedBox(width: 5),
                                  Text(
                                    context.isArabic ? 'العربية' : 'English',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : AppBar(
                leading: IconButton(
                  tooltip: context.tr('Menu'),
                  onPressed: () => scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
                title: Text(
                  context.tr('Eazy POS'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.language),
                    onSelected: (code) =>
                        ref.read(localeProvider.notifier).setLanguage(code),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'en', child: Text('English')),
                      PopupMenuItem(value: 'ar', child: Text('العربية')),
                    ],
                  ),
                  StatusBadge(context.tr('Online')),
                  IconButton(
                    onPressed: () => context.go('/pos'),
                    icon: const Icon(Icons.add_shopping_cart),
                  ),
                ],
              ),
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          height: phone ? 60 : 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: mobileIndex < 0 ? 4 : mobileIndex,
          onDestinationSelected: (i) {
            if (i == 4) {
              scaffoldKey.currentState?.openDrawer();
            } else {
              context.go(mobile[i].$1);
            }
          },
          destinations: [
            for (final d in mobile)
              NavigationDestination(icon: Icon(d.$3), label: context.tr(d.$2)),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: expanded ? 244 : 82,
            color: AppColors.navy,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 18),
                    child: Row(
                      children: [
                        const _EazyPosIcon(size: 42, radius: 13),
                        if (expanded) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  businessName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  context.tr('Point of Sale'),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (expanded)
                          IconButton(
                            onPressed: () => _setExpanded(false),
                            icon: const Icon(
                              Icons.keyboard_double_arrow_left,
                              color: Colors.white54,
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                  if (!expanded)
                    IconButton(
                      onPressed: () => _setExpanded(true),
                      icon: const Icon(
                        Icons.keyboard_double_arrow_right,
                        color: Colors.white54,
                      ),
                    ),
                  if (expanded)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'WORKSPACE',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: [
                        for (int i = 0; i < destinations.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Tooltip(
                              message: destinations[i].$2,
                              child: Material(
                                color: i == index(path)
                                    ? const Color(0xFF245148)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(11),
                                  onTap: () => context.go(destinations[i].$1),
                                  child: SizedBox(
                                    height: 46,
                                    child: Row(
                                      children: [
                                        if (expanded)
                                          SizedBox(
                                            width: 58,
                                            child: Icon(
                                              destinations[i].$3,
                                              color: i == index(path)
                                                  ? Colors.white
                                                  : Colors.white54,
                                              size: 21,
                                            ),
                                          )
                                        else
                                          Expanded(
                                            child: Icon(
                                              destinations[i].$3,
                                              color: i == index(path)
                                                  ? Colors.white
                                                  : Colors.white54,
                                              size: 21,
                                            ),
                                          ),
                                        if (expanded)
                                          Text(
                                            context.tr(destinations[i].$2),
                                            style: TextStyle(
                                              color: i == index(path)
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontWeight: i == index(path)
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: InkWell(
                      onTap: () => showAccountMenu(context, ref),
                      borderRadius: BorderRadius.circular(13),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.accent,
                              child: Text(
                                userName.isEmpty
                                    ? '?'
                                    : userName
                                          .split(' ')
                                          .where((part) => part.isNotEmpty)
                                          .take(2)
                                          .map((part) => part[0])
                                          .join()
                                          .toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (expanded) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      context.tr('Administrator'),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.more_vert,
                                color: Colors.white38,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE7ECEA)),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (path == '/pos') ...[
                        OutlinedButton.icon(
                          onPressed: () => showCashRegisterDialog(context, ref),
                          icon: const Icon(
                            Icons.point_of_sale_rounded,
                            size: 17,
                          ),
                          label: Text(registerLabel),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: register == null
                                      ? const Color(0xFFB7791F)
                                      : const Color(0xFF15945B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  register == null
                                      ? 'Shift closed'
                                      : 'Shift open',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              register == null
                                  ? 'Open the register to start selling'
                                  : 'Cash register active',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          businessName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            locationName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: context.tr('Language'),
                        onSelected: (code) =>
                            ref.read(localeProvider.notifier).setLanguage(code),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'en',
                            child: Text('🇬🇧  ${context.tr('English')}'),
                          ),
                          PopupMenuItem(
                            value: 'ar',
                            child: Text('🇸🇦  ${context.tr('Arabic')}'),
                          ),
                        ],
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFDCE4E1)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.language, size: 17),
                              const SizedBox(width: 7),
                              Text(context.isArabic ? 'العربية' : 'English'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F7F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.tr('Online'),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              context.tr('Synced'),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (width >= 1320) ...[
                        const SizedBox(width: 14),
                        Text(
                          '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(width: 14),
                      FilledButton.icon(
                        onPressed: () => context.go('/pos'),
                        icon: const Icon(Icons.add),
                        label: Text(context.tr('New sale')),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: context.tr('Account menu'),
                        onPressed: () => showAccountMenu(context, ref),
                        icon: const Icon(Icons.account_circle_outlined),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Badge(
                          smallSize: 7,
                          child: Icon(Icons.notifications_none_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileNavigationDrawer extends StatelessWidget {
  const _MobileNavigationDrawer({
    required this.currentPath,
    required this.businessName,
    required this.userName,
    required this.onSelected,
    required this.onAccountTap,
  });

  final String currentPath;
  final String businessName;
  final String userName;
  final ValueChanged<String> onSelected;
  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) => Drawer(
    width: MediaQuery.sizeOf(context).width.clamp(280, 340).toDouble(),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
            child: Row(
              children: [
                const _EazyPosIcon(size: 46, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName.isEmpty ? 'Eazy POS' : businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        context.tr('All sections'),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final destination = destinations[index];
                final selected = currentPath.startsWith(destination.$1);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: ListTile(
                    selected: selected,
                    selectedTileColor: const Color(0xFFE1F1EC),
                    selectedColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(destination.$3),
                    title: Text(
                      context.tr(destination.$2),
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, size: 19)
                        : null,
                    onTap: () => onSelected(destination.$1),
                  ),
                );
              },
            ),
          ),
          if (userName.isNotEmpty) ...[
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF4A62A),
                child: Icon(Icons.person_outline, color: Colors.black87),
              ),
              title: Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(context.tr('Signed in user')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => onAccountTap(),
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}

class _EazyPosIcon extends StatelessWidget {
  const _EazyPosIcon({required this.size, required this.radius});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius - 2),
      child: Image.asset(
        'assets/branding/eazy_pos_icon.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    ),
  );
}
