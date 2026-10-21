import 'dart:math';

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../../shared/models/entities.dart';
import '../../auth/auth_controller.dart';
import '../../backend/presentation/backend_controller.dart';
import '../../cash_register/presentation/cash_register_controller.dart';
import '../../invoice_layouts/presentation/invoice_layout_controller.dart';
import '../../pos/pos_screen.dart' show showPosCustomerSelector;
import '../../printers/application/printer_controller.dart';
import '../../settings/application/payment_method_settings_controller.dart';
import '../../store/app_store.dart';
import '../../../shared/widgets/localized_text.dart';
import '../domain/fuel_calculation.dart';

class FuelPosScreen extends ConsumerStatefulWidget {
  const FuelPosScreen({super.key});

  @override
  ConsumerState<FuelPosScreen> createState() => _FuelPosScreenState();
}

class _FuelPosScreenState extends ConsumerState<FuelPosScreen> {
  final _vehicleController = TextEditingController();
  final _odometerController = TextEditingController();
  final _pumpController = TextEditingController();
  final _nozzleController = TextEditingController();
  final _amountController = TextEditingController();
  final _litresController = TextEditingController();
  final _cashReceivedController = TextEditingController();
  final _random = Random.secure();
  final _lines = <FuelLine>[];
  String? _selectedProductId;
  String? _customerId;
  String _paymentMethod = 'cash';
  bool _editingAmount = true;
  bool _submitting = false;
  bool _mobileBillView = false;
  String? _error;
  String? _pendingTransactionId;
  String? _pendingSaleFingerprint;

  Future<void> _selectCustomer(AppState state) => showPosCustomerSelector(
    context,
    ref,
    state,
    selectedCustomer:
        state.customers
            .where((customer) => customer.id == _customerId)
            .firstOrNull ??
        state.customers.firstOrNull,
    onSelected: (customer) => setState(() {
      _customerId = customer.id;
      _pendingTransactionId = null;
      _pendingSaleFingerprint = null;
    }),
  );

  Widget _customerPicker(AppState state, {required bool mobile}) {
    final selected = state.customers
        .where((customer) => customer.id == _customerId)
        .firstOrNull;
    final name = selected?.name ?? state.customers.firstOrNull?.name;
    return Semantics(
      button: true,
      label: 'Search or add customer',
      child: OutlinedButton(
        onPressed: _submitting ? null : () => _selectCustomer(state),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: mobile ? 11 : 15,
          ),
          alignment: AlignmentDirectional.centerStart,
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name ?? context.tr('Select customer'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.search_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    _odometerController.dispose();
    _pumpController.dispose();
    _nozzleController.dispose();
    _amountController.dispose();
    _litresController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  String _gradeName(Product product) =>
      '${product.name} ${product.nameEn} ${product.nameAr}'.toLowerCase();

  List<Product> _fuelProducts(AppState state) {
    final fuelCategoryIds = state.categories
        .where(
          (category) => RegExp(
            r'fuel|petrol|diesel|gasoline|وقود|بنزين|ديزل',
            caseSensitive: false,
          ).hasMatch('${category.name} ${category.nameEn} ${category.nameAr}'),
        )
        .map((category) => category.id)
        .toSet();
    return state.products
        .where(
          (product) =>
              product.active &&
              product.sellingPrice > 0 &&
              (fuelCategoryIds.contains(product.categoryId) ||
                  RegExp(
                    r'fuel|petrol|diesel|gasoline|وقود|بنزين|ديزل',
                    caseSensitive: false,
                  ).hasMatch(_gradeName(product))),
        )
        .toList(growable: false);
  }

  void _recalculateFromAmount(Product product) {
    final cents = FuelLine.parseMoney(_amountController.text);
    final price = FuelLine(
      product: product,
      quantityUnits: 1,
    ).priceCentsIncludingTax;
    final units = cents == null
        ? null
        : FuelLine.litresFromAmount(cents, price);
    _litresController.text = units == null || units <= 0
        ? ''
        : (units / 10000).toStringAsFixed(4);
    setState(() => _error = null);
  }

  void _recalculateFromLitres(Product product) {
    final units = FuelLine.parseLitres(_litresController.text);
    _amountController.text = units == null || units <= 0
        ? ''
        : (FuelLine(product: product, quantityUnits: units).totalCents / 100)
              .toStringAsFixed(2);
    setState(() => _error = null);
  }

  void _addLine(Product? product) {
    if (product == null) return;
    final units = FuelLine.parseLitres(_litresController.text);
    if (units == null || units <= 0) {
      setState(() => _error = 'Enter a valid amount or quantity in litres.');
      return;
    }
    final line = FuelLine(product: product, quantityUnits: units);
    if (line.totalCents <= 0) {
      setState(() => _error = 'The fuel amount must be at least 0.01.');
      return;
    }
    setState(() {
      _lines.add(line);
      _amountController.clear();
      _litresController.clear();
      _cashReceivedController.clear();
      _error = null;
      if (MediaQuery.sizeOf(context).width < 560) _mobileBillView = true;
    });
  }

  void _clearSale() {
    setState(() {
      _lines.clear();
      _vehicleController.clear();
      _odometerController.clear();
      _pumpController.clear();
      _nozzleController.clear();
      _amountController.clear();
      _litresController.clear();
      _pendingTransactionId = null;
      _pendingSaleFingerprint = null;
      _error = null;
      _mobileBillView = false;
    });
  }

  bool _isWalkIn(Customer customer) {
    final value = '${customer.name} ${customer.businessName}'.toLowerCase();
    return value.contains('walk-in') || value.contains('walk in');
  }

  String _transactionId() {
    String block(int length) => List.generate(
      length,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    return '${block(8)}-${block(4)}-4${block(3)}-a${block(3)}-${block(12)}';
  }

  Future<void> _checkout(AppState state) async {
    if (_submitting || _lines.isEmpty) return;
    final paymentSettings = ref.read(paymentMethodSettingsProvider);
    final enabledPaymentCodes = ref
        .read(paymentMethodSettingsProvider)
        .apply(state.posPaymentOptions)
        .where((option) => option.code.toLowerCase() != 'due')
        .map((option) => option.code.toLowerCase())
        .toList(growable: true);
    if (paymentSettings.upiId.isNotEmpty) enabledPaymentCodes.add('upi');
    if (enabledPaymentCodes.isEmpty) return;
    final selectedPaymentMethod = enabledPaymentCodes.contains(_paymentMethod)
        ? _paymentMethod
        : enabledPaymentCodes.first;
    final paymentMethod = selectedPaymentMethod == 'upi'
        ? 'bank_transfer'
        : selectedPaymentMethod;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final customer =
          state.customers.where((item) => item.id == _customerId).firstOrNull ??
          state.customers.firstOrNull;
      if (customer == null || int.tryParse(customer.id) == null) {
        setState(() => _error = 'Select a customer before checkout.');
        return;
      }
      if (paymentMethod == 'credit' &&
          (_customerId == null || _isWalkIn(customer))) {
        setState(
          () => _error =
              'Select a registered customer before creating a credit sale.',
        );
        return;
      }
      final register = await ref.read(cashRegisterControllerProvider.future);
      if (!mounted) return;
      if (register == null) {
        setState(() => _error = 'Open a cash register before checkout.');
        return;
      }
      final token = await ref.read(authControllerProvider.future);
      if (!mounted) return;
      if (token == null || token == 'offline-local-session') {
        setState(
          () => _error =
              'Fuel checkout requires an online connection. The sale has not been submitted.',
        );
        return;
      }
      final total = _lines.fold<int>(0, (sum, line) => sum + line.totalCents);
      final metadata = FuelSaleMetadata(
        vehicleNumber: _vehicleController.text,
        odometer: _odometerController.text,
        pumpNumber: _pumpController.text,
        nozzleNumber: _nozzleController.text,
      );
      if (int.tryParse(register.locationId) == null ||
          int.tryParse(register.id) == null ||
          _lines.any(
            (line) =>
                int.tryParse(line.product.id) == null ||
                int.tryParse(line.product.variationId) == null,
          )) {
        setState(
          () => _error =
              'Fuel product or register data is invalid. Refresh and retry.',
        );
        return;
      }
      final fingerprint = [
        register.id,
        customer.id,
        metadata.saleNote,
        paymentMethod,
        for (final line in _lines)
          '${line.product.id}:${line.product.variationId}:${line.quantityUnits}:${line.priceCentsIncludingTax}',
      ].join('|');
      if (_pendingSaleFingerprint != fingerprint) {
        _pendingSaleFingerprint = fingerprint;
        _pendingTransactionId = _transactionId();
      }
      final id = _pendingTransactionId!;
      final sell = <String, dynamic>{
        'client_transaction_id': id,
        'location_id': int.parse(register.locationId),
        'cash_register_id': int.parse(register.id),
        'contact_id': int.parse(customer.id),
        'status': 'final',
        'source': 'connector_flutter',
        'is_kitchen_order': 0,
        'discount_type': 'fixed',
        'discount_amount': '0.00',
        'tax_rate_id': null,
        'sale_note': metadata.saleNote,
        if (paymentMethod == 'credit' &&
            customer.payTermNumber.trim().isNotEmpty)
          'pay_term_number':
              int.tryParse(customer.payTermNumber) ?? customer.payTermNumber,
        if (paymentMethod == 'credit' &&
            customer.payTermNumber.trim().isNotEmpty)
          'pay_term_type': customer.payTermType,
        'products': [
          for (final line in _lines)
            {
              'product_id': int.parse(line.product.id),
              'variation_id': int.parse(line.product.variationId),
              'quantity': line.quantityForApi,
              'unit_price_inc_tax': line.unitPriceForApi,
              'tax_rate_id': line.product.taxId.isEmpty
                  ? null
                  : int.tryParse(line.product.taxId),
              'discount_type': 'fixed',
              'discount_amount': '0.00',
            },
        ],
        'client_calculation': {
          'lines': [
            for (final line in _lines)
              {
                'line_total': (line.totalCents / 100).toStringAsFixed(2),
                'order_discount': '0.00',
                'payable_total': (line.totalCents / 100).toStringAsFixed(2),
              },
          ],
          'subtotal': (total / 100).toStringAsFixed(2),
          'discount_total': '0.00',
          'order_tax_total': '0.00',
          'final_total': (total / 100).toStringAsFixed(2),
        },
        if (paymentMethod != 'credit')
          'payments': [
            {
              'method': paymentMethod,
              'amount': (total / 100).toStringAsFixed(2),
            },
          ],
      };
      final result = await ref
          .read(apiProvider)
          .createSalePayload(accessToken: token, sell: sell);
      if (!mounted) return;
      final transactionId =
          (result['transaction_id'] ??
                  result['server_transaction_id'] ??
                  result['id'])
              ?.toString() ??
          '';
      final invoiceNo =
          result['official_invoice_no']?.toString() ??
          result['invoice_no']?.toString() ??
          '';
      final fuelLines = List<FuelLine>.from(_lines);
      final now = DateTime.now();
      final completedSale = Sale(
        localId: 'server-$transactionId',
        serverId: transactionId.isEmpty ? null : transactionId,
        invoiceNo: invoiceNo,
        createdAt: now,
        updatedAt: now,
        customer: customer,
        items: [
          for (final line in fuelLines)
            CartLine(
              product: line.product,
              quantity: line.quantityUnits / 10000,
              saleUnitPriceIncTax: line.priceCentsIncludingTax,
            ),
        ],
        paymentMethod: paymentMethod,
        total: total,
        tax: fuelLines.fold<int>(0, (sum, line) => sum + line.taxCents),
        discount: 0,
        syncStatus: SyncStatus.synced,
        status: 'final',
        paymentStatus: paymentMethod == 'credit' ? 'due' : 'paid',
        locationId: register.locationId,
        saleNote: metadata.saleNote,
      );
      setState(() {
        _lines.clear();
        _vehicleController.clear();
        _odometerController.clear();
        _pumpController.clear();
        _nozzleController.clear();
        _cashReceivedController.clear();
        _pendingTransactionId = null;
        _pendingSaleFingerprint = null;
        _mobileBillView = false;
      });
      final printers = ref.read(printerControllerProvider);
      if (printers.settings.posPrintingEnabled && transactionId.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fuel sale completed${invoiceNo.isEmpty ? '' : ' • $invoiceNo'} • Printing…',
            ),
          ),
        );
        try {
          await _printCompletedSaleWithRetry(
            completedSale,
            state.business?.name ?? 'Eazy POS',
            arabic:
                Localizations.localeOf(context).languageCode.toLowerCase() ==
                'ar',
          );
        } catch (printError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Sale completed, but receipt printing failed: $printError',
                ),
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printers.settings.posPrintingEnabled
                  ? 'Fuel sale completed, but the server did not return an invoice ID for printing.'
                  : 'Fuel sale completed • Printing is turned off.',
            ),
          ),
        );
      }
      try {
        await ref
            .read(backendControllerProvider.notifier)
            .refreshSalesHistory();
      } catch (_) {
        // The server already accepted the sale; history can refresh later.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Unable to submit fuel sale. Check the connection and retry.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _printCompletedSaleWithRetry(
    Sale sale,
    String businessName, {
    required bool arabic,
  }) async {
    Object? lastError;
    for (final delay in const [
      Duration.zero,
      Duration(milliseconds: 700),
      Duration(seconds: 2),
    ]) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      try {
        final printers = ref.read(printerControllerProvider);
        await ref
            .read(invoiceLayoutControllerProvider.notifier)
            .printSale(
              sale: sale,
              businessName: businessName,
              settings: printers.settings,
              printers: printers.selectedPrinters,
              arabic: arabic,
            );
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('Unable to print the completed sale.');
  }

  Future<void> _completeSale(
    AppState state,
    int total,
    String currency,
    String upiId,
  ) async {
    if (_paymentMethod != 'upi') {
      await _checkout(state);
      return;
    }
    if (upiId.isEmpty) {
      setState(
        () => _error = 'Add a UPI ID in Settings before using QR payment.',
      );
      return;
    }
    if (currency.toUpperCase() != 'INR') {
      setState(
        () => _error =
            'UPI QR supports INR payments only. Select another payment method for $currency.',
      );
      return;
    }
    final businessName = state.business?.name.trim().isNotEmpty == true
        ? state.business!.name.trim()
        : 'Eazy POS';
    final amount = (total / 100).toStringAsFixed(2);
    final qrData = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': businessName,
        'am': amount,
        'cu': 'INR',
        'tn': 'Fuel sale',
      },
    ).toString();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_2),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('Scan to pay'))),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$currency $amount',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 230,
                  child: CustomPaint(painter: _QrCodePainter(qrData)),
                ),
              ),
              const SizedBox(height: 12),
              Text(upiId, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                context.tr('Confirm only after the payment is received.'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.verified_outlined),
            label: Text(context.tr('Payment received')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _checkout(state);
  }

  IconData _paymentIcon(String code) => switch (code.toLowerCase()) {
    'cash' => Icons.payments_outlined,
    'card' => Icons.credit_card_outlined,
    'cheque' => Icons.receipt_long_outlined,
    'bank_transfer' => Icons.account_balance_outlined,
    'upi' => Icons.qr_code_2,
    'credit' => Icons.person_outline,
    _ => Icons.more_horiz,
  };

  Color _fuelColor(Product product) {
    final name = _gradeName(product);
    if (name.contains('95')) return const Color(0xFFD7191C);
    if (name.contains('diesel')) return const Color(0xFF68706E);
    return const Color(0xFF16A45B);
  }

  int _includedTax(FuelLine line) {
    final rate = line.product.taxPercent;
    if (rate <= 0) return 0;
    return line.totalCents - (line.totalCents * 100 / (100 + rate)).round();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStoreProvider);
    final products = _fuelProducts(state);
    final selected =
        products.where((item) => item.id == _selectedProductId).firstOrNull ??
        products.firstOrNull;
    final price = selected == null
        ? 0
        : FuelLine(product: selected, quantityUnits: 1).priceCentsIncludingTax;
    final total = _lines.fold<int>(0, (sum, line) => sum + line.totalCents);
    final paymentSettings = ref.watch(paymentMethodSettingsProvider);
    final paymentCodes = paymentSettings
        .apply(state.posPaymentOptions)
        .where((item) => item.code.toLowerCase() != 'due')
        .toList(growable: true);
    if (paymentSettings.upiId.isNotEmpty) {
      paymentCodes.add(const PaymentOption(code: 'upi', label: 'UPI / QR'));
    }
    final tax = _lines.fold<int>(0, (sum, line) => sum + _includedTax(line));
    final subtotal = total - tax;
    final currency = state.business?.currencyCode.trim().isNotEmpty == true
        ? state.business!.currencyCode
        : 'SAR';
    final colors = Theme.of(context).colorScheme;
    final outline = colors.outlineVariant.withValues(alpha: .75);

    InputDecoration fieldDecoration(
      String label,
      IconData icon, {
      String? suffix,
    }) => InputDecoration(
      labelText: context.tr(label),
      prefixIcon: Icon(icon, size: 20),
      suffixText: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: outline),
      ),
    );

    Widget sectionHeader(String title, {Widget? action}) => Row(
      children: [
        Expanded(
          child: Text(
            context.tr(title),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null) action,
      ],
    );

    Widget panel({required Widget child}) => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE7E3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A3D32).withValues(alpha: .06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final veryNarrow = constraints.maxWidth < 560;
        final details = Padding(
          padding: EdgeInsets.all(veryNarrow ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (veryNarrow) ...[
                    IconButton(
                      tooltip: context.tr('Back'),
                      onPressed: () => setState(() => _mobileBillView = false),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F5EF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.local_gas_station,
                      color: colors.primary,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('New fuel sale'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.35,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr(
                            'Manual forecourt billing. Pump authorization and tank readings require a forecourt controller integration.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _customerPicker(state, mobile: false),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, fieldConstraints) {
                  final stacked = fieldConstraints.maxWidth < 560;
                  final vehicleField = TextField(
                    controller: _vehicleController,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.characters,
                    decoration: fieldDecoration(
                      'Vehicle number (optional)',
                      Icons.directions_car_outlined,
                    ).copyWith(counterText: ''),
                  );
                  final odometerField = TextField(
                    controller: _odometerController,
                    keyboardType: TextInputType.number,
                    decoration: fieldDecoration(
                      'Odometer (optional)',
                      Icons.speed_outlined,
                      suffix: 'km',
                    ),
                  );
                  return stacked
                      ? Column(
                          children: [
                            vehicleField,
                            const SizedBox(height: 10),
                            odometerField,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: vehicleField),
                            const SizedBox(width: 10),
                            Expanded(child: odometerField),
                          ],
                        );
                },
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, fieldConstraints) {
                  final stacked = fieldConstraints.maxWidth < 560;
                  final fields = <Widget>[
                    TextField(
                      controller: _pumpController,
                      keyboardType: TextInputType.number,
                      decoration: fieldDecoration(
                        'Pump number (optional)',
                        Icons.local_gas_station_outlined,
                      ),
                    ),
                    TextField(
                      controller: _nozzleController,
                      keyboardType: TextInputType.number,
                      decoration: fieldDecoration(
                        'Nozzle number (optional)',
                        Icons.gas_meter_outlined,
                      ),
                    ),
                    TextFormField(
                      initialValue: state.user?.name ?? '',
                      readOnly: true,
                      decoration: fieldDecoration(
                        'Attendant',
                        Icons.badge_outlined,
                      ),
                    ),
                  ];
                  if (stacked) {
                    return Column(
                      children: [
                        fields[0],
                        const SizedBox(height: 10),
                        fields[1],
                        const SizedBox(height: 10),
                        fields[2],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: 10),
                      Expanded(child: fields[1]),
                      const SizedBox(width: 10),
                      Expanded(child: fields[2]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),
              sectionHeader(
                'Fuel products',
                action: OutlinedButton.icon(
                  onPressed: () => context.go('/products'),
                  icon: const Icon(Icons.settings_outlined, size: 17),
                  label: Text(context.tr('Manage products')),
                ),
              ),
              const SizedBox(height: 10),
              if (products.isEmpty)
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: veryNarrow ? 2 : 4,
                  childAspectRatio: veryNarrow ? 1.35 : 1.28,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    for (final placeholder in const [
                      ('Petrol 91', Color(0xFF16A45B)),
                      ('Diesel', Color(0xFF16A45B)),
                      ('Petrol 95', Color(0xFFD7191C)),
                      ('Premium Diesel', Color(0xFF68706E)),
                    ])
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => context.go('/products'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: outline),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0A3D32,
                                ).withValues(alpha: .035),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.water_drop,
                                color: placeholder.$2.withValues(alpha: .45),
                                size: 28,
                              ),
                              const Spacer(),
                              Text(
                                context.tr(placeholder.$1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '+ ${context.tr('Configure product')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: veryNarrow ? 2 : 4,
                    childAspectRatio: veryNarrow ? 1.35 : 1.28,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isSelected = product.id == selected?.id;
                    final productPrice = FuelLine(
                      product: product,
                      quantityUnits: 1,
                    ).priceCentsIncludingTax;
                    final color = _fuelColor(product);
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() {
                        _selectedProductId = product.id;
                        if (_editingAmount) {
                          _recalculateFromAmount(product);
                        } else {
                          _recalculateFromLitres(product);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE8F7F2)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? colors.primary : outline,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? colors.primary.withValues(alpha: .10)
                                  : const Color(
                                      0xFF0A3D32,
                                    ).withValues(alpha: .035),
                              blurRadius: isSelected ? 16 : 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: .10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.water_drop,
                                    color: color,
                                    size: 24,
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: colors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${(productPrice / 100).toStringAsFixed(2)} / ${context.tr('litre')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '● ${context.tr('Available')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FAF7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD3ECE4)),
                ),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final rate = Text(
                          '${context.tr('Fuel rate')}: ${(price / 100).toStringAsFixed(2)} / ${context.tr('litre')}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        );
                        final selector = SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: true,
                              label: Text(context.tr('By amount')),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text(context.tr('By litres')),
                            ),
                          ],
                          selected: {_editingAmount},
                          onSelectionChanged: (value) =>
                              setState(() => _editingAmount = value.first),
                          showSelectedIcon: false,
                        );
                        if (innerConstraints.maxWidth < 640) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              rate,
                              const SizedBox(height: 8),
                              selector,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: rate),
                            selector,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            readOnly: !_editingAmount,
                            decoration: fieldDecoration(
                              'Amount',
                              Icons.paid_outlined,
                              suffix: currency,
                            ),
                            onChanged: (_) {
                              if (selected != null) {
                                _editingAmount = true;
                                _recalculateFromAmount(selected);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _litresController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            readOnly: _editingAmount,
                            decoration: fieldDecoration(
                              'Litres',
                              Icons.water_drop_outlined,
                              suffix: context.tr('litres'),
                            ),
                            onChanged: (_) {
                              if (selected != null) {
                                _editingAmount = false;
                                _recalculateFromLitres(selected);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final quickAmounts = Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (innerConstraints.maxWidth >= 480)
                              Text(context.tr('Quick amounts')),
                            for (final amount in [50, 100, 200])
                              OutlinedButton(
                                onPressed: selected == null
                                    ? null
                                    : () {
                                        _amountController.text = amount
                                            .toString();
                                        _editingAmount = true;
                                        _recalculateFromAmount(selected);
                                      },
                                child: Text('$amount'),
                              ),
                          ],
                        );
                        final addButton = FilledButton.icon(
                          onPressed: selected == null || _submitting
                              ? null
                              : () => _addLine(selected),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(context.tr('Add fuel to bill')),
                        );
                        if (innerConstraints.maxWidth < 640) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              quickAmounts,
                              const SizedBox(height: 8),
                              addButton,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: quickAmounts),
                            const SizedBox(width: 8),
                            addButton,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        final summary = Padding(
          padding: EdgeInsets.all(veryNarrow ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F5EF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('Bill'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _lines.isEmpty || _submitting
                        ? null
                        : _clearSale,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(context.tr('Clear all')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_lines.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(context.tr('No fuel added yet.')),
                ),
              for (var index = 0; index < _lines.length; index++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBFDFC),
                    border: Border.all(color: const Color(0xFFDDE7E3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.water_drop,
                          color: _fuelColor(_lines[index].product),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lines[index].product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${_lines[index].quantityForApi} ${context.tr('litres')} × ${_lines[index].unitPriceForApi}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$currency ${(_lines[index].totalCents / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _lines.removeAt(index)),
                        icon: const Icon(Icons.delete_outline),
                        color: colors.error,
                      ),
                    ],
                  ),
                ),
              if (veryNarrow && _lines.isNotEmpty) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _mobileBillView = false),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Add more fuel')),
                ),
                const SizedBox(height: 8),
              ],
              const Divider(),
              _FuelTotalRow(
                label: context.tr('Subtotal'),
                value: '$currency ${(subtotal / 100).toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              _FuelTotalRow(
                label: context.tr('VAT'),
                value: '$currency ${(tax / 100).toStringAsFixed(2)}',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBE8DF)),
                ),
                child: _FuelTotalRow(
                  label: context.tr('Total'),
                  value: '$currency ${(total / 100).toStringAsFixed(2)}',
                  emphasized: true,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('Payment method'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (paymentCodes.isNotEmpty)
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final option in paymentCodes)
                      SizedBox(
                        width: narrow ? 112 : 94,
                        height: 84,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _submitting
                              ? null
                              : () => setState(
                                  () => _paymentMethod = option.code
                                      .toLowerCase(),
                                ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: option.code.toLowerCase() == _paymentMethod
                                  ? const Color(0xFFE8F7F2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    option.code.toLowerCase() == _paymentMethod
                                    ? colors.primary
                                    : outline,
                                width:
                                    option.code.toLowerCase() == _paymentMethod
                                    ? 2
                                    : 1,
                              ),
                              boxShadow:
                                  option.code.toLowerCase() == _paymentMethod
                                  ? [
                                      BoxShadow(
                                        color: colors.primary.withValues(
                                          alpha: .10,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _paymentIcon(option.code),
                                  color:
                                      option.code.toLowerCase() ==
                                          _paymentMethod
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  context.tr(option.label),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (paymentCodes.isEmpty)
                const Text(
                  'Enable a payment method in settings to complete a fuel sale.',
                ),
              const SizedBox(height: 14),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: _lines.isEmpty || _submitting || paymentCodes.isEmpty
                    ? null
                    : () => _completeSale(
                        state,
                        total,
                        currency,
                        paymentSettings.upiId,
                      ),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  '${context.tr(_submitting ? 'Submitting…' : 'Complete sale')}   $currency ${(total / 100).toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colors.primary, size: 20),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        context.tr(
                          'Fuel sales currently require an online connection. No sale is recorded until the server confirms it.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        Widget mobileFuelCard(Product product) {
          final isSelected = product.id == selected?.id;
          final fuelColor = _fuelColor(product);
          final productPrice = FuelLine(
            product: product,
            quantityUnits: 1,
          ).priceCentsIncludingTax;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() {
              _selectedProductId = product.id;
              _editingAmount
                  ? _recalculateFromAmount(product)
                  : _recalculateFromLitres(product);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEEFAF5) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? colors.primary : const Color(0xFFDCE5E2),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_gas_station, color: fuelColor, size: 26),
                      const Spacer(),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: colors.primary,
                          size: 18,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$currency ${(productPrice / 100).toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget mobileCompactField(
          TextEditingController controller,
          String label,
          IconData icon, {
          TextInputType? keyboardType,
        }) => TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: context.tr(label),
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 13,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        final estimatedUnits = selected == null
            ? null
            : FuelLine.parseLitres(_litresController.text);
        final mobileEntry = Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F5EF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.local_gas_station, color: colors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('New Fuel Sale'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          context.tr(
                            'Select fuel product and enter amount or litres',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              if (products.isEmpty)
                OutlinedButton.icon(
                  onPressed: () => context.go('/products'),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Configure fuel products')),
                )
              else
                SizedBox(
                  height: 94,
                  child: products.length <= 4
                      ? Row(
                          children: [
                            for (
                              var index = 0;
                              index < products.length;
                              index++
                            ) ...[
                              Expanded(child: mobileFuelCard(products[index])),
                              if (index != products.length - 1)
                                const SizedBox(width: 7),
                            ],
                          ],
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 7),
                          itemBuilder: (context, index) => SizedBox(
                            width: 108,
                            child: mobileFuelCard(products[index]),
                          ),
                        ),
                ),
              const SizedBox(height: 10),
              _customerPicker(state, mobile: true),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: mobileCompactField(
                      _vehicleController,
                      'Vehicle number',
                      Icons.directions_car_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: mobileCompactField(
                      _odometerController,
                      'Odometer',
                      Icons.speed_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: mobileCompactField(
                      _pumpController,
                      'Pump number',
                      Icons.local_gas_station_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: mobileCompactField(
                      _nozzleController,
                      'Nozzle number',
                      Icons.gas_meter_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${selected?.name ?? context.tr('Fuel')} ${context.tr('rate')}: $currency ${(price / 100).toStringAsFixed(2)} / ${context.tr('litre')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 7),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(context.tr('Amount'))),
                  ButtonSegment(
                    value: false,
                    label: Text(context.tr('Litres')),
                  ),
                ],
                selected: {_editingAmount},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _editingAmount = value.first),
              ),
              const SizedBox(height: 8),
              TextField(
                key: ValueKey(_editingAmount),
                controller: _editingAmount
                    ? _amountController
                    : _litresController,
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
                decoration: InputDecoration(
                  hintText: context.tr(
                    _editingAmount ? 'Enter amount' : 'Enter litres',
                  ),
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: .72),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixText: _editingAmount ? '$currency  ' : null,
                  suffixText: _editingAmount ? null : context.tr('litres'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) {
                  if (selected == null) return;
                  _editingAmount
                      ? _recalculateFromAmount(selected)
                      : _recalculateFromLitres(selected);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var index = 0; index < 4; index++) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: selected == null
                            ? null
                            : () {
                                _editingAmount = true;
                                _amountController.text =
                                    '${[100, 200, 500, 1000][index]}';
                                _recalculateFromAmount(selected);
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                        ),
                        child: Text(
                          '${[100, 200, 500, 1000][index]}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    if (index < 3) const SizedBox(width: 5),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEFAF5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_gas_station,
                      color: colors.primary,
                      size: 27,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('You will get (approx)'),
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            '${estimatedUnits == null ? '0.00' : (estimatedUnits / 10000).toStringAsFixed(2)} ${context.tr('litres')}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              FilledButton.icon(
                onPressed: selected == null || _submitting
                    ? null
                    : () => _addLine(selected),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(context.tr('Add to Bill')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        );

        final totalQuantityUnits = _lines.fold<int>(
          0,
          (sum, line) => sum + line.quantityUnits,
        );
        final cashReceived =
            FuelLine.parseMoney(_cashReceivedController.text) ?? total;
        final change = max(0, cashReceived - total);
        final mobileBill = Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _mobileBillView = false),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      context.tr('Current Bill'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _lines.isEmpty ? null : _clearSale,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (var index = 0; index < _lines.length; index++)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: outline),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_gas_station,
                        color: _fuelColor(_lines[index].product),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lines[index].product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$currency ${_lines[index].unitPriceForApi} / L',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$currency ${(_lines[index].totalCents / 100).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${(_lines[index].quantityUnits / 10000).toStringAsFixed(2)} L',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => setState(() => _lines.removeAt(index)),
                        icon: const Icon(Icons.delete_outline),
                        color: colors.error,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _mobileBillView = false),
                icon: const Icon(Icons.add),
                label: Text(context.tr('Add more fuel')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(38),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Total Amount')),
                        Text(
                          '$currency ${(total / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(context.tr('Total Quantity')),
                      Text(
                        '${(totalQuantityUnits / 10000).toStringAsFixed(2)} L',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('Select Payment Method'),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: paymentCodes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final option = paymentCodes[index];
                    return SizedBox(
                      width: 72,
                      child: InkWell(
                        onTap: () => setState(
                          () => _paymentMethod = option.code.toLowerCase(),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: option.code.toLowerCase() == _paymentMethod
                                ? const Color(0xFFEEFAF5)
                                : Colors.white,
                            border: Border.all(
                              color: option.code.toLowerCase() == _paymentMethod
                                  ? colors.primary
                                  : outline,
                              width: option.code.toLowerCase() == _paymentMethod
                                  ? 2
                                  : 1,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_paymentIcon(option.code), size: 20),
                              const SizedBox(height: 3),
                              Text(
                                context.tr(option.label),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_paymentMethod == 'cash') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _cashReceivedController,
                  style: const TextStyle(fontSize: 15),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      fieldDecoration(
                        'Cash Received',
                        Icons.payments_outlined,
                        suffix: currency,
                      ).copyWith(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                      ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final amount in [500, 1000, 2000])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: OutlinedButton(
                            onPressed: () => setState(
                              () => _cashReceivedController.text = '$amount',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              '$currency $amount',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEFAF5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(context.tr('Balance / Change'))),
                      Text(
                        '$currency ${(change / 100).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 17,
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: colors.error)),
              ],
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _lines.isEmpty || paymentCodes.isEmpty || _submitting
                    ? null
                    : () => _completeSale(
                        state,
                        total,
                        currency,
                        paymentSettings.upiId,
                      ),
                icon: const Icon(Icons.check),
                label: Text(
                  context.tr(_submitting ? 'Submitting…' : 'Complete Sale'),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        );
        return ColoredBox(
          color: const Color(0xFFF4F7F6),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(veryNarrow ? 10 : 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: veryNarrow
                    ? panel(child: _mobileBillView ? mobileBill : mobileEntry)
                    : narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          panel(child: details),
                          const SizedBox(height: 12),
                          panel(child: summary),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: panel(child: details)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: panel(child: summary)),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FuelTotalRow extends StatelessWidget {
  const _FuelTotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            fontSize: emphasized ? 18 : null,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: emphasized ? 18 : null,
          color: emphasized ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    ],
  );
}

class _QrCodePainter extends CustomPainter {
  _QrCodePainter(this.data);

  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final paint = Paint()..color = Colors.black;
    for (final element in Barcode.qrCode().make(
      data,
      width: size.width,
      height: size.height,
    )) {
      if (element is BarcodeBar && element.black) {
        canvas.drawRect(
          Rect.fromLTWH(
            element.left,
            element.top,
            element.width,
            element.height,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrCodePainter oldDelegate) =>
      oldDelegate.data != data;
}
