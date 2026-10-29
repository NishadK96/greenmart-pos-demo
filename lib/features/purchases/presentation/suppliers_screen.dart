import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:eazy_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/auth_controller.dart';
import '../domain/purchase_entities.dart';
import 'purchase_controller.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String search = '';
  String? selectedId;
  Future<List<Map<String, dynamic>>>? transactions;

  Future<String> _token() async {
    final token = await ref.read(authControllerProvider.future);
    if (token == null || token.isEmpty) {
      throw const ApiException('Your session has expired. Please sign in.');
    }
    return token;
  }

  void _select(Supplier supplier) {
    setState(() {
      selectedId = supplier.id;
      transactions = _loadTransactions(supplier.id);
    });
  }

  Future<List<Map<String, dynamic>>> _loadTransactions(String id) async {
    final token = await _token();
    try {
      return await ref.read(apiProvider).supplierTransactions(token, id);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      final rows = await ref.read(apiProvider).supplierPayments(token, id);
      return rows.map((row) => {...row, 'kind': 'payment'}).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(purchaseControllerProvider);
    final supplierDirectory = ref.watch(supplierDirectoryProvider);
    final narrow = MediaQuery.sizeOf(context).width < 800;
    return Padding(
      padding: EdgeInsets.all(narrow ? 12 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(
            'Suppliers',
            subtitle: 'Profiles, purchase history and payments.',
            action: FilledButton.icon(
              onPressed: supplierDirectory.hasValue ? () => _edit(null) : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add supplier'),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: supplierDirectory.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load suppliers.'),
                    const SizedBox(height: 4),
                    Text(
                      error is ApiException ? error.message : '$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(supplierDirectoryProvider);
                        ref.invalidate(purchaseControllerProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (suppliers) {
                final data =
                    workspace.asData?.value ??
                    PurchaseWorkspaceState(suppliers: suppliers);
                final query = search.trim().toLowerCase();
                final filtered = suppliers.where((supplier) {
                  return query.isEmpty ||
                      supplier.name.toLowerCase().contains(query) ||
                      supplier.nameAr.contains(search.trim()) ||
                      supplier.contactName.toLowerCase().contains(query) ||
                      supplier.mobile.contains(query);
                }).toList();
                final selected = suppliers
                    .where((item) => item.id == selectedId)
                    .firstOrNull;
                final list = _supplierList(filtered);
                if (narrow) {
                  return selected == null
                      ? list
                      : _supplierDetail(data, selected, showBack: true);
                }
                return Row(
                  children: [
                    SizedBox(width: 340, child: list),
                    const SizedBox(width: 14),
                    Expanded(
                      child: selected == null
                          ? const Surface(
                              child: Center(
                                child: Text(
                                  'Select a supplier to view details.',
                                ),
                              ),
                            )
                          : _supplierDetail(data, selected),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierList(List<Supplier> suppliers) => Surface(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search supplier, contact or phone',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (value) => setState(() => search = value),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: suppliers.isEmpty
              ? const Center(child: Text('No suppliers found.'))
              : ListView.separated(
                  itemCount: suppliers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index];
                    return ListTile(
                      selected: supplier.id == selectedId,
                      leading: const CircleAvatar(
                        child: Icon(Icons.local_shipping_outlined),
                      ),
                      title: Text(
                        supplier.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          supplier.contactName,
                          supplier.mobile,
                        ].where((value) => value.isNotEmpty).join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _select(supplier),
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Widget _supplierDetail(
    PurchaseWorkspaceState data,
    Supplier supplier, {
    bool showBack = false,
  }) {
    final orders =
        data.orders.where((item) => item.supplierId == supplier.id).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final transactions = [
      ...data.invoices.where((item) => item.supplierId == supplier.id),
      ...data.returns.where((item) => item.supplierId == supplier.id),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return DefaultTabController(
      length: 3,
      child: Surface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: () => setState(() => selectedId = null),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: Text(
                      supplier.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit supplier',
                    onPressed: () => _edit(supplier),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Details'),
                Tab(text: 'Transactions'),
                Tab(text: 'All orders'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _details(supplier),
                  _transactions(transactions),
                  _orders(orders),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(Supplier supplier) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      _fact('Supplier name', supplier.name),
      _fact('Supplier name (Arabic)', supplier.nameAr),
      _fact('Contact person', supplier.contactName),
      _fact('Contact person (Arabic)', supplier.contactNameAr),
      _fact('Mobile', supplier.mobile),
      _fact('Email', supplier.email),
      _fact('VAT number', supplier.taxNumber),
      _fact(
        'Address',
        [
          supplier.addressLine1,
          supplier.addressLine2,
          supplier.city,
          supplier.state,
          supplier.country,
          supplier.zipCode,
        ].where((value) => value.isNotEmpty).join(', '),
      ),
    ],
  );

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 3),
        Text(value.isEmpty ? '—' : value),
      ],
    ),
  );

  Widget _transactions(
    List<PurchaseDocument> documents,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: transactions,
    builder: (context, snapshot) {
      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
      final localDocuments = rows.any((row) => row['kind'] == 'document')
          ? const <PurchaseDocument>[]
          : documents;
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (localDocuments.isEmpty &&
              rows.isEmpty &&
              !snapshot.hasError &&
              snapshot.connectionState != ConnectionState.waiting)
            const ListTile(title: Text('No transactions found.')),
          for (final doc in localDocuments)
            ListTile(
              leading: Icon(
                doc.type == PurchaseDocumentType.purchaseReturn
                    ? Icons.keyboard_return_rounded
                    : Icons.receipt_long_outlined,
              ),
              title: Text(doc.reference),
              subtitle: Text(
                '${DateFormat.yMMMd().format(doc.date)} • ${doc.status}',
              ),
              trailing: Text(money(doc.total)),
            ),
          for (final row in rows)
            ListTile(
              leading: Icon(
                row['kind'] == 'payment'
                    ? Icons.payments_outlined
                    : Icons.receipt_long_outlined,
              ),
              title: Text(
                '${row['kind'] == 'payment' ? 'Payment' : row['type'] ?? 'Transaction'} • ${row['reference'] ?? '—'}',
              ),
              subtitle: Text(
                '${row['date'] ?? row['paid_on'] ?? ''} • ${row['method'] ?? row['payment_method_label'] ?? row['status'] ?? ''}',
              ),
              trailing: Text(
                money(
                  ((num.tryParse('${row['amount'] ?? 0}') ?? 0) * 100).round(),
                ),
              ),
            ),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(),
              ),
            ),
          if (snapshot.hasError)
            ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Transaction history could not be loaded.'),
              trailing: TextButton(
                onPressed: () => setState(
                  () => transactions = _loadTransactions(selectedId!),
                ),
                child: const Text('Retry'),
              ),
            ),
        ],
      );
    },
  );

  Widget _orders(List<PurchaseDocument> orders) => orders.isEmpty
      ? const Center(child: Text('No purchase orders for this supplier.'))
      : ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final order = orders[index];
            return ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: Text(order.reference),
              subtitle: Text(
                '${DateFormat.yMMMd().format(order.date)} • ${order.status}',
              ),
              trailing: Text(money(order.total)),
              onTap: () => context.go('/purchases'),
            );
          },
        );

  Future<void> _edit(Supplier? existing) async {
    final result = await showDialog<Supplier>(
      context: context,
      builder: (dialogContext) => _SupplierForm(existing: existing),
    );
    if (result == null || !mounted) return;
    ref.invalidate(supplierDirectoryProvider);
    ref.invalidate(purchaseControllerProvider);
    _select(result);
  }
}

class _SupplierForm extends ConsumerStatefulWidget {
  const _SupplierForm({this.existing});
  final Supplier? existing;

  @override
  ConsumerState<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends ConsumerState<_SupplierForm> {
  final formKey = GlobalKey<FormState>();
  late final fields = <String, TextEditingController>{
    'name': TextEditingController(text: widget.existing?.name),
    'nameAr': TextEditingController(text: widget.existing?.nameAr),
    'contact': TextEditingController(text: widget.existing?.contactName),
    'contactAr': TextEditingController(text: widget.existing?.contactNameAr),
    'mobile': TextEditingController(text: widget.existing?.mobile),
    'email': TextEditingController(text: widget.existing?.email),
    'tax': TextEditingController(text: widget.existing?.taxNumber),
    'address1': TextEditingController(text: widget.existing?.addressLine1),
    'address2': TextEditingController(text: widget.existing?.addressLine2),
    'city': TextEditingController(text: widget.existing?.city),
    'state': TextEditingController(text: widget.existing?.state),
    'country': TextEditingController(text: widget.existing?.country),
    'zip': TextEditingController(text: widget.existing?.zipCode),
  };
  bool busy = false;
  String? error;

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String value(String key) => fields[key]!.text.trim();

  Widget input(String key, String label, {bool required = false}) =>
      TextFormField(
        controller: fields[key],
        decoration: InputDecoration(labelText: label),
        textDirection: key.endsWith('Ar') ? ui.TextDirection.rtl : null,
        keyboardType: key == 'email'
            ? TextInputType.emailAddress
            : key == 'mobile'
            ? TextInputType.phone
            : null,
        validator: required
            ? (text) => (text ?? '').trim().isEmpty ? 'Required' : null
            : null,
      );

  Future<void> save() async {
    if (!formKey.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final Supplier result;
      if (widget.existing == null) {
        result = await ref
            .read(purchaseControllerProvider.notifier)
            .createSupplier(
              businessName: value('name'),
              businessNameAr: value('nameAr'),
              contactName: value('contact'),
              contactNameAr: value('contactAr'),
              mobile: value('mobile'),
              email: value('email'),
              taxNumber: value('tax'),
              addressLine1: value('address1'),
              addressLine2: value('address2'),
              city: value('city'),
              state: value('state'),
              country: value('country'),
              zipCode: value('zip'),
            );
      } else {
        final token = await ref.read(authControllerProvider.future);
        if (token == null)
          throw const ApiException('Your session has expired.');
        result = await ref
            .read(apiProvider)
            .updateSupplier(
              accessToken: token,
              supplier: Supplier(
                id: widget.existing!.id,
                name: value('name'),
                nameAr: value('nameAr'),
                contactName: value('contact'),
                contactNameAr: value('contactAr'),
                mobile: value('mobile'),
                email: value('email'),
                taxNumber: value('tax'),
                addressLine1: value('address1'),
                addressLine2: value('address2'),
                city: value('city'),
                state: value('state'),
                country: value('country'),
                zipCode: value('zip'),
              ),
            );
      }
      if (mounted) Navigator.of(context).pop(result);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 740),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Add supplier' : 'Edit supplier',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Form(
                key: formKey,
                child: ListView(
                  children: [
                    input('name', 'Supplier / business name *', required: true),
                    input('nameAr', 'Supplier / business name (Arabic)'),
                    input('contact', 'Contact person *', required: true),
                    input('contactAr', 'Contact person (Arabic)'),
                    input('mobile', 'Mobile *', required: true),
                    input('email', 'Email'),
                    input('tax', 'VAT number'),
                    input('address1', 'Address line 1'),
                    input('address2', 'Address line 2'),
                    input('city', 'City'),
                    input('state', 'State'),
                    input('country', 'Country'),
                    input('zip', 'Postal code'),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Saving…' : 'Save supplier'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
