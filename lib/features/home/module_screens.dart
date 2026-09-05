import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'package:retailflow_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../apis/api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/utils/pdf_fonts.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/ui.dart';
import '../store/app_store.dart';
import '../backend/presentation/backend_controller.dart';
import '../printers/application/printer_controller.dart';
import '../zatca/presentation/zatca_screen.dart';
import '../invoice_layouts/presentation/invoice_layout_controller.dart';
import '../cash_register/presentation/cash_register_controller.dart';
import '../offline_pos/presentation/offline_pos_controller.dart';

final saleReturnsProvider = FutureProvider.autoDispose<List<SaleReturnRecord>>(
  (ref) => ref.watch(backendControllerProvider.notifier).saleReturns(),
);

Future<bool?> showSaleReturnDialog(BuildContext context, Sale sale) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SaleReturnDialog(sale: sale),
    );

class PagePad extends StatelessWidget {
  const PagePad({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(20), child: child);
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStoreProvider);
    final now = DateTime.now();
    final today = state.sales
        .where((sale) => _sameDay(sale.createdAt, now))
        .toList();
    final todaySales = today.fold<int>(0, (sum, sale) => sum + sale.total);
    final lowStock =
        state.products
            .where((product) => product.stock <= product.minimumStock)
            .toList()
          ..sort((a, b) => a.stock.compareTo(b.stock));

    return PagePad(
      child: ListView(
        children: [
          _DashboardHero(state: state),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: constraints.maxWidth > 1120
                  ? 6
                  : constraints.maxWidth > 720
                  ? 3
                  : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: constraints.maxWidth > 1120 ? 1.7 : 1.85,
              children: [
                _DashboardMetric(
                  label: "Today's sales",
                  amount: todaySales,
                  detail: 'Today',
                  icon: Icons.trending_up_rounded,
                  tint: const Color(0xFF16885F),
                ),
                _DashboardMetric(
                  label: 'Transactions',
                  value: '${today.length}',
                  detail: 'Completed today',
                  icon: Icons.receipt_long_outlined,
                  tint: const Color(0xFF2679B8),
                ),
                _DashboardMetric(
                  label: 'Gross profit',
                  amount: state.profitLoss?.grossProfit ?? 0,
                  detail: 'Current period',
                  icon: Icons.savings_outlined,
                  tint: AppColors.primary,
                ),
                _DashboardMetric(
                  label: 'Low stock',
                  value: '${lowStock.length}',
                  detail: 'View details',
                  icon: Icons.warning_amber_rounded,
                  tint: const Color(0xFFE97324),
                  onTap: () => context.go('/inventory'),
                ),
                _DashboardMetric(
                  label: 'Expenses',
                  amount: state.profitLoss?.totalExpenses ?? 0,
                  detail: 'View details',
                  icon: Icons.payments_outlined,
                  tint: AppColors.primary,
                  onTap: () => context.go('/reports'),
                ),
                _DashboardMetric(
                  label: 'Total purchases',
                  amount: state.profitLoss?.totalPurchases ?? 0,
                  detail: 'View details',
                  icon: Icons.local_shipping_outlined,
                  tint: const Color(0xFF7650C8),
                  onTap: () => context.go('/purchases'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final recent = _DashboardListPanel(
                title: 'Recent sales',
                icon: Icons.receipt_long_outlined,
                onViewAll: () => context.go('/sales'),
                child: state.sales.isEmpty
                    ? const EmptyState('No sales yet')
                    : Column(
                        children: state.sales
                            .take(5)
                            .map(
                              (sale) => _SaleRow(
                                sale: sale,
                                onTap: () => context.go('/sales'),
                              ),
                            )
                            .toList(),
                      ),
              );
              final stock = _DashboardListPanel(
                title: 'Low stock',
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFE97324),
                onViewAll: () => context.go('/inventory'),
                child: lowStock.isEmpty
                    ? const EmptyState('Stock levels look good')
                    : Column(
                        children: lowStock
                            .take(5)
                            .map((product) => _LowStockRow(product: product))
                            .toList(),
                      ),
              );
              if (constraints.maxWidth <= 820) {
                return Column(
                  children: [recent, const SizedBox(height: 14), stock],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 11, child: recent),
                    const SizedBox(width: 14),
                    Expanded(flex: 10, child: stock),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = <Widget>[
                _SalesOverviewCard(sales: state.sales),
                _TopProductsCard(sales: state.sales),
                _PaymentMethodsCard(sales: state.sales),
              ];
              if (constraints.maxWidth <= 1000) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i < cards.length - 1) const SizedBox(height: 14),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i < cards.length - 1) const SizedBox(width: 14),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 20 : 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C493F), Color(0xFF07362F)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2410231F),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(
                context.tr('Store open'),
                color: const Color(0xFF4ED49A),
              ),
              const SizedBox(height: 17),
              Text(
                '${context.tr('Good morning')}, ${state.user?.name ?? ''} 👋',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('Your store is on track. Here’s today at a glance.'),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeroAction(
                label: 'New sale',
                icon: Icons.point_of_sale_outlined,
                strong: true,
                onTap: () => context.go('/pos'),
              ),
              const SizedBox(width: 10),
              _HeroAction(
                label: 'Inventory',
                icon: Icons.inventory_2_outlined,
                onTap: () => context.go('/inventory'),
              ),
              const SizedBox(width: 10),
              _HeroAction(
                label: 'Reports',
                icon: Icons.bar_chart_rounded,
                onTap: () => context.go('/reports'),
              ),
            ],
          );
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _HeroAction(
                        label: 'New sale',
                        icon: Icons.point_of_sale_outlined,
                        strong: true,
                        compact: true,
                        onTap: () => context.go('/pos'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroAction(
                        label: 'Inventory',
                        icon: Icons.inventory_2_outlined,
                        compact: true,
                        onTap: () => context.go('/inventory'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroAction(
                        label: 'Reports',
                        icon: Icons.bar_chart_rounded,
                        compact: true,
                        onTap: () => context.go('/reports'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: intro),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.strong = false,
    this.compact = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool strong;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: strong ? AppColors.accent : Colors.white.withValues(alpha: .09),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 18,
          vertical: compact ? 12 : 15,
        ),
        child: Column(
          children: [
            Icon(icon, color: strong ? AppColors.navy : Colors.white),
            const SizedBox(height: 6),
            Text(
              context.tr(label),
              style: TextStyle(
                color: strong ? AppColors.navy : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.detail,
    required this.icon,
    required this.tint,
    this.onTap,
    this.value,
    this.amount,
  });
  final String label, detail;
  final String? value;
  final int? amount;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.all(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: .11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                if (amount != null)
                  RiyalAmount(
                    amount!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  )
                else
                  Text(
                    value ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                Text(
                  context.tr(detail),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onTap == null ? AppColors.muted : AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
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

class _DashboardListPanel extends StatelessWidget {
  const _DashboardListPanel({
    required this.title,
    required this.icon,
    required this.onViewAll,
    required this.child,
    this.iconColor = AppColors.primary,
  });
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onViewAll;
  final Widget child;

  @override
  Widget build(BuildContext context) => Surface(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 11),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: iconColor.withValues(alpha: .1),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.tr(title),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: onViewAll,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 33),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                ),
                child: Text(context.tr('View all')),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        child,
      ],
    ),
  );
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, required this.onTap});
  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECEA))),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFE3F3EE),
            child: Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.invoiceNo,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  sale.customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${sale.createdAt.hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 78,
            child: RiyalAmount(
              sale.total,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    ),
  );
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 58),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE8ECEA))),
    ),
    child: Row(
      children: [
        SizedBox(width: 38, height: 38, child: ProductImage(product.imageUrl)),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.displayName(context.isArabic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${context.tr('Minimum')} ${product.minimumStock}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        StatusBadge('${product.stock} left', color: AppColors.danger),
      ],
    ),
  );
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr(title),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDDE4E1)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.tr('This week'),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _SalesOverviewCard extends StatelessWidget {
  const _SalesOverviewCard({required this.sales});
  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final values = List<int>.generate(7, (index) {
      final day = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index));
      return sales
          .where(
            (sale) =>
                sale.createdAt.year == day.year &&
                sale.createdAt.month == day.month &&
                sale.createdAt.day == day.day,
          )
          .fold<int>(0, (sum, sale) => sum + sale.total);
    });
    return _AnalyticsCard(
      title: 'Sales overview',
      child: SizedBox(
        height: 145,
        child: CustomPaint(painter: _SalesLinePainter(values)),
      ),
    );
  }
}

class _SalesLinePainter extends CustomPainter {
  const _SalesLinePainter(this.values);
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFE8ECEA);
    for (var i = 0; i < 4; i++) {
      final y = 8 + (size.height - 20) * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final maximum = math.max(1, values.fold<int>(0, math.max));
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - 12 - (size.height - 28) * values[i] / maximum;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SalesLinePainter oldDelegate) =>
      oldDelegate.values != values;
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.sales});
  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    final totals = <String, ({Product product, int value})>{};
    for (final sale in sales) {
      for (final line in sale.items) {
        final current = totals[line.product.id];
        totals[line.product.id] = (
          product: line.product,
          value: (current?.value ?? 0) + line.total,
        );
      }
    }
    final rows = totals.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maximum = rows.isEmpty ? 1 : math.max(1, rows.first.value);
    return _AnalyticsCard(
      title: 'Top selling products',
      child: SizedBox(
        height: 145,
        child: rows.isEmpty
            ? const EmptyState('No sales yet')
            : Column(
                children: rows.take(3).map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: ProductImage(row.product.imageUrl),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.product.displayName(context.isArabic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    money(row.value),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: row.value / maximum,
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(10),
                                backgroundColor: const Color(0xFFE7ECEA),
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  const _PaymentMethodsCard({required this.sales});
  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    for (final sale in sales) {
      totals.update(
        sale.paymentMethod,
        (value) => value + sale.total,
        ifAbsent: () => sale.total,
      );
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = math.max(
      1,
      entries.fold<int>(0, (sum, item) => sum + item.value),
    );
    const colors = [
      AppColors.primary,
      Color(0xFF4E7EB8),
      Color(0xFF66C4A4),
      AppColors.accent,
    ];
    return _AnalyticsCard(
      title: 'Payment methods',
      child: SizedBox(
        height: 145,
        child: entries.isEmpty
            ? const EmptyState('No payments yet')
            : Row(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CustomPaint(
                      painter: _DonutPainter(
                        values: entries.map((entry) => entry.value).toList(),
                        colors: colors,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < math.min(entries.length, 4); i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colors[i],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr(entries[i].key),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                Text(
                                  '${(entries[i].value * 100 / total).round()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
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
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = math.max(1, values.fold<int>(0, (sum, value) => sum + value));
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.pi * 2 * values[i] / total;
      canvas.drawArc(
        (Offset.zero & size).deflate(12),
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values;
}

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  final _minStockController = TextEditingController();
  final _maxStockController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  String query = '';
  String categoryId = 'all';
  String status = 'all';
  String sortBy = 'name';
  bool onlyActive = false;
  int page = 0;
  static const pageSize = 9;

  @override
  void dispose() {
    _searchController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final normalizedQuery = query.trim().toLowerCase();
    final minStock = int.tryParse(_minStockController.text);
    final maxStock = int.tryParse(_maxStockController.text);
    final minPrice = double.tryParse(_minPriceController.text);
    final maxPrice = double.tryParse(_maxPriceController.text);
    final rows = s.products.where((product) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          product.name.toLowerCase().contains(normalizedQuery) ||
          product.nameEn.toLowerCase().contains(normalizedQuery) ||
          product.nameAr.toLowerCase().contains(normalizedQuery) ||
          product.sku.toLowerCase().contains(normalizedQuery) ||
          product.barcode.toLowerCase().contains(normalizedQuery);
      final matchesCategory =
          categoryId == 'all' || product.categoryId == categoryId;
      final matchesStatus = switch (status) {
        'active' => product.active,
        'inactive' => !product.active,
        'low' => product.stock > 0 && product.stock <= product.minimumStock,
        'out' => product.stock <= 0,
        _ => true,
      };
      final matchesStock =
          (minStock == null || product.stock >= minStock) &&
          (maxStock == null || product.stock <= maxStock);
      final matchesPrice =
          (minPrice == null || product.sellingPrice >= minPrice) &&
          (maxPrice == null || product.sellingPrice <= maxPrice);
      return matchesQuery &&
          matchesCategory &&
          matchesStatus &&
          matchesStock &&
          matchesPrice &&
          (!onlyActive || product.active);
    }).toList();
    rows.sort(switch (sortBy) {
      'price_low' => (a, b) => a.sellingPrice.compareTo(b.sellingPrice),
      'price_high' => (a, b) => b.sellingPrice.compareTo(a.sellingPrice),
      'stock_low' => (a, b) => a.stock.compareTo(b.stock),
      _ =>
        (a, b) => a
            .displayName(context.isArabic)
            .toLowerCase()
            .compareTo(b.displayName(context.isArabic).toLowerCase()),
    });
    final totalPages = rows.isEmpty ? 1 : (rows.length / pageSize).ceil();
    final safePage = page.clamp(0, totalPages - 1);
    final start = safePage * pageSize;
    final visibleRows = rows.skip(start).take(pageSize).toList(growable: false);
    final lowStock = s.products
        .where(
          (product) =>
              product.stock > 0 && product.stock <= product.minimumStock,
        )
        .length;
    final outOfStock = s.products.where((product) => product.stock <= 0).length;
    final stockValue = s.products.fold<int>(
      0,
      (value, product) =>
          value +
          (product.purchasePrice * (product.stock > 0 ? product.stock : 0)),
    );
    final mobile = MediaQuery.sizeOf(context).width < 700;

    final productGrid = _productGrid(rows, visibleRows);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PageTitle(
                  'Products',
                  subtitle: 'Manage pricing, stock and barcodes.',
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => context.go('/products/create'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.tr('New product')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          )
        else
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const PageTitle(
                'Products',
                subtitle: 'Manage pricing, stock and barcodes.',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/products/import'),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(context.tr('Import')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/products/bulk'),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: Text(context.tr('Bulk update')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/products/quick'),
                    icon: const Icon(Icons.bolt_outlined),
                    label: Text(context.tr('Quick add')),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/products/create'),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr('New product')),
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = mobile
                ? 4
                : constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            final cardWidth =
                (constraints.maxWidth - ((columns - 1) * 10)) / columns;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: cardWidth / (mobile ? 86 : 72),
              children: [
                _productMetric(
                  'Total Products',
                  '${s.products.length}',
                  Icons.inventory_2_outlined,
                  AppColors.primary,
                ),
                _productMetric(
                  'Low Stock',
                  '$lowStock',
                  Icons.warning_amber_rounded,
                  const Color(0xFFD88900),
                ),
                _productMetric(
                  'Out of Stock',
                  '$outOfStock',
                  Icons.remove_shopping_cart_outlined,
                  AppColors.danger,
                ),
                _productMetric(
                  'Total Stock Value',
                  money(stockValue),
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFF286B9B),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Surface(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final search = TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {
                  query = value;
                  page = 0;
                }),
                decoration: InputDecoration(
                  hintText: context.tr('Search name, SKU or barcode'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.tr('Clear search'),
                          onPressed: () => setState(() {
                            _searchController.clear();
                            query = '';
                            page = 0;
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              );
              final filters = Row(
                children: [
                  Expanded(child: _categoryFilter(s)),
                  const SizedBox(width: 8),
                  Expanded(child: _statusFilter()),
                ],
              );
              if (mobile) {
                return Column(
                  children: [
                    search,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _mobileFilterButton(
                            Icons.category_outlined,
                            categoryId == 'all'
                                ? 'Categories'
                                : _categoryName(s),
                            () => _showMobileFilters(s),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _mobileFilterButton(
                            Icons.check_circle_outline,
                            status == 'all' ? 'Status' : _statusName(status),
                            () => _showMobileFilters(s),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _mobileFilterButton(
                            Icons.filter_alt_outlined,
                            'Filters',
                            () => _showMobileFilters(s),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return compact
                  ? Column(
                      children: [search, const SizedBox(height: 9), filters],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 3, child: search),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: filters),
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (mobile)
          SizedBox(
            height: rows.isEmpty
                ? 180
                : (((visibleRows.length / 2).ceil() * 222) - 12).toDouble(),
            child: productGrid,
          )
        else
          Expanded(child: productGrid),
        const SizedBox(height: 12),
        _pagination(rows.length, safePage, totalPages, mobile: mobile),
      ],
    );

    return Padding(
      padding: EdgeInsets.all(mobile ? 12 : 20),
      child: mobile ? SingleChildScrollView(child: content) : content,
    );
  }

  Widget _productGrid(List<Product> rows, List<Product> visibleRows) {
    if (rows.isEmpty) {
      return const EmptyState('No products match these filters');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = MediaQuery.sizeOf(context).width < 700;
        final columns = mobile
            ? 2
            : constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 580
            ? 2
            : 1;
        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: MediaQuery.sizeOf(context).width < 700
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: visibleRows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: mobile ? 210 : (columns == 1 ? 178 : 160),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, index) => mobile
              ? _mobileProductCard(visibleRows[index])
              : _productCard(visibleRows[index]),
        );
      },
    );
  }

  Widget _productMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Surface(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 7 : 12,
        vertical: mobile ? 7 : 9,
      ),
      child: Flex(
        direction: mobile ? Axis.vertical : Axis.horizontal,
        mainAxisAlignment: mobile
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: mobile
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: mobile ? 28 : 34,
            height: mobile ? 28 : 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: mobile ? 15 : 18),
          ),
          SizedBox(width: mobile ? 0 : 9, height: mobile ? 4 : 0),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mobile ? 12 : 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: mobile ? 7 : 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _categoryName(AppState state) {
    for (final category in state.categories) {
      if (category.id == categoryId) return context.tr(category.name);
    }
    return 'Categories';
  }

  String _statusName(String value) => switch (value) {
    'active' => 'Active',
    'inactive' => 'Inactive',
    'low' => 'Low stock',
    'out' => 'Out of stock',
    _ => 'Status',
  };

  Widget _mobileFilterButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.keyboard_arrow_down, size: 16),
      ],
    ),
  );

  Widget _categoryFilter(AppState state) => DropdownButtonFormField<String>(
    initialValue: categoryId,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: context.tr('Category'),
      prefixIcon: Icon(Icons.category_outlined, size: 19),
      isDense: true,
    ),
    items: [
      const DropdownMenuItem(value: 'all', child: Text('All categories')),
      for (final category in state.categories)
        DropdownMenuItem(
          value: category.id,
          child: Text(context.tr(category.name)),
        ),
    ],
    onChanged: (value) => setState(() {
      categoryId = value ?? 'all';
      page = 0;
    }),
  );

  Widget _statusFilter() => DropdownButtonFormField<String>(
    initialValue: status,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: context.tr('Status'),
      prefixIcon: Icon(Icons.flag_outlined, size: 19),
      isDense: true,
    ),
    items: const [
      DropdownMenuItem(value: 'all', child: Text('All statuses')),
      DropdownMenuItem(value: 'active', child: Text('Active')),
      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
      DropdownMenuItem(value: 'low', child: Text('Low stock')),
      DropdownMenuItem(value: 'out', child: Text('Out of stock')),
    ],
    onChanged: (value) => setState(() {
      status = value ?? 'all';
      page = 0;
    }),
  );

  Widget _mobileProductCard(Product product) {
    final out = product.stock <= 0;
    final low = !out && product.stock <= product.minimumStock;
    final stockColor = !product.active
        ? AppColors.muted
        : out
        ? AppColors.danger
        : low
        ? const Color(0xFFD88900)
        : const Color(0xFF16814E);
    final statusLabel = !product.active
        ? 'Inactive'
        : out
        ? 'Out of stock'
        : low
        ? 'Low stock'
        : 'In stock';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Color(0xFFE1E8E5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/products/edit', extra: product),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Center(
                    child: ProductImage(
                      product.imageUrl,
                      width: 78,
                      height: 78,
                      fit: BoxFit.contain,
                    ),
                  ),
                  PositionedDirectional(
                    end: -8,
                    top: -8,
                    child: PopupMenuButton<String>(
                      tooltip: context.tr('Product actions'),
                      onSelected: (action) => _productAction(product, action),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'status',
                          child: Text(
                            product.active ? 'Deactivate' : 'Activate',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete product'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                product.displayName(context.isArabic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'SKU: ${product.sku}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 8),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: RiyalAmount(
                      product.sellingPrice,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stockColor.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${product.stock} ${product.unit}',
                      style: TextStyle(
                        color: stockColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: stockColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: stockColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.go('/products/edit', extra: product),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      backgroundColor: const Color(0xFFEAF5F1),
                    ),
                    child: const Text('View', style: TextStyle(fontSize: 9)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMobileFilters(AppState state) async {
    var draftCategory = categoryId;
    var draftStatus = status;
    var draftSort = sortBy;
    var draftOnlyActive = onlyActive;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => FractionallySizedBox(
          heightFactor: .9,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD4D0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        draftCategory = 'all';
                        draftStatus = 'all';
                        draftSort = 'name';
                        draftOnlyActive = false;
                        _minStockController.clear();
                        _maxStockController.clear();
                        _minPriceController.clear();
                        _maxPriceController.clear();
                      }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: draftCategory,
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All categories'),
                          ),
                          for (final category in state.categories)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(context.tr(category.name)),
                            ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => draftCategory = value ?? 'all'),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      RadioGroup<String>(
                        groupValue: draftStatus,
                        onChanged: (value) =>
                            setSheetState(() => draftStatus = value ?? 'all'),
                        child: Column(
                          children: [
                            for (final option in const [
                              ('all', 'All'),
                              ('active', 'In stock'),
                              ('low', 'Low stock'),
                              ('out', 'Out of stock'),
                            ])
                              RadioListTile<String>(
                                value: option.$1,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(option.$2),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _rangeFields(
                        'Stock range',
                        _minStockController,
                        _maxStockController,
                      ),
                      const SizedBox(height: 18),
                      _rangeFields(
                        'Price range',
                        _minPriceController,
                        _maxPriceController,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Sort by',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: draftSort,
                        items: const [
                          DropdownMenuItem(
                            value: 'name',
                            child: Text('Name (A to Z)'),
                          ),
                          DropdownMenuItem(
                            value: 'price_low',
                            child: Text('Price: Low to high'),
                          ),
                          DropdownMenuItem(
                            value: 'price_high',
                            child: Text('Price: High to low'),
                          ),
                          DropdownMenuItem(
                            value: 'stock_low',
                            child: Text('Stock: Low to high'),
                          ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => draftSort = value ?? 'name'),
                      ),
                      const SizedBox(height: 14),
                      CheckboxListTile(
                        value: draftOnlyActive,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Only active products'),
                        onChanged: (value) => setSheetState(
                          () => draftOnlyActive = value ?? false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            categoryId = draftCategory;
                            status = draftStatus;
                            sortBy = draftSort;
                            onlyActive = draftOnlyActive;
                            page = 0;
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Apply filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rangeFields(
    String label,
    TextEditingController minimum,
    TextEditingController maximum,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: minimum,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: context.tr('Min')),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('–'),
          ),
          Expanded(
            child: TextField(
              controller: maximum,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: context.tr('Max')),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _productCard(Product product) {
    final out = product.stock <= 0;
    final low = !out && product.stock <= product.minimumStock;
    final stockColor = !product.active
        ? AppColors.muted
        : out
        ? AppColors.danger
        : low
        ? const Color(0xFFD88900)
        : const Color(0xFF16814E);
    final statusLabel = !product.active
        ? 'Inactive'
        : out
        ? 'Out of stock'
        : low
        ? 'Low stock'
        : 'In stock';

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE1E8E5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/products/edit', extra: product),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F8),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: ProductImage(
                      product.imageUrl,
                      width: 58,
                      height: 58,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.displayName(context.isArabic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${product.sku}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          money(product.sellingPrice),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: context.tr('Product actions'),
                    padding: EdgeInsets.zero,
                    onSelected: (action) => _productAction(product, action),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'status',
                        child: Text(product.active ? 'Deactivate' : 'Activate'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete product'),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              const Divider(height: 16),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: stockColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: stockColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${product.stock} ${product.unit}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 9),
                  IconButton(
                    tooltip: context.tr('Edit product'),
                    onPressed: () =>
                        context.go('/products/edit', extra: product),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pagination(
    int total,
    int currentPage,
    int totalPages, {
    bool mobile = false,
  }) => Container(
    height: mobile ? 96 : 48,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E8E5)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: mobile
        ? Column(
            children: [
              Text(
                total == 0
                    ? '0 products'
                    : 'Showing ${currentPage * pageSize + 1}–${(currentPage * pageSize + pageSize).clamp(0, total)} of $total products',
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pageButton(
                    Icons.first_page_rounded,
                    currentPage == 0 ? null : () => setState(() => page = 0),
                  ),
                  _pageButton(
                    Icons.chevron_left_rounded,
                    currentPage == 0
                        ? null
                        : () => setState(() => page = currentPage - 1),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${currentPage + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Text(
                      'of $totalPages',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  _pageButton(
                    Icons.chevron_right_rounded,
                    currentPage >= totalPages - 1
                        ? null
                        : () => setState(() => page = currentPage + 1),
                  ),
                  _pageButton(
                    Icons.last_page_rounded,
                    currentPage >= totalPages - 1
                        ? null
                        : () => setState(() => page = totalPages - 1),
                  ),
                ],
              ),
            ],
          )
        : Row(
            children: [
              Text(
                total == 0
                    ? '0 products'
                    : 'Showing ${currentPage * pageSize + 1}–${(currentPage * pageSize + pageSize).clamp(0, total)} of $total',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const Spacer(),
              IconButton(
                tooltip: context.tr('Previous page'),
                onPressed: currentPage == 0
                    ? null
                    : () => setState(() => page = currentPage - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${currentPage + 1} / $totalPages',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr('Next page'),
                onPressed: currentPage >= totalPages - 1
                    ? null
                    : () => setState(() => page = currentPage + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
  );

  Widget _pageButton(IconData icon, VoidCallback? onPressed) => IconButton(
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    icon: Icon(icon, size: 19),
  );

  Future<void> _productAction(Product product, String action) async {
    if (action == 'edit') {
      context.go('/products/edit', extra: product);
      return;
    }
    if (action == 'status') {
      try {
        await ref
            .read(backendControllerProvider.notifier)
            .updateProductStatus(product, !product.active);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                product.active ? 'Product deactivated.' : 'Product activated.',
              ),
            ),
          );
      } on ApiException catch (error) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          '“${product.name}” can only be deleted if it has no transaction history. Otherwise deactivate it instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(backendControllerProvider.notifier).deleteProduct(product);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product deleted.')));
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});
  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    return PagePad(
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              const PageTitle(
                'Categories',
                subtitle: 'Organize products for faster checkout.',
              ),
              FilledButton.icon(
                onPressed: _busy ? null : () => _showEditor(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New category'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: c.maxWidth > 900
                      ? 4
                      : c.maxWidth > 500
                      ? 3
                      : 2,
                  mainAxisExtent: 130,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: s.categories.length,
                itemBuilder: (_, i) {
                  final cat = s.categories[i];
                  final count = s.products
                      .where((p) => p.categoryId == cat.id)
                      .length;
                  return Surface(
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.category_outlined, size: 26),
                            const Spacer(),
                            Text(
                              context.tr(cat.name),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '$count products • ${cat.subCategories.length} subcategories',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          right: -8,
                          top: -10,
                          child: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'manage') _showSubcategories(cat);
                              if (action == 'sub') _showEditor(parent: cat);
                              if (action == 'edit') _showEditor(category: cat);
                              if (action == 'delete') _deleteCategory(cat);
                            },
                            itemBuilder: (_) => [
                              if (cat.subCategories.isNotEmpty)
                                const PopupMenuItem(
                                  value: 'manage',
                                  child: Text('Manage subcategories'),
                                ),
                              PopupMenuItem(
                                value: 'sub',
                                child: Text('Add subcategory'),
                              ),
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete / replace'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditor({Category? category, Category? parent}) async {
    final name = TextEditingController(
      text: category?.nameEn.isNotEmpty == true
          ? category!.nameEn
          : category?.name ?? '',
    );
    final arabic = TextEditingController(text: category?.nameAr ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          category == null
              ? (parent == null ? 'Create category' : 'Create subcategory')
              : 'Edit category',
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.tr('English name *'),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: arabic,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: context.tr('Arabic name (optional)'),
                ),
              ),
              if (parent != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Parent: ${parent.name}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final controller = ref.read(backendControllerProvider.notifier);
      if (category == null) {
        await controller.createCategory(
          name: name.text.trim(),
          nameAr: arabic.text.trim(),
          parentId: parent?.id,
        );
      } else {
        await controller.updateCategory(
          id: category.id,
          name: name.text.trim(),
          nameAr: arabic.text.trim(),
        );
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category saved.')));
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
      name.dispose();
      arabic.dispose();
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final state = ref.read(appStoreProvider);
    final parent = state.categories
        .where((item) => item.subCategories.any((sub) => sub.id == category.id))
        .firstOrNull;
    final options = (parent?.subCategories ?? state.categories)
        .where((item) => item.id != category.id)
        .toList();
    String? replacementId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Delete or replace category'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete “${category.name}”. If it is in use, select a compatible replacement.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: replacementId,
                  decoration: InputDecoration(
                    labelText: context.tr('Replacement (if required)'),
                  ),
                  items: options
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => replacementId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(backendControllerProvider.notifier)
          .deleteCategory(id: category.id, replacementId: replacementId);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category deleted.')));
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSubcategories(Category parent) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_categoryLabel(parent)} subcategories'),
        content: SizedBox(
          width: 480,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: parent.subCategories.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final sub = parent.subCategories[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_categoryLabel(sub)),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    Navigator.pop(dialogContext);
                    if (action == 'edit') _showEditor(category: sub);
                    if (action == 'delete') _deleteCategory(sub);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete / replace'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showEditor(parent: parent);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add subcategory'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(Category category) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    if (arabic && category.nameAr.trim().isNotEmpty) return category.nameAr;
    if (category.nameEn.trim().isNotEmpty) return category.nameEn;
    return context.tr(category.name);
  }
}

class LegacyPurchasesScreen extends ConsumerWidget {
  const LegacyPurchasesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    return PagePad(
      child: Column(
        children: [
          const PageTitle(
            'Purchases',
            subtitle: 'Purchase APIs are not available in Connector.',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Surface(
              child: s.purchases.isEmpty
                  ? const EmptyState(
                      'BACKEND CHANGE REQUIRED: No purchase API is available.',
                    )
                  : ListView.separated(
                      itemCount: s.purchases.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final p = s.purchases[i];
                        return ListTile(
                          title: Text(
                            p.invoiceNo,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${p.supplier.name} • ${p.items.length} lines',
                          ),
                          trailing: Text(
                            money(p.total),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final low = s.stockItems.where((p) => p.stock <= p.minimumStock).length,
        out = s.stockItems.where((p) => p.stock == 0).length;
    final rows = s.stockItems
        .where(
          (p) =>
              filter == 'All' ||
              filter == 'Low stock' && p.stock <= p.minimumStock ||
              filter == 'Out of stock' && p.stock == 0,
        )
        .toList();
    return PagePad(
      child: Column(
        children: [
          const PageTitle(
            'Inventory',
            subtitle: 'Live stock reported by EazyERP.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Products',
                  value: '${s.stockItems.length}',
                  icon: Icons.inventory_2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Low stock',
                  value: '$low',
                  icon: Icons.warning_amber,
                  tint: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Out of stock',
                  value: '$out',
                  icon: Icons.remove_shopping_cart,
                  tint: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'All', label: Text(context.tr('All'))),
                ButtonSegment(
                  value: 'Low stock',
                  label: Text(context.tr('Low stock')),
                ),
                ButtonSegment(
                  value: 'Out of stock',
                  label: Text(context.tr('Out of stock')),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (v) => setState(() => filter = v.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Surface(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final p = rows[i];
                  return ListTile(
                    title: Text(
                      context.tr(p.name),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Min ${p.minimumStock} • ${p.locationName} • ${money(p.unitPrice)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge(
                          p.stock == 0
                              ? 'Out of stock'
                              : p.stock <= p.minimumStock
                              ? 'Low: ${p.stock}'
                              : 'In stock: ${p.stock}',
                          color: p.stock <= p.minimumStock
                              ? AppColors.danger
                              : AppColors.primary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final customers = s.customers
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(query.toLowerCase()) ||
              customer.businessName.toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              customer.phone.contains(query) ||
              customer.email.toLowerCase().contains(query.toLowerCase()),
        )
        .toList(growable: false);
    return PagePad(
      child: Column(
        children: [
          PageTitle(
            'Customers',
            subtitle: 'Customer profiles for faster billing.',
            action: FilledButton.icon(
              onPressed: () => _customerForm(context, ref),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(context.tr('Add customer')),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              hintText: context.tr('Search customers'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Surface(
              child: ListView.separated(
                itemCount: customers.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final c = customers[i];
                  return ListTile(
                    onTap: () => _customerForm(context, ref, c),
                    leading: CircleAvatar(
                      child: Icon(
                        c.isBusiness
                            ? Icons.storefront_outlined
                            : Icons.person_outline,
                      ),
                    ),
                    title: Text(
                      c.isBusiness && c.businessName.isNotEmpty
                          ? c.businessName
                          : c.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: c.phone.isEmpty
                                ? 'Default billing customer'
                                : c.phone,
                          ),
                          if (c.isBusiness && c.name.isNotEmpty)
                            TextSpan(text: '  •  ${c.name}'),
                          TextSpan(
                            text: '  •  ${c.isBusiness ? 'B2B' : 'B2C'}',
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _customerForm(
    BuildContext context,
    WidgetRef ref, [
    Customer? existing,
  ]) async {
    final name = TextEditingController(text: existing?.name);
    final mobile = TextEditingController(text: existing?.phone);
    final email = TextEditingController(text: existing?.email);
    final businessName = TextEditingController(text: existing?.businessName);
    final taxNumber = TextEditingController(text: existing?.taxNumber);
    final registrationNumber = TextEditingController(
      text: existing?.commercialRegistrationNumber,
    );
    final addressLine1 = TextEditingController(text: existing?.addressLine1);
    final addressLine2 = TextEditingController(text: existing?.addressLine2);
    final city = TextEditingController(text: existing?.city);
    final state = TextEditingController(text: existing?.state);
    final country = TextEditingController(
      text: existing?.country.isNotEmpty == true
          ? existing!.country
          : 'Saudi Arabia',
    );
    final zipCode = TextEditingController(text: existing?.zipCode);
    final contactId = TextEditingController(text: existing?.contactId);
    final prefix = TextEditingController(text: existing?.prefix);
    final middleName = TextEditingController(text: existing?.middleName);
    final lastName = TextEditingController(text: existing?.lastName);
    final alternateNumber = TextEditingController(
      text: existing?.alternateNumber,
    );
    final landline = TextEditingController(text: existing?.landline);
    final dateOfBirth = TextEditingController(text: existing?.dateOfBirth);
    final customerGroupId = TextEditingController(
      text: existing?.customerGroupId,
    );
    final payTermNumber = TextEditingController(text: existing?.payTermNumber);
    final shippingAddress = TextEditingController(
      text: existing?.shippingAddress,
    );
    final position = TextEditingController(text: existing?.position);
    final formKey = GlobalKey<FormState>();
    var isBusiness = existing?.isBusiness ?? false;
    var payTermType = existing?.payTermType.isNotEmpty == true
        ? existing!.payTermType
        : 'days';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenSize = MediaQuery.sizeOf(dialogContext);
        final dialogWidth = math.min(
          760.0,
          math.max(280.0, screenSize.width - 84),
        );
        final dialogHeight = math.min(650.0, screenSize.height - 180);
        var saving = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 20,
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            title: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBusiness
                        ? Icons.storefront_outlined
                        : Icons.person_outline,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          existing == null ? 'Add customer' : 'Edit customer',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBusiness
                            ? 'Create a ZATCA-ready business customer'
                            : 'Create a customer for simplified invoices',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Close'),
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: SingleChildScrollView(
                  child: Builder(
                    builder: (context) {
                      final fieldWidth = dialogWidth >= 680
                          ? (dialogWidth - 12) / 2
                          : dialogWidth;
                      Widget field(
                        TextEditingController controller,
                        String label,
                        IconData icon, {
                        String? hint,
                        TextInputType? keyboardType,
                        String? Function(String?)? validator,
                      }) => SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: controller,
                          keyboardType: keyboardType,
                          decoration: InputDecoration(
                            labelText: context.tr(label),
                            hintText: hint,
                            prefixIcon: Icon(icon, size: 20),
                          ),
                          validator: validator,
                        ),
                      );
                      String? requiredValue(String? value) =>
                          value == null || value.trim().isEmpty
                          ? context.tr('Required')
                          : null;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invoice customer type',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  icon: Icon(Icons.person_outline),
                                  label: Text('Individual (B2C)'),
                                ),
                                ButtonSegment(
                                  value: true,
                                  icon: Icon(Icons.storefront_outlined),
                                  label: Text('Business (B2B)'),
                                ),
                              ],
                              selected: {isBusiness},
                              onSelectionChanged: saving
                                  ? null
                                  : (selection) => setState(
                                      () => isBusiness = selection.first,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: .06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 19,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isBusiness
                                        ? 'B2B invoices use the company VAT and registered address for ZATCA clearance.'
                                        : 'B2C customers use the simplified invoice flow. Business tax fields are not required.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Contact type',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const Spacer(),
                              Chip(
                                avatar: const Icon(
                                  Icons.person_outline,
                                  size: 17,
                                ),
                                label: const Text('Customer'),
                                side: BorderSide.none,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: .08,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const _CustomerFormSectionTitle(
                            icon: Icons.person_outline,
                            title: 'Contact details',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              field(
                                name,
                                isBusiness ? 'Contact person' : 'First name',
                                Icons.person_outline,
                                validator: requiredValue,
                              ),
                              if (!isBusiness)
                                field(
                                  prefix,
                                  'Prefix',
                                  Icons.person_outline,
                                  hint: 'Mr / Mrs / Miss',
                                ),
                              if (!isBusiness)
                                field(
                                  middleName,
                                  'Middle name',
                                  Icons.person_outline,
                                ),
                              if (!isBusiness)
                                field(
                                  lastName,
                                  'Last name',
                                  Icons.person_outline,
                                ),
                              field(
                                mobile,
                                'Mobile',
                                Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: requiredValue,
                              ),
                              field(
                                alternateNumber,
                                'Alternate contact number',
                                Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                              field(
                                landline,
                                'Landline',
                                Icons.call_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                              field(
                                email,
                                'Email',
                                Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isNotEmpty && !text.contains('@')) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          if (isBusiness) ...[
                            const SizedBox(height: 22),
                            const Divider(),
                            const SizedBox(height: 14),
                            const _CustomerFormSectionTitle(
                              icon: Icons.business_outlined,
                              title: 'Business & ZATCA details',
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Fields marked required are used to produce a standard B2B tax invoice.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                field(
                                  businessName,
                                  'Business name',
                                  Icons.storefront_outlined,
                                  validator: requiredValue,
                                ),
                                field(
                                  taxNumber,
                                  'VAT number',
                                  Icons.receipt_long_outlined,
                                  hint: '15 digits, starts and ends with 3',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    final vat = value?.trim() ?? '';
                                    if (vat.isEmpty)
                                      return context.tr('Required');
                                    if (!RegExp(r'^3\d{13}3$').hasMatch(vat)) {
                                      return 'Enter a valid 15-digit Saudi VAT number';
                                    }
                                    return null;
                                  },
                                ),
                                field(
                                  registrationNumber,
                                  'Commercial registration number',
                                  Icons.badge_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const _CustomerFormSectionTitle(
                              icon: Icons.location_on_outlined,
                              title: 'Registered address',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                field(
                                  addressLine1,
                                  'Address line 1',
                                  Icons.location_on_outlined,
                                  validator: requiredValue,
                                ),
                                field(
                                  addressLine2,
                                  'Address line 2',
                                  Icons.location_on_outlined,
                                ),
                                field(
                                  city,
                                  'City',
                                  Icons.location_city_outlined,
                                  validator: requiredValue,
                                ),
                                field(
                                  state,
                                  'State / Province',
                                  Icons.map_outlined,
                                ),
                                field(
                                  country,
                                  'Country',
                                  Icons.public_outlined,
                                  validator: requiredValue,
                                ),
                                field(
                                  zipCode,
                                  'Postal code',
                                  Icons.markunread_mailbox_outlined,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            leading: const Icon(
                              Icons.more_horiz,
                              color: AppColors.primary,
                            ),
                            title: const Text(
                              'More information',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text(
                              'Optional identifiers, terms and delivery details',
                            ),
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  field(
                                    contactId,
                                    'Contact ID',
                                    Icons.badge_outlined,
                                    hint: 'Leave blank to auto-generate',
                                  ),
                                  field(
                                    customerGroupId,
                                    'Customer group ID',
                                    Icons.groups_outlined,
                                    keyboardType: TextInputType.number,
                                  ),
                                  if (!isBusiness)
                                    field(
                                      dateOfBirth,
                                      'Date of birth',
                                      Icons.cake_outlined,
                                      hint: 'YYYY-MM-DD',
                                      keyboardType: TextInputType.datetime,
                                      validator: (value) {
                                        final text = value?.trim() ?? '';
                                        if (text.isNotEmpty &&
                                            !RegExp(
                                              r'^\d{4}-\d{2}-\d{2}$',
                                            ).hasMatch(text)) {
                                          return 'Use YYYY-MM-DD';
                                        }
                                        return null;
                                      },
                                    ),
                                  field(
                                    position,
                                    'Position / designation',
                                    Icons.work_outline,
                                  ),
                                  field(
                                    payTermNumber,
                                    'Payment term',
                                    Icons.calendar_month_outlined,
                                    hint: 'e.g. 30',
                                    keyboardType: TextInputType.number,
                                  ),
                                  SizedBox(
                                    width: fieldWidth,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: payTermType,
                                      decoration: InputDecoration(
                                        labelText: context.tr(
                                          'Payment term unit',
                                        ),
                                        prefixIcon: Icon(
                                          Icons.schedule_outlined,
                                          size: 20,
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'days',
                                          child: Text('Days'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'months',
                                          child: Text('Months'),
                                        ),
                                      ],
                                      onChanged: saving
                                          ? null
                                          : (value) => setState(
                                              () =>
                                                  payTermType = value ?? 'days',
                                            ),
                                    ),
                                  ),
                                  field(
                                    shippingAddress,
                                    'Shipping address',
                                    Icons.local_shipping_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Assigned user and additional contact persons require dedicated backend endpoints. They are not added as unsaved placeholder fields.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              error!,
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final controller = ref.read(
                            backendControllerProvider.notifier,
                          );
                          if (existing == null) {
                            await controller.createCustomer(
                              name: name.text.trim(),
                              mobile: mobile.text.trim(),
                              email: email.text.trim(),
                              taxNumber: isBusiness
                                  ? taxNumber.text.trim()
                                  : '',
                              businessName: isBusiness
                                  ? businessName.text.trim()
                                  : '',
                              commercialRegistrationNumber: isBusiness
                                  ? registrationNumber.text.trim()
                                  : '',
                              addressLine1: isBusiness
                                  ? addressLine1.text.trim()
                                  : '',
                              addressLine2: isBusiness
                                  ? addressLine2.text.trim()
                                  : '',
                              city: isBusiness ? city.text.trim() : '',
                              state: isBusiness ? state.text.trim() : '',
                              country: isBusiness ? country.text.trim() : '',
                              zipCode: isBusiness ? zipCode.text.trim() : '',
                              contactId: contactId.text.trim(),
                              prefix: isBusiness ? '' : prefix.text.trim(),
                              middleName: isBusiness
                                  ? ''
                                  : middleName.text.trim(),
                              lastName: isBusiness ? '' : lastName.text.trim(),
                              alternateNumber: alternateNumber.text.trim(),
                              landline: landline.text.trim(),
                              dateOfBirth: isBusiness
                                  ? ''
                                  : dateOfBirth.text.trim(),
                              customerGroupId: customerGroupId.text.trim(),
                              payTermNumber: payTermNumber.text.trim(),
                              payTermType: payTermType,
                              shippingAddress: shippingAddress.text.trim(),
                              position: position.text.trim(),
                            );
                          } else {
                            await controller.updateCustomer(
                              customer: existing,
                              name: name.text.trim(),
                              mobile: mobile.text.trim(),
                              email: email.text.trim(),
                              taxNumber: isBusiness
                                  ? taxNumber.text.trim()
                                  : '',
                              businessName: isBusiness
                                  ? businessName.text.trim()
                                  : '',
                              commercialRegistrationNumber: isBusiness
                                  ? registrationNumber.text.trim()
                                  : '',
                              addressLine1: isBusiness
                                  ? addressLine1.text.trim()
                                  : '',
                              addressLine2: isBusiness
                                  ? addressLine2.text.trim()
                                  : '',
                              city: isBusiness ? city.text.trim() : '',
                              state: isBusiness ? state.text.trim() : '',
                              country: isBusiness ? country.text.trim() : '',
                              zipCode: isBusiness ? zipCode.text.trim() : '',
                              contactId: contactId.text.trim(),
                              prefix: isBusiness ? '' : prefix.text.trim(),
                              middleName: isBusiness
                                  ? ''
                                  : middleName.text.trim(),
                              lastName: isBusiness ? '' : lastName.text.trim(),
                              alternateNumber: alternateNumber.text.trim(),
                              landline: landline.text.trim(),
                              dateOfBirth: isBusiness
                                  ? ''
                                  : dateOfBirth.text.trim(),
                              customerGroupId: customerGroupId.text.trim(),
                              payTermNumber: payTermNumber.text.trim(),
                              payTermType: payTermType,
                              shippingAddress: shippingAddress.text.trim(),
                              position: position.text.trim(),
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (exception) {
                          setState(() {
                            saving = false;
                            error = exception.toString();
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Save')),
              ),
            ],
          ),
        );
      },
    );
    name.dispose();
    mobile.dispose();
    email.dispose();
    businessName.dispose();
    taxNumber.dispose();
    registrationNumber.dispose();
    addressLine1.dispose();
    addressLine2.dispose();
    city.dispose();
    state.dispose();
    country.dispose();
    zipCode.dispose();
    contactId.dispose();
    prefix.dispose();
    middleName.dispose();
    lastName.dispose();
    alternateNumber.dispose();
    landline.dispose();
    dateOfBirth.dispose();
    customerGroupId.dispose();
    payTermNumber.dispose();
    shippingAddress.dispose();
    position.dispose();
  }
}

class _CustomerFormSectionTitle extends StatelessWidget {
  const _CustomerFormSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});
  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  bool showingReturns = false;
  String period = 'Today';
  String query = '';
  String paymentFilter = 'All';
  String syncFilter = 'All';
  String customerFilter = 'All';
  String sortFilter = 'Newest first';
  int? minimumAmount;
  int? maximumAmount;
  DateTimeRange? customRange;
  int page = 1;
  int rowsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStoreProvider);
    final mobile = MediaQuery.sizeOf(context).width < 600;
    if (showingReturns) return _buildReturnsPage(context, mobile);
    final now = DateTime.now();
    final range = _periodRange(now);
    final normalizedQuery = query.trim().toLowerCase();
    final sales = state.sales.where((sale) {
      final inRange =
          !sale.createdAt.isBefore(range.start) &&
          sale.createdAt.isBefore(range.end);
      final matchesQuery =
          normalizedQuery.isEmpty ||
          sale.invoiceNo.toLowerCase().contains(normalizedQuery) ||
          sale.customer.name.toLowerCase().contains(normalizedQuery) ||
          sale.paymentMethod.toLowerCase().contains(normalizedQuery) ||
          (sale.total / 100).toStringAsFixed(2).contains(normalizedQuery);
      final matchesPayment =
          paymentFilter == 'All' ||
          sale.paymentMethod.toLowerCase() == paymentFilter.toLowerCase();
      final matchesSync =
          syncFilter == 'All' ||
          sale.syncStatus.name.toLowerCase() == syncFilter.toLowerCase();
      final matchesCustomer =
          customerFilter == 'All' || sale.customer.id == customerFilter;
      final matchesAmount =
          (minimumAmount == null || sale.total >= minimumAmount!) &&
          (maximumAmount == null || sale.total <= maximumAmount!);
      return inRange &&
          matchesQuery &&
          matchesPayment &&
          matchesSync &&
          matchesCustomer &&
          matchesAmount;
    }).toList();
    switch (sortFilter) {
      case 'Oldest first':
        sales.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'Amount high to low':
        sales.sort((a, b) => b.total.compareTo(a.total));
      case 'Amount low to high':
        sales.sort((a, b) => a.total.compareTo(b.total));
      default:
        sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final lowStock =
        state.products
            .where((product) => product.stock <= product.minimumStock)
            .toList()
          ..sort((a, b) => a.stock.compareTo(b.stock));
    final total = sales.fold<int>(0, (sum, sale) => sum + sale.total);
    final customers = sales.map((sale) => sale.customer.id).toSet().length;
    final average = sales.isEmpty ? 0 : total ~/ sales.length;
    final pageCount = math.max(1, (sales.length / rowsPerPage).ceil());
    if (page > pageCount) page = pageCount;
    final visibleSales = sales
        .skip((page - 1) * rowsPerPage)
        .take(rowsPerPage)
        .toList(growable: false);

    return PagePad(
      child: ListView(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PageTitle(
                  'Sales history',
                  subtitle: 'Local and synchronized transactions.',
                ),
              ),
              PopupMenuButton<String>(
                tooltip: context.tr('Export'),
                onSelected: (_) => _exportSales(sales),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                ],
                child: IgnorePointer(
                  child: _SalesToolbarButton(
                    icon: Icons.ios_share_outlined,
                    label: context.tr('Export'),
                    trailing: Icons.keyboard_arrow_down,
                    onTap: () {},
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SalesHistoryTabs(
            showingReturns: false,
            onChanged: (returns) => setState(() => showingReturns = returns),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final periodButtons = <Widget>[
                for (final value in const [
                  'Today',
                  'Yesterday',
                  'This week',
                  'This month',
                  'Custom range',
                ])
                  _SalesPeriodButton(
                    label: context.tr(value),
                    selected: period == value,
                    icon: value == 'Today'
                        ? Icons.calendar_today_outlined
                        : value == 'Custom range'
                        ? Icons.date_range_outlined
                        : null,
                    onTap: () => _selectPeriod(value),
                  ),
              ];
              final periods = mobile
                  ? Wrap(spacing: 8, runSpacing: 8, children: periodButtons)
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final button in periodButtons) ...[
                            button,
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    );
              final searchAndFilter = Row(
                children: [
                  _SalesToolbarButton(
                    icon: Icons.filter_alt_outlined,
                    label: context.tr('Filters'),
                    trailing: Icons.keyboard_arrow_down,
                    onTap: _showFilters,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() {
                        query = value;
                        page = 1;
                      }),
                      decoration: InputDecoration(
                        hintText: context.tr(
                          'Search invoice, customer or amount...',
                        ),
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 850) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    periods,
                    const SizedBox(height: 10),
                    searchAndFilter,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: periods),
                  const SizedBox(width: 16),
                  SizedBox(width: 480, child: searchAndFilter),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (_, constraints) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: constraints.maxWidth >= 980 ? 4 : 2,
              childAspectRatio: constraints.maxWidth < 550 ? 1.12 : 2.35,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _SalesSummaryCard(
                  label: 'Total sales',
                  value: money(total),
                  icon: Icons.trending_up,
                  tint: const Color(0xFFE0F6DF),
                  iconColor: const Color(0xFF159447),
                ),
                _SalesSummaryCard(
                  label: 'Total invoices',
                  value: sales.length.toString(),
                  icon: Icons.receipt_long_outlined,
                  tint: const Color(0xFFE7EEFF),
                  iconColor: const Color(0xFF2867E8),
                ),
                _SalesSummaryCard(
                  label: 'Total customers',
                  value: customers.toString(),
                  icon: Icons.people_alt_outlined,
                  tint: const Color(0xFFF1E4FF),
                  iconColor: const Color(0xFF7A31C7),
                ),
                _SalesSummaryCard(
                  label: 'Average order value',
                  value: money(average),
                  icon: Icons.monetization_on_outlined,
                  tint: const Color(0xFFFFEDD9),
                  iconColor: const Color(0xFFE97513),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 820;
                return Column(
                  children: [
                    if (compact)
                      _SalesMobileSectionHeader(
                        title: 'Recent sales',
                        icon: Icons.receipt_long_outlined,
                        count: sales.length,
                      ),
                    if (!compact) const _SalesTableHeader(),
                    if (visibleSales.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 56),
                        child: const EmptyState(
                          'No sales found. Try changing the date range or active filters.',
                        ),
                      )
                    else
                      for (final sale in visibleSales)
                        _SalesTransactionRow(
                          sale: sale,
                          compact: compact,
                          onTap: () => _details(context, sale),
                        ),
                    _SalesPagination(
                      total: sales.length,
                      page: page,
                      pageCount: pageCount,
                      rowsPerPage: rowsPerPage,
                      onPageChanged: (value) => setState(() => page = value),
                      onRowsChanged: (value) => setState(() {
                        rowsPerPage = value;
                        page = 1;
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
          if (mobile) ...[
            const SizedBox(height: 14),
            Surface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SalesMobileSectionHeader(
                    title: 'Low stock',
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFE97324),
                    count: lowStock.length,
                    onTap: () => context.go('/inventory'),
                  ),
                  if (lowStock.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: EmptyState('Stock levels look good'),
                    )
                  else
                    for (final product in lowStock.take(5))
                      _LowStockRow(product: product),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReturnsPage(BuildContext context, bool mobile) {
    final returnsAsync = ref.watch(saleReturnsProvider);
    final now = DateTime.now();
    final range = _periodRange(now);
    final normalizedQuery = query.trim().toLowerCase();
    return PagePad(
      child: ListView(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PageTitle(
                  'Sales returns',
                  subtitle: 'Invoice-linked refunds synchronized with EazyERP.',
                ),
              ),
              IconButton.outlined(
                tooltip: context.tr('Refresh'),
                onPressed: () => ref.invalidate(saleReturnsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SalesHistoryTabs(
            showingReturns: true,
            onChanged: (returns) => setState(() => showingReturns = returns),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final periods = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in const [
                    'Today',
                    'Yesterday',
                    'This week',
                    'This month',
                    'Custom range',
                  ])
                    _SalesPeriodButton(
                      label: context.tr(value),
                      selected: period == value,
                      icon: value == 'Custom range'
                          ? Icons.date_range_outlined
                          : null,
                      onTap: () => _selectPeriod(value),
                    ),
                ],
              );
              final search = TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  hintText: context.tr(
                    'Search return, original invoice or customer...',
                  ),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              );
              if (constraints.maxWidth < 850) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [periods, const SizedBox(height: 10), search],
                );
              }
              return Row(
                children: [
                  Expanded(child: periods),
                  const SizedBox(width: 16),
                  SizedBox(width: 430, child: search),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          returnsAsync.when(
            loading: () => const Surface(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => Surface(
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 42,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 10),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(saleReturnsProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
            data: (records) {
              final filtered = records.where((record) {
                final inRange =
                    !record.createdAt.isBefore(range.start) &&
                    record.createdAt.isBefore(range.end);
                final matchesQuery =
                    normalizedQuery.isEmpty ||
                    record.invoiceNo.toLowerCase().contains(normalizedQuery) ||
                    record.parentInvoiceNo.toLowerCase().contains(
                      normalizedQuery,
                    ) ||
                    record.customerName.toLowerCase().contains(normalizedQuery);
                return inRange && matchesQuery;
              }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              final total = filtered.fold<int>(
                0,
                (sum, record) => sum + record.total,
              );
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SalesSummaryCard(
                          label: 'Return documents',
                          value: filtered.length.toString(),
                          icon: Icons.assignment_return_outlined,
                          tint: const Color(0xFFFFEDD9),
                          iconColor: const Color(0xFFE97513),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SalesSummaryCard(
                          label: 'Refund total',
                          value: money(total),
                          icon: Icons.currency_exchange_outlined,
                          tint: const Color(0xFFE7EEFF),
                          iconColor: const Color(0xFF2867E8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Surface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SalesMobileSectionHeader(
                          title: 'Return history',
                          icon: Icons.assignment_return_outlined,
                          count: filtered.length,
                        ),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 56),
                            child: EmptyState(
                              'No sales returns match this date range.',
                            ),
                          )
                        else
                          for (final record in filtered)
                            _SaleReturnHistoryRow(
                              record: record,
                              compact: mobile,
                              onZatca: () =>
                                  showZatcaReturnDialog(context, ref, record),
                            ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  DateTimeRange _periodRange(DateTime now) {
    if (period == 'Custom range' && customRange != null) {
      return DateTimeRange(
        start: DateTime(
          customRange!.start.year,
          customRange!.start.month,
          customRange!.start.day,
        ),
        end: DateTime(
          customRange!.end.year,
          customRange!.end.month,
          customRange!.end.day + 1,
        ),
      );
    }
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      'Yesterday' => DateTimeRange(
        start: today.subtract(const Duration(days: 1)),
        end: today,
      ),
      'This week' => DateTimeRange(
        start: today.subtract(Duration(days: now.weekday - 1)),
        end: today.add(const Duration(days: 1)),
      ),
      'This month' => DateTimeRange(
        start: DateTime(now.year, now.month),
        end: today.add(const Duration(days: 1)),
      ),
      _ => DateTimeRange(start: today, end: today.add(const Duration(days: 1))),
    };
  }

  Future<void> _selectPeriod(String value) async {
    if (value != 'Custom range') {
      setState(() {
        period = value;
        page = 1;
      });
      return;
    }
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: customRange,
    );
    if (selected != null && mounted) {
      setState(() {
        customRange = selected;
        period = value;
        page = 1;
      });
    }
  }

  Future<void> _showFilters() async {
    var payment = paymentFilter;
    var sync = syncFilter;
    var customer = customerFilter;
    var selectedPeriod = period;
    var selectedRange = customRange;
    var minimum = minimumAmount == null
        ? ''
        : (minimumAmount! / 100).toStringAsFixed(2);
    var maximum = maximumAmount == null
        ? ''
        : (maximumAmount! / 100).toStringAsFixed(2);
    var sort = sortFilter;
    final customers = ref
        .read(appStoreProvider)
        .sales
        .map((sale) => sale.customer)
        .fold<Map<String, Customer>>({}, (items, item) {
          items[item.id] = item;
          return items;
        })
        .values
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => FractionallySizedBox(
          heightFactor: .92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DFDC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        context.tr('Filters'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        payment = 'All';
                        sync = 'All';
                        customer = 'All';
                        selectedPeriod = 'Today';
                        selectedRange = null;
                        minimum = '';
                        maximum = '';
                        sort = 'Newest first';
                      }),
                      child: Text(context.tr('Reset')),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  children: [
                    const _SalesFilterLabel('Date range'),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in const [
                          'Today',
                          'Yesterday',
                          'This week',
                          'This month',
                          'Custom range',
                        ])
                          _SalesPeriodButton(
                            label: context.tr(value),
                            selected: selectedPeriod == value,
                            icon: value == 'Custom range'
                                ? Icons.date_range_outlined
                                : null,
                            onTap: () async {
                              if (value == 'Custom range') {
                                final range = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 1),
                                  ),
                                  initialDateRange: selectedRange,
                                );
                                if (range == null) return;
                                selectedRange = range;
                              }
                              setSheetState(() => selectedPeriod = value);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SalesFilterLabel('Customer'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: customer,
                      items: [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text(context.tr('All customers')),
                        ),
                        ...customers.map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => customer = value ?? 'All'),
                    ),
                    const SizedBox(height: 20),
                    const _SalesFilterLabel('Payment method'),
                    const SizedBox(height: 6),
                    RadioGroup<String>(
                      groupValue: payment,
                      onChanged: (value) =>
                          setSheetState(() => payment = value ?? 'All'),
                      child: Column(
                        children: [
                          for (final value in const [
                            'All',
                            'Cash',
                            'Card',
                            'UPI',
                            'Credit',
                            'Other',
                          ])
                            RadioListTile<String>(
                              value: value,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(context.tr(value)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _SalesFilterLabel('Sync status'),
                    const SizedBox(height: 6),
                    RadioGroup<String>(
                      groupValue: sync,
                      onChanged: (value) =>
                          setSheetState(() => sync = value ?? 'All'),
                      child: Column(
                        children: [
                          for (final value in [
                            'All',
                            ...SyncStatus.values.map((item) => item.name),
                          ])
                            RadioListTile<String>(
                              value: value,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(context.tr(value)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _SalesFilterLabel('Amount range'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: minimum,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: context.tr('Min amount'),
                            ),
                            onChanged: (value) => minimum = value,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 9),
                          child: Text('–'),
                        ),
                        Expanded(
                          child: TextFormField(
                            initialValue: maximum,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: context.tr('Max amount'),
                            ),
                            onChanged: (value) => maximum = value,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SalesFilterLabel('Sort by'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: sort,
                      items:
                          const [
                                'Newest first',
                                'Oldest first',
                                'Amount high to low',
                                'Amount low to high',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setSheetState(() => sort = value ?? 'Newest first'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  22,
                  12,
                  22,
                  14 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(context.tr('Cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            period = selectedPeriod;
                            customRange = selectedRange;
                            paymentFilter = payment;
                            syncFilter = sync;
                            customerFilter = customer;
                            minimumAmount = _amountFromInput(minimum);
                            maximumAmount = _amountFromInput(maximum);
                            sortFilter = sort;
                            page = 1;
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: Text(context.tr('Apply filters')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? _amountFromInput(String value) {
    final parsed = double.tryParse(value.trim());
    return parsed == null ? null : (parsed * 100).round();
  }

  Future<void> _exportSales(List<Sale> sales) async {
    final document = pw.Document(title: 'GreenMart Sales History');
    final theme = await PdfFonts.arabicTheme();
    document.addPage(
      pw.MultiPage(
        theme: theme,
        build: (_) => [
          pw.Text(
            'GreenMart - Sales History',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Invoice',
              'Customer',
              'Date',
              'Items',
              'Payment',
              'Total',
              'Sync',
            ],
            data: sales
                .map(
                  (sale) => [
                    sale.invoiceNo,
                    sale.customer.name,
                    _dateTime(sale.createdAt),
                    sale.items.length.toString(),
                    sale.paymentMethod,
                    money(sale.total),
                    sale.syncStatus.name,
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'greenmart-sales-history.pdf',
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  static String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _dateTime(DateTime value) => '${_date(value)} ${_time(value)}';

  void _details(BuildContext context, Sale sale) => showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(sale.invoiceNo),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Customer'),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            Text(
              sale.customer.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _SalePaymentSummary(sale: sale),
            const Divider(),
            for (final line in sale.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${line.quantity} × ${line.product.displayName(context.isArabic)}',
                      ),
                    ),
                    RiyalAmount(line.total),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                Text(
                  context.tr('Total'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  money(sale.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed:
              sale.serverId == null ||
                  sale.items.every(
                    (line) =>
                        line.sellLineId == null || line.returnableQuantity <= 0,
                  )
              ? null
              : () {
                  Navigator.pop(dialogContext);
                  _showSaleReturn(context, sale);
                },
          icon: const Icon(Icons.keyboard_return_rounded),
          label: Text(context.tr('Return')),
        ),
        OutlinedButton.icon(
          onPressed: sale.serverId == null
              ? null
              : () {
                  Navigator.pop(dialogContext);
                  showZatcaInvoiceDialog(context, ref, sale);
                },
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('ZATCA'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.tr('Close')),
        ),
        FilledButton.icon(
          onPressed: () async {
            final printerState = ref.read(printerControllerProvider);
            try {
              await ref
                  .read(invoiceLayoutControllerProvider.notifier)
                  .printSale(
                    sale: sale,
                    businessName:
                        ref
                            .read(appStoreProvider)
                            .business
                            ?.displayName(context.isArabic) ??
                        'GreenMart',
                    settings: printerState.settings,
                    printer: printerState.selectedPrinter,
                    arabic: ref.read(localeProvider).languageCode == 'ar',
                  );
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Print failed: $error')));
              }
            }
          },
          icon: const Icon(Icons.print_outlined),
          label: Text(context.tr('Print')),
        ),
      ],
    ),
  );

  Future<void> _showSaleReturn(BuildContext context, Sale sale) async {
    final completed = await showSaleReturnDialog(context, sale);
    if (!mounted) return;
    if (completed == true) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Sale return created successfully.')),
      );
    }
  }
}

class _SalesHistoryTabs extends StatelessWidget {
  const _SalesHistoryTabs({
    required this.showingReturns,
    required this.onChanged,
  });

  final bool showingReturns;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2EF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SalesHistoryTab(
          label: context.tr('Sales'),
          icon: Icons.receipt_long_outlined,
          selected: !showingReturns,
          onTap: () => onChanged(false),
        ),
        _SalesHistoryTab(
          label: context.tr('Returns'),
          icon: Icons.assignment_return_outlined,
          selected: showingReturns,
          onTap: () => onChanged(true),
        ),
      ],
    ),
  );
}

class _SalesHistoryTab extends StatelessWidget {
  const _SalesHistoryTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? AppColors.primary : AppColors.muted,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SaleReturnHistoryRow extends StatelessWidget {
  const _SaleReturnHistoryRow({
    required this.record,
    required this.compact,
    required this.onZatca,
  });

  final SaleReturnRecord record;
  final bool compact;
  final VoidCallback onZatca;

  @override
  Widget build(BuildContext context) {
    final date = record.createdAt;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final statusColor = record.paymentStatus.toLowerCase() == 'paid'
        ? AppColors.primary
        : const Color(0xFFB76E00);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 20,
        vertical: compact ? 14 : 16,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE0E7E4))),
      ),
      child: compact
          ? Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFFEDD9),
                  foregroundColor: Color(0xFFE97513),
                  child: Icon(Icons.assignment_return_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.invoiceNo.isEmpty
                            ? 'Return #${record.id}'
                            : record.invoiceNo,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${record.parentInvoiceNo.isEmpty ? 'Original sale' : record.parentInvoiceNo} • ${record.customerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(dateText, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(record.total),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.paymentStatus.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    IconButton.outlined(
                      tooltip: context.tr('Submit return to ZATCA'),
                      visualDensity: VisualDensity.compact,
                      onPressed: onZatca,
                      icon: const Icon(Icons.verified_user_outlined, size: 18),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                const SizedBox(
                  width: 48,
                  child: CircleAvatar(
                    backgroundColor: Color(0xFFFFEDD9),
                    foregroundColor: Color(0xFFE97513),
                    child: Icon(Icons.assignment_return_outlined),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _ReturnCell(
                    primary: record.invoiceNo.isEmpty
                        ? 'Return #${record.id}'
                        : record.invoiceNo,
                    secondary: 'Original: ${record.parentInvoiceNo}',
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _ReturnCell(
                    primary: record.customerName,
                    secondary: dateText,
                  ),
                ),
                Expanded(
                  child: _ReturnCell(
                    primary: record.paymentMethod.toUpperCase(),
                    secondary: record.paymentStatus.toUpperCase(),
                    secondaryColor: statusColor,
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: Text(
                    money(record.total),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(
                  onPressed: onZatca,
                  icon: const Icon(Icons.verified_user_outlined, size: 18),
                  label: const Text('ZATCA'),
                ),
              ],
            ),
    );
  }
}

class _ReturnCell extends StatelessWidget {
  const _ReturnCell({
    required this.primary,
    required this.secondary,
    this.secondaryColor = AppColors.muted,
  });

  final String primary;
  final String secondary;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          secondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: secondaryColor, fontSize: 12),
        ),
      ],
    ),
  );
}

class _SaleReturnDialog extends ConsumerStatefulWidget {
  const _SaleReturnDialog({required this.sale});
  final Sale sale;

  @override
  ConsumerState<_SaleReturnDialog> createState() => _SaleReturnDialogState();
}

class _SaleReturnDialogState extends ConsumerState<_SaleReturnDialog> {
  late final Map<String, int> quantities = {
    for (final line in widget.sale.items)
      if (line.sellLineId != null) line.sellLineId!: 0,
  };
  bool submitting = false;
  String? error;

  int get refundTotal => widget.sale.items.fold(0, (total, line) {
    final quantity = quantities[line.sellLineId] ?? 0;
    if (quantity <= 0) return total;
    return total + (line.returnUnitPrice * quantity);
  });

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 12 : 40,
        vertical: mobile ? 18 : 32,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE3F5EF),
                    child: Icon(
                      Icons.keyboard_return_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return ${widget.sale.invoiceNo}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'Select the items and quantities being returned.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: submitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: widget.sale.items.length,
                separatorBuilder: (_, __) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final line = widget.sale.items[index];
                  final lineId = line.sellLineId;
                  final available = line.returnableQuantity;
                  final quantity = quantities[lineId] ?? 0;
                  return Row(
                    children: [
                      ProductImage(
                        line.product.imageUrl,
                        width: 52,
                        height: 52,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.product.displayName(context.isArabic),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              lineId == null
                                  ? 'Return unavailable for this line'
                                  : '$available of ${line.quantity} available',
                              style: TextStyle(
                                color: lineId == null || available == 0
                                    ? AppColors.danger
                                    : AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        money(line.returnUnitPrice * quantity),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD7DFDC)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: quantity <= 0 || submitting
                                  ? null
                                  : () => setState(
                                      () => quantities[lineId!] = quantity - 1,
                                    ),
                              icon: const Icon(Icons.remove, size: 18),
                            ),
                            SizedBox(
                              width: 24,
                              child: Text(
                                '$quantity',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed:
                                  lineId == null ||
                                      quantity >= available ||
                                      submitting
                                  ? null
                                  : () => setState(
                                      () => quantities[lineId] = quantity + 1,
                                    ),
                              icon: const Icon(Icons.add, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              decoration: const BoxDecoration(
                color: Color(0xFFF7FAF9),
                border: Border(top: BorderSide(color: Color(0xFFE1E7E5))),
              ),
              child: Column(
                children: [
                  if (error != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      const Text(
                        'Refund total',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        money(refundTotal),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: submitting
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(context.tr('Cancel')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: refundTotal <= 0 || submitting
                              ? null
                              : _submit,
                          icon: submitting
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.keyboard_return_rounded),
                          label: Text(
                            submitting ? 'Creating return...' : 'Create return',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await ref
          .read(backendControllerProvider.notifier)
          .createSaleReturn(sale: widget.sale, quantities: quantities);
      ref.invalidate(saleReturnsProvider);
      await ref.read(backendControllerProvider.future);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          submitting = false;
          error = exception.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          submitting = false;
          error = 'Unable to create the sale return. Please retry.';
        });
      }
    }
  }
}

class _SalesPeriodButton extends StatelessWidget {
  const _SalesPeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
      side: BorderSide(
        color: selected ? AppColors.primary : const Color(0xFFE1E7E5),
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : AppColors.ink,
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SalesFilterLabel extends StatelessWidget {
  const _SalesFilterLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    context.tr(label),
    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
  );
}

class _SalesToolbarButton extends StatelessWidget {
  const _SalesToolbarButton({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final IconData? trailing;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Icon(trailing, size: 18),
        ],
      ],
    ),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    ),
  );
}

class _SalesSummaryCard extends StatelessWidget {
  const _SalesSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.iconColor,
  });
  final String label, value;
  final IconData icon;
  final Color tint, iconColor;

  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(label),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SalesTableHeader extends StatelessWidget {
  const _SalesTableHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE1E7E5))),
    ),
    child: const Row(
      children: [
        Expanded(flex: 16, child: Text('Invoice')),
        Expanded(flex: 19, child: Text('Customer')),
        Expanded(flex: 16, child: Text('Date & time')),
        Expanded(flex: 9, child: Text('Items')),
        Expanded(flex: 13, child: Text('Total amount')),
        Expanded(flex: 15, child: Text('Payment / sync')),
        SizedBox(width: 64, child: Text('Actions')),
      ],
    ),
  );
}

class _SalesTransactionRow extends StatelessWidget {
  const _SalesTransactionRow({
    required this.sale,
    required this.compact,
    required this.onTap,
  });
  final Sale sale;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final synced = sale.syncStatus != SyncStatus.pending;
    if (compact) {
      return InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE1E7E5))),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE3F5EF),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.invoiceNo,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${sale.customer.name} • ${_SalesScreenState._dateTime(sale.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _SalePaymentBadge(sale: sale),
                        StatusBadge(
                          synced ? 'Synced' : 'Pending',
                          color: synced ? AppColors.primary : AppColors.accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(sale.total),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${sale.items.length} ${context.tr('items')}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE1E7E5))),
        ),
        child: Row(
          children: [
            Expanded(flex: 16, child: _invoice()),
            Expanded(flex: 19, child: _customer()),
            Expanded(
              flex: 16,
              child: Text(
                '${_SalesScreenState._date(sale.createdAt)}\n${_SalesScreenState._time(sale.createdAt)}',
              ),
            ),
            Expanded(
              flex: 9,
              child: Text('${sale.items.length}\n${context.tr('items')}'),
            ),
            Expanded(
              flex: 13,
              child: Text(
                money(sale.total),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              flex: 15,
              child: Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  _SalePaymentBadge(sale: sale),
                  StatusBadge(
                    synced ? 'Synced' : 'Pending sync',
                    color: synced ? AppColors.primary : AppColors.accent,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 64,
              child: IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.more_vert),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoice() => Row(
    children: [
      const CircleAvatar(
        backgroundColor: Color(0xFFE3F5EF),
        child: Icon(Icons.receipt_long_outlined, color: AppColors.primary),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          sale.invoiceNo,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  Widget _customer() =>
      Text(sale.customer.name, maxLines: 2, overflow: TextOverflow.ellipsis);
}

bool _isCreditSale(Sale sale) {
  final method = sale.paymentMethod.trim().toLowerCase();
  return method == 'due' || method == 'credit';
}

String _salePaymentLabel(BuildContext context, Sale sale) {
  if (_isCreditSale(sale)) return context.tr('Payment due');
  final method = sale.paymentMethod.trim();
  if (method.isEmpty) return context.tr('Paid');
  return '${context.tr('Paid')} • ${context.tr(method)}';
}

class _SalePaymentBadge extends StatelessWidget {
  const _SalePaymentBadge({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final credit = _isCreditSale(sale);
    return StatusBadge(
      _salePaymentLabel(context, sale),
      color: credit ? const Color(0xFFB7791F) : AppColors.primary,
    );
  }
}

class _SalePaymentSummary extends StatelessWidget {
  const _SalePaymentSummary({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final credit = _isCreditSale(sale);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: credit ? const Color(0xFFFFF7E8) : const Color(0xFFE9F6EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: credit ? const Color(0xFFE5B45B) : const Color(0xFF9DCEBA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            credit
                ? Icons.schedule_rounded
                : Icons.check_circle_outline_rounded,
            color: credit ? const Color(0xFF9A5B00) : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credit ? context.tr('Credit sale') : context.tr('Paid sale'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  credit
                      ? '${context.tr('Outstanding')}: ${money(sale.total)}'
                      : _salePaymentLabel(context, sale),
                  style: TextStyle(
                    color: credit ? const Color(0xFF7A4A00) : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          _SalePaymentBadge(sale: sale),
        ],
      ),
    );
  }
}

class _SalesMobileSectionHeader extends StatelessWidget {
  const _SalesMobileSectionHeader({
    required this.title,
    required this.icon,
    required this.count,
    this.iconColor = AppColors.primary,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final int count;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 11, 10, 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE1E7E5))),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: iconColor.withValues(alpha: .1),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            context.tr(title),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
        if (count > 0)
          Text(
            '$count',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 11),
            ),
            child: Text(context.tr('View all')),
          ),
        ],
      ],
    ),
  );
}

class _SalesPagination extends StatelessWidget {
  const _SalesPagination({
    required this.total,
    required this.page,
    required this.pageCount,
    required this.rowsPerPage,
    required this.onPageChanged,
    required this.onRowsChanged,
  });
  final int total, page, pageCount, rowsPerPage;
  final ValueChanged<int> onPageChanged, onRowsChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: LayoutBuilder(
      builder: (_, constraints) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            total == 0
                ? context.tr('No transactions')
                : '${context.tr('Showing')} ${(page - 1) * rowsPerPage + 1}–${math.min(page * rowsPerPage, total)} ${context.tr('of')} $total',
            style: const TextStyle(color: AppColors.muted),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.outlined(
                onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              StatusBadge('$page / $pageCount', color: AppColors.primary),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: page < pageCount
                    ? () => onPageChanged(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              if (constraints.maxWidth > 520) ...[
                const SizedBox(width: 16),
                Text(context.tr('Rows per page')),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: rowsPerPage,
                  items: const [10, 20, 50]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onRowsChanged(value);
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

class LegacyReportsScreen extends ConsumerWidget {
  const LegacyReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    final report = s.profitLoss;
    final total = report?.totalSales ?? 0;
    final trend = s.sales.take(10).toList().reversed.toList();
    final maxSale = trend.fold<int>(
      0,
      (maximum, sale) => sale.total > maximum ? sale.total : maximum,
    );
    final units = <String, int>{};
    for (final sale in s.sales) {
      for (final item in sale.items) {
        units.update(
          item.product.displayName(context.isArabic),
          (v) => v + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }
    final top = units.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return PagePad(
      child: ListView(
        children: [
          const PageTitle(
            'Sales report',
            subtitle: 'Performance reported by EazyERP.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (_, c) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: c.maxWidth > 800 ? 4 : 2,
              childAspectRatio: 1.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                MetricCard(
                  label: 'Total sales',
                  value: money(total),
                  icon: Icons.trending_up,
                ),
                MetricCard(
                  label: 'Total orders',
                  value: '${s.sales.length}',
                  icon: Icons.receipt,
                ),
                MetricCard(
                  label: 'Gross profit',
                  value: money(report?.grossProfit ?? 0),
                  icon: Icons.analytics_outlined,
                ),
                MetricCard(
                  label: 'Net profit',
                  value: money(report?.netProfit ?? 0),
                  icon: Icons.account_balance_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Sales trend'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 180,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final sale in trend)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Container(
                              height: maxSale == 0
                                  ? 0
                                  : 160 * sale.total / maxSale,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: .22),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Top selling products'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                for (final e in top.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.key),
                    trailing: StatusBadge('${e.value} sold'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    final offline = ref.watch(offlinePosControllerProvider);
    final register = ref.watch(cashRegisterControllerProvider).value;
    final offlineState = offline.value;
    return PagePad(
      child: ListView(
        children: [
          const PageTitle(
            'Synchronization',
            subtitle: 'Refresh data directly from EazyERP.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (_, c) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: c.maxWidth > 700 ? 3 : 1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.3,
              children: [
                const MetricCard(
                  label: 'Internet status',
                  value: 'Online',
                  icon: Icons.wifi,
                ),
                MetricCard(
                  label: 'Products',
                  value: '${s.products.length}',
                  icon: Icons.inventory_2_outlined,
                ),
                MetricCard(
                  label: 'Customers',
                  value: '${s.customers.length}',
                  icon: Icons.people_outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Offline POS readiness',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    StatusBadge(
                      offlineState?.ready == true ? 'Ready' : 'Not prepared',
                      color: offlineState?.ready == true
                          ? AppColors.primary
                          : AppColors.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  offlineState?.ready == true
                      ? '${offlineState!.pendingCount} sale(s) waiting to synchronize. ${offlineState.catalog.products.length} products cached. Authorization expires ${DateFormat('dd MMM yyyy, HH:mm').format(offlineState.context!.authorizedUntil.toLocal())}.'
                      : 'Connect once with an open register to authorize this device for offline cash sales.',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          offline.isLoading ||
                              register == null ||
                              s.locations.isEmpty
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(offlinePosControllerProvider.notifier)
                                    .prepare(
                                      locationId: register.locationId,
                                      cashRegisterId: register.id,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Offline POS is ready on this device.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.offline_bolt_outlined),
                      label: const Text('Prepare offline mode'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          offlineState?.pendingCount == 0 ||
                              offlineState?.syncing == true
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(offlinePosControllerProvider.notifier)
                                    .syncNow();
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              }
                            },
                      icon: offlineState?.syncing == true
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_sync_outlined),
                      label: Text(
                        'Sync queued sales (${offlineState?.pendingCount ?? 0})',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          offlineState?.ready != true || offline.isLoading
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(offlinePosControllerProvider.notifier)
                                    .refreshCatalogChanges();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Offline catalog is up to date.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Update offline catalog'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('Backend data'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.invalidate(backendControllerProvider),
                      icon: const Icon(Icons.sync),
                      label: Text(context.tr('Sync now')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_done_outlined),
                  title: Text('API-backed mode'),
                  subtitle: Text(
                    'Products, categories, customers, sales, stock, and reports are loaded from EazyERP.',
                  ),
                  trailing: StatusBadge('Connected'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStoreProvider);
    final business = state.business;
    final user = state.user;
    final locationNames = state.locations.map((item) => item.name).join(', ');
    final sections = [
      (
        'Business profile',
        '${business?.name ?? ''} • ${business?.currencyCode ?? ''} • ${business?.timeZone ?? ''}',
        Icons.store_outlined,
        null,
      ),
      (
        'Tax settings',
        business?.taxLabel.isNotEmpty == true
            ? business!.taxLabel
            : 'No default business tax',
        Icons.percent,
        null,
      ),
      ('Business locations', locationNames, Icons.location_on_outlined, null),
      (
        'User & profile',
        '${user?.name ?? ''} • ${user?.isAdmin == true ? 'Administrator' : user?.username ?? ''}',
        Icons.person_outline,
        null,
      ),
      (
        'Subscription & users',
        'View your package, included users and available seats',
        Icons.workspace_premium_outlined,
        '/settings/subscription',
      ),
      (
        'ZATCA e-invoicing',
        'Device onboarding, compliance status and invoice submissions',
        Icons.verified_user_outlined,
        '/zatca',
      ),
      (
        'Printers & documents',
        'Billing, quotation, kitchen and barcode printer profiles',
        Icons.print_outlined,
        '/settings/printers',
      ),
    ];
    return PagePad(
      child: ListView(
        children: [
          const PageTitle(
            'Settings',
            subtitle: 'Configure your business and connected services.',
          ),
          const SizedBox(height: 18),
          _BusinessSaleSettings(
            allowOverselling: state.allowOverselling,
            onChanged: (value) async {
              try {
                await ref
                    .read(backendControllerProvider.notifier)
                    .updateAllowOverselling(value);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value
                            ? 'Overselling is enabled for POS sales.'
                            : 'Overselling is disabled for POS sales.',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
          ),
          const SizedBox(height: 10),
          for (final section in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Surface(
                child: ListTile(
                  onTap: section.$4 == null
                      ? null
                      : () => context.go(section.$4!),
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(section.$3)),
                  title: Text(
                    context.tr(section.$1),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(context.tr(section.$2)),
                  trailing: section.$4 == null
                      ? null
                      : const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BusinessSaleSettings extends StatefulWidget {
  const _BusinessSaleSettings({
    required this.allowOverselling,
    required this.onChanged,
  });

  final bool allowOverselling;
  final Future<void> Function(bool value) onChanged;

  @override
  State<_BusinessSaleSettings> createState() => _BusinessSaleSettingsState();
}

class _BusinessSaleSettingsState extends State<_BusinessSaleSettings> {
  bool saving = false;

  @override
  Widget build(BuildContext context) => Surface(
    child: SwitchListTile.adaptive(
      value: widget.allowOverselling,
      onChanged: saving
          ? null
          : (value) async {
              setState(() => saving = true);
              try {
                await widget.onChanged(value);
              } finally {
                if (mounted) setState(() => saving = false);
              }
            },
      contentPadding: EdgeInsets.zero,
      secondary: saving
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const CircleAvatar(child: Icon(Icons.inventory_outlined)),
      title: const Text(
        'Allow overselling',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        'When enabled, POS users can complete a sale even when available stock is zero. This changes the ERP business setting for all POS users.',
      ),
    ),
  );
}
