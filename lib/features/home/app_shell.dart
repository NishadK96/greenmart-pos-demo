import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';
import '../store/app_store.dart';

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
  ('/settings', 'Settings', Icons.settings_outlined),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
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
    final saved = preferences.getBool('greenmart_sidebar_expanded');
    if (!mounted || saved == null) return;
    setState(() {
      expanded = saved;
      sidebarInitialized = true;
    });
  }

  Future<void> _setExpanded(bool value) async {
    setState(() => expanded = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('greenmart_sidebar_expanded', value);
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
    final businessName = appState.business?.name ?? '';
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
    if (!desktop) {
      final mobile = [
        destinations[0],
        destinations[2],
        destinations[7],
        destinations[5],
        ('/settings', 'More', Icons.more_horiz),
      ];
      final phone = width < 700;
      return Scaffold(
        appBar: phone
            ? PreferredSize(
                preferredSize: const Size.fromHeight(112),
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
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
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    businessName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    context.tr('Point of Sale'),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (path == '/pos')
                              OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 42),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Register 01'),
                                    SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down, size: 18),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Notifications',
                              onPressed: () {},
                              icon: const Icon(Icons.notifications_none),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
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
                title: Text(
                  context.tr('RetailFlow'),
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
          height: phone ? 66 : 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: mobile
              .indexWhere((e) => path.startsWith(e.$1))
              .clamp(0, 4),
          onDestinationSelected: (i) => context.go(mobile[i].$1),
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
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.navy,
                          ),
                        ),
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
                          onPressed: () {},
                          icon: const Icon(
                            Icons.point_of_sale_rounded,
                            size: 17,
                          ),
                          label: const Text('Register 01'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Color(0xFF15945B),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Shift Open',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '09:00 AM - 09:00 PM',
                              style: TextStyle(
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
