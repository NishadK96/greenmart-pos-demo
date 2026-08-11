import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../apis/api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/ui.dart';
import '../../backend/presentation/backend_controller.dart';
import '../../store/app_store.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product, this.quick = false});
  final Product? product;
  final bool quick;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _purchase;
  late final TextEditingController _selling;
  late final TextEditingController _minimum;
  final _opening = TextEditingController(text: '0');
  String? _unitId, _categoryId, _taxId, _locationId;
  bool _manageStock = true, _saving = false;
  List<int>? _imageBytes;
  String? _imageName;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _purchase = TextEditingController(
      text: p == null ? '' : (p.purchasePrice / 100).toStringAsFixed(2),
    );
    _selling = TextEditingController(
      text: p == null ? '' : (p.sellingPrice / 100).toStringAsFixed(2),
    );
    _minimum = TextEditingController(text: '${p?.minimumStock ?? 0}');
    _unitId = p?.unitId.isNotEmpty == true ? p!.unitId : null;
    _categoryId = p?.categoryId.isNotEmpty == true ? p!.categoryId : null;
    _taxId = p?.taxId.isNotEmpty == true ? p!.taxId : null;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sku,
      _purchase,
      _selling,
      _minimum,
      _opening,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStoreProvider);
    _unitId ??= state.units.isNotEmpty ? state.units.first.id : null;
    _locationId ??= state.locations.isNotEmpty
        ? state.locations.first.id
        : null;
    final editing = widget.product != null;
    return _Page(
      title: widget.quick
          ? 'Quick add product'
          : editing
          ? 'Edit product'
          : 'Create product',
      subtitle: widget.quick
          ? 'Create a sellable product with optional opening stock.'
          : 'Product details are saved directly to EazyERP.',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _section('Basic information', [
              _field(_name, 'Product name', required: true),
              _field(_sku, 'SKU / barcode'),
              _dropdown(
                'Unit',
                _unitId,
                state.units,
                (v) => setState(() => _unitId = v),
                required: true,
              ),
              _dropdown(
                'Category',
                _categoryId,
                state.categories
                    .map((e) => LookupOption(id: e.id, name: e.name))
                    .toList(),
                (v) => setState(() => _categoryId = v),
              ),
              _dropdown(
                'Tax',
                _taxId,
                state.taxes,
                (v) => setState(() => _taxId = v),
              ),
            ]),
            const SizedBox(height: 16),
            _section('Pricing and inventory', [
              _field(_purchase, 'Purchase price', number: true, required: true),
              _field(_selling, 'Selling price', number: true, required: true),
              _field(_minimum, 'Low-stock alert quantity', number: true),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Manage inventory')),
                value: _manageStock,
                onChanged: (v) => setState(() => _manageStock = v),
              ),
              _dropdown(
                'Business location',
                _locationId,
                state.locations
                    .map((e) => LookupOption(id: e.id, name: e.name))
                    .toList(),
                (v) => setState(() => _locationId = v),
              ),
              if (widget.quick) _field(_opening, 'Opening stock', number: true),
            ]),
            const SizedBox(height: 16),
            _section('Product image', [
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _imageName ??
                      (editing && widget.product!.imageUrl.isNotEmpty
                          ? 'Replace image'
                          : 'Choose image'),
                ),
              ),
              if (_imageName != null)
                Text(
                  _imageName!,
                  style: const TextStyle(color: AppColors.muted),
                ),
            ]),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    context.tr(editing ? 'Save changes' : 'Create product'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: children
              .map((e) => SizedBox(width: 330, child: e))
              .toList(),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool required = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      if (required && (v == null || v.trim().isEmpty))
        return '$label is required';
      if (number && v?.isNotEmpty == true && double.tryParse(v!) == null)
        return 'Enter a valid number';
      return null;
    },
  );

  Widget _dropdown(
    String label,
    String? value,
    List<LookupOption> options,
    ValueChanged<String?> changed, {
    bool required = false,
  }) => DropdownButtonFormField<String>(
    initialValue: options.any((e) => e.id == value) ? value : null,
    decoration: InputDecoration(labelText: label),
    items: options
        .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
        .toList(),
    onChanged: changed,
    validator: required ? (v) => v == null ? '$label is required' : null : null,
  );

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes != null)
      setState(() {
        _imageBytes = file!.bytes;
        _imageName = file.name;
      });
  }

  int _cents(String value) => ((double.tryParse(value) ?? 0) * 100).round();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _unitId == null) return;
    setState(() => _saving = true);
    try {
      final draft = ProductDraft(
        name: _name.text,
        sku: _sku.text,
        unitId: _unitId!,
        categoryId: _categoryId ?? '',
        taxId: _taxId ?? '',
        purchasePrice: _cents(_purchase.text),
        sellingPrice: _cents(_selling.text),
        minimumStock: int.tryParse(_minimum.text) ?? 0,
        manageStock: _manageStock,
        locationIds: _locationId == null ? const [] : [_locationId!],
        openingStock: int.tryParse(_opening.text) ?? 0,
        imageBytes: _imageBytes,
        imageName: _imageName,
      );
      if (widget.product == null) {
        await ref
            .read(backendControllerProvider.notifier)
            .createProduct(draft, quick: widget.quick);
      } else {
        await ref
            .read(backendControllerProvider.notifier)
            .updateProduct(widget.product!, draft);
      }
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class BulkProductUpdateScreen extends ConsumerStatefulWidget {
  const BulkProductUpdateScreen({super.key});
  @override
  ConsumerState<BulkProductUpdateScreen> createState() =>
      _BulkProductUpdateScreenState();
}

class _BulkProductUpdateScreenState
    extends ConsumerState<BulkProductUpdateScreen> {
  final Set<String> selected = {};
  final price = TextEditingController();
  String? categoryId, locationId;
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    return _Page(
      title: 'Bulk update products',
      subtitle:
          'Apply category, location, or selling price to selected products.',
      child: Row(
        children: [
          Expanded(
            child: Surface(
              child: ListView.builder(
                itemCount: s.products.length,
                itemBuilder: (_, i) {
                  final p = s.products[i];
                  return CheckboxListTile(
                    value: selected.contains(p.id),
                    onChanged: (v) => setState(
                      () => v == true
                          ? selected.add(p.id)
                          : selected.remove(p.id),
                    ),
                    title: Text(p.name),
                    subtitle: Text(p.sku),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 360,
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${selected.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(
                      labelText: 'New category',
                    ),
                    items: s.categories
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => categoryId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: locationId,
                    decoration: const InputDecoration(
                      labelText: 'Business location',
                    ),
                    items: s.locations
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => locationId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'New selling price',
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: saving ? null : () => _save(s),
                    child: Text(saving ? 'Updating…' : 'Update selected'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppState s) async {
    final amount = price.text.trim().isEmpty
        ? null
        : ((double.tryParse(price.text) ?? 0) * 100).round();
    if (selected.isEmpty ||
        (categoryId == null && locationId == null && amount == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select products and at least one change.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(backendControllerProvider.notifier)
          .bulkUpdateProducts(
            products: s.products.where((e) => selected.contains(e.id)).toList(),
            categoryId: categoryId,
            locationId: locationId,
            sellingPrice: amount,
          );
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class ProductImportScreen extends ConsumerStatefulWidget {
  const ProductImportScreen({super.key});
  @override
  ConsumerState<ProductImportScreen> createState() =>
      _ProductImportScreenState();
}

class _ProductImportScreenState extends ConsumerState<ProductImportScreen> {
  PlatformFile? file;
  bool importing = false;
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Import products',
    subtitle: 'Upload the EazyERP product spreadsheet template.',
    child: Center(
      child: SizedBox(
        width: 650,
        child: Surface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.upload_file_outlined,
                size: 58,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'XLS, XLSX, CSV or TXT • maximum 100 MB',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              const Text(
                'Required columns: product_name, category, unit, tax, manage_inventory, sku_barcode, sales_price, purchase_price, opening_quantity. Existing SKUs are rejected.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.folder_open),
                label: Text(file?.name ?? 'Choose spreadsheet'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: file == null || importing ? null : _import,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(importing ? 'Importing…' : 'Import products'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xls', 'xlsx', 'csv', 'txt'],
      withData: true,
    );
    if (result != null) setState(() => file = result.files.single);
  }

  Future<void> _import() async {
    if (file?.bytes == null) return;
    setState(() => importing = true);
    try {
      final products = await ref
          .read(backendControllerProvider.notifier)
          .importProducts(file!.bytes!, file!.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${products.length} products imported.')),
        );
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PageTitle(
                context.tr(title),
                subtitle: context.tr(subtitle),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: child),
      ],
    ),
  );
}
