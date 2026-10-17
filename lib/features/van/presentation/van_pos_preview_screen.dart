import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Visual prototype only. No order is submitted or stock changed here.
class VanPosPreviewScreen extends StatefulWidget {
  const VanPosPreviewScreen({super.key});

  @override
  State<VanPosPreviewScreen> createState() => _VanPosPreviewScreenState();
}

class _VanPosPreviewScreenState extends State<VanPosPreviewScreen> {
  static const _ink = Color(0xFF172521);
  static const _muted = Color(0xFF687874);
  static const _border = Color(0xFFDCE7E2);
  static const _surface = Color(0xFFF6F9F7);
  static const _products = [
    _VanProduct(
      'Water 500 ml',
      'Beverages',
      2.00,
      120,
      Icons.water_drop_outlined,
    ),
    _VanProduct(
      'Orange Juice',
      'Beverages',
      5.50,
      48,
      Icons.local_drink_outlined,
    ),
    _VanProduct('Potato Chips', 'Snacks', 3.00, 72, Icons.fastfood_outlined),
    _VanProduct('Chocolate Bar', 'Snacks', 4.00, 36, Icons.cookie_outlined),
  ];

  final _quantities = <int, int>{0: 4, 1: 2};
  String _query = '';
  String _customer = 'Al Noor Mini Market';
  String _payment = 'Cash';

  double get _subtotal => _quantities.entries.fold(
    0,
    (total, entry) => total + _products[entry.key].price * entry.value,
  );

  void _changeQuantity(int index, int delta) {
    setState(() {
      final next = (_quantities[index] ?? 0) + delta;
      if (next <= 0) {
        _quantities.remove(index);
      } else if (next <= _products[index].stock) {
        _quantities[index] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 980;
    final horizontal = width < 600 ? 16.0 : 28.0;
    final catalog = _catalog();
    final order = _order();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: horizontal,
        title: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text(
              'Van POS',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            if (width >= 650) ...[
              const SizedBox(width: 18),
              const _Tag('Design preview', Icons.visibility_outlined),
            ],
          ],
        ),
        actions: [
          if (width >= 600)
            const Padding(
              padding: EdgeInsets.only(right: 24),
              child: Center(
                child: _Tag('Route 04 · Van 02', Icons.route_outlined),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heading(compact),
                  const SizedBox(height: 20),
                  _routeStrip(compact),
                  const SizedBox(height: 20),
                  if (compact) ...[
                    catalog,
                    const SizedBox(height: 16),
                    order,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: catalog),
                        const SizedBox(width: 18),
                        Expanded(flex: 4, child: order),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(bool compact) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 12,
    children: [
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New van sale',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Sell from vehicle stock at each stop on your route.',
            style: TextStyle(color: _muted),
          ),
        ],
      ),
      const _Tag('On route · Stop 3 of 12', Icons.near_me_outlined),
    ],
  );

  Widget _routeStrip(bool compact) => _Card(
    child: Wrap(
      spacing: 20,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _Metric('Today’s route', 'North Riyadh', Icons.route_outlined),
        const _Metric('Vehicle', 'Van 02', Icons.local_shipping_outlined),
        const _Metric('Current stop', '3 / 12', Icons.pin_drop_outlined),
        const _Metric(
          'Van stock value',
          'SAR 1,284.00',
          Icons.inventory_2_outlined,
        ),
      ],
    ),
  );

  Widget _catalog() => Column(
    children: [
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer & stop',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _customer,
              isExpanded: true,
              decoration: _input('Customer', Icons.storefront_outlined),
              items: const [
                DropdownMenuItem(
                  value: 'Al Noor Mini Market',
                  child: Text('Al Noor Mini Market'),
                ),
                DropdownMenuItem(
                  value: 'Walk-in customer',
                  child: Text('Walk-in customer'),
                ),
                DropdownMenuItem(
                  value: 'Green Corner Grocery',
                  child: Text('Green Corner Grocery'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _customer = value ?? _customer),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.location_on_outlined, size: 17, color: _muted),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Stop 3 · King Fahd Road, Riyadh',
                    style: TextStyle(color: _muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Products in van',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                Text(
                  '${_products.length} items',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase().trim()),
              decoration: _input(
                'Search or scan product',
                Icons.search_rounded,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _products.length; i++)
              if (_products[i].name.toLowerCase().contains(_query)) ...[
                if (i != 0) const Divider(height: 1, color: _border),
                _productRow(i),
              ],
            if (_products.every(
              (product) => !product.name.toLowerCase().contains(_query),
            ))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text(
                    'No matching products in this van.',
                    style: TextStyle(color: _muted),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _productRow(int index) {
    final product = _products[index];
    final quantity = _quantities[index] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5F0),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(product.icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                Text(
                  '${product.category} · ${product.stock} in van',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          Text(
            'SAR ${product.price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          if (quantity == 0)
            IconButton.filledTonal(
              tooltip: 'Add ${product.name}',
              onPressed: () => _changeQuantity(index, 1),
              icon: const Icon(Icons.add),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  onPressed: () => _changeQuantity(index, -1),
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 25,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => _changeQuantity(index, 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _order() => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Current order',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(_customer, style: const TextStyle(color: _muted)),
        const SizedBox(height: 16),
        if (_quantities.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Add products from the van to start an order.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
            ),
          )
        else
          for (final entry in _quantities.entries) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${entry.value} × ${_products[entry.key].name}',
                    style: const TextStyle(color: _ink),
                  ),
                ),
                Text(
                  'SAR ${(_products[entry.key].price * entry.value).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        const Divider(height: 24, color: _border),
        _totalRow('Subtotal', _subtotal),
        const SizedBox(height: 8),
        _totalRow('Discount', 0),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F4EE),
            borderRadius: BorderRadius.circular(11),
          ),
          child: _totalRow('Total', _subtotal, emphasized: true),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment method',
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        const SizedBox(height: 9),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Cash',
              label: Text('Cash'),
              icon: Icon(Icons.payments_outlined),
            ),
            ButtonSegment(
              value: 'Card',
              label: Text('Card'),
              icon: Icon(Icons.credit_card_outlined),
            ),
            ButtonSegment(
              value: 'Credit',
              label: Text('Credit'),
              icon: Icon(Icons.person_outline),
            ),
          ],
          selected: {_payment},
          onSelectionChanged: (values) =>
              setState(() => _payment = values.first),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle_outline),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Text('Complete sale'),
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Design preview only · No sale or stock movement is recorded.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: _muted),
        ),
      ],
    ),
  );

  Widget _totalRow(String label, double value, {bool emphasized = false}) =>
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w400,
                color: emphasized ? AppColors.primary : _muted,
              ),
            ),
          ),
          Text(
            'SAR ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: emphasized ? 20 : 14,
              fontWeight: FontWeight.w800,
              color: emphasized ? AppColors.primary : _ink,
            ),
          ),
        ],
      );

  InputDecoration _input(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _border),
      borderRadius: BorderRadius.circular(10),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
  );
}

class _VanProduct {
  const _VanProduct(
    this.name,
    this.category,
    this.price,
    this.stock,
    this.icon,
  );
  final String name;
  final String category;
  final double price;
  final int stock;
  final IconData icon;
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFDCE7E2)),
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [
        BoxShadow(
          color: Color(0x090A3930),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF5F0),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF687874)),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172521),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
