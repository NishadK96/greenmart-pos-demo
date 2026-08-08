import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';

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

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool expanded = true;
  late final Timer timer;
  DateTime now = DateTime.now();
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
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
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width > 1100;
    final path = GoRouterState.of(context).uri.path;
    if (!desktop) {
      final mobile = [
        destinations[0],
        destinations[1],
        destinations[5],
        destinations[7],
        ('/settings', 'More', Icons.more_horiz),
      ];
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'RetailFlow',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            const StatusBadge('Online'),
            IconButton(
              onPressed: () => context.go('/pos'),
              icon: const Icon(Icons.add_shopping_cart),
            ),
          ],
        ),
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: mobile
              .indexWhere((e) => path.startsWith(e.$1))
              .clamp(0, 4),
          onDestinationSelected: (i) => context.go(mobile[i].$1),
          destinations: [
            for (final d in mobile)
              NavigationDestination(icon: Icon(d.$3), label: d.$2),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          Container(
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
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GreenMart',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  'Point of Sale',
                                  style: TextStyle(
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
                            onPressed: () => setState(() => expanded = false),
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
                      onPressed: () => setState(() => expanded = true),
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
                                            destinations[i].$2,
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
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.accent,
                            child: Text(
                              'NK',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (expanded) ...[
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nishad',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Administrator',
                                    style: TextStyle(
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
                  height: 76,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Text(
                        'GreenMart',
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
                        child: const Text(
                          'MAIN STORE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const StatusBadge('● Online'),
                      const SizedBox(width: 8),
                      const StatusBadge('Synced'),
                      const SizedBox(width: 18),
                      Text(
                        '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                      ),
                      const SizedBox(width: 18),
                      FilledButton.icon(
                        onPressed: () => context.go('/pos'),
                        icon: const Icon(Icons.add),
                        label: const Text('New sale'),
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
