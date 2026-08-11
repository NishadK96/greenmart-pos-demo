import 'package:file_picker/file_picker.dart';
import 'package:collection/collection.dart';
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
  late final TextEditingController _name, _sku, _purchase, _purchaseInc;
  late final TextEditingController _selling, _sellingInc, _margin, _minimum;
  final _description = TextEditingController();
  final _weight = TextEditingController();
  final _preparation = TextEditingController();
  final _opening = TextEditingController(text: '0');
  String? _unitId, _categoryId, _subCategoryId, _brandId, _taxId;
  String _barcodeType = 'C128', _taxType = 'exclusive';
  final Set<String> _locationIds = {};
  bool _manageStock = true, _serialNumber = false, _notForSelling = false;
  bool _saving = false;
  List<int>? _imageBytes, _brochureBytes;
  String? _imageName, _brochureName;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _purchase = TextEditingController(
      text: p == null ? '' : (p.purchasePrice / 100).toStringAsFixed(2),
    );
    _purchaseInc = TextEditingController(
      text: p == null ? '' : (p.purchasePrice / 100).toStringAsFixed(2),
    );
    _selling = TextEditingController(
      text: p == null ? '' : (p.sellingPrice / 100).toStringAsFixed(2),
    );
    _sellingInc = TextEditingController(
      text: p == null ? '' : (p.sellingPrice / 100).toStringAsFixed(2),
    );
    _margin = TextEditingController(text: '25.00');
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
      _purchaseInc,
      _selling,
      _sellingInc,
      _margin,
      _minimum,
      _opening,
      _description,
      _weight,
      _preparation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStoreProvider);
    _unitId ??= state.units.isNotEmpty ? state.units.first.id : null;
    if (_locationIds.isEmpty && state.locations.length == 1) {
      _locationIds.add(state.locations.first.id);
    }
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
            _section('Product identity', [
              _field(_name, 'Product name', required: true),
              _field(_sku, 'SKU (leave blank to auto-generate)'),
              _choice('Barcode type', _barcodeType, const [
                LookupOption(id: 'C128', name: 'Code 128 (C128)'),
                LookupOption(id: 'C39', name: 'Code 39 (C39)'),
                LookupOption(id: 'EAN13', name: 'EAN-13'),
                LookupOption(id: 'EAN8', name: 'EAN-8'),
                LookupOption(id: 'UPCA', name: 'UPC-A'),
                LookupOption(id: 'UPCE', name: 'UPC-E'),
              ], (v) => setState(() => _barcodeType = v!)),
              _dropdown(
                'Unit',
                _unitId,
                state.units,
                (v) => setState(() => _unitId = v),
                required: true,
              ),
              _dropdown(
                'Brand',
                _brandId,
                state.brands,
                (v) => setState(() => _brandId = v),
              ),
              _dropdown(
                'Category',
                _categoryId,
                state.categories
                    .map((e) => LookupOption(id: e.id, name: e.name))
                    .toList(),
                (v) => setState(() {
                  _categoryId = v;
                  _subCategoryId = null;
                }),
              ),
              _dropdown(
                'Sub category',
                _subCategoryId,
                _subCategories(state),
                (v) => setState(() => _subCategoryId = v),
              ),
            ]),
            const SizedBox(height: 16),
            _section('Inventory and description', [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Manage inventory')),
                value: _manageStock,
                onChanged: (v) => setState(() => _manageStock = v),
              ),
              if (_manageStock)
                _field(_minimum, 'Alert quantity', number: true),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Enable IMEI or serial number')),
                value: _serialNumber,
                onChanged: (v) => setState(() => _serialNumber = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Not for selling')),
                value: _notForSelling,
                onChanged: (v) => setState(() => _notForSelling = v),
              ),
              _field(_weight, 'Weight'),
              _field(_preparation, 'Preparation time (minutes)', number: true),
              SizedBox(
                width: 674,
                child: TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Product description',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Business locations'),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'Select every location where this product can be sold.',
                    ),
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final location in state.locations)
                        FilterChip(
                          selected: _locationIds.contains(location.id),
                          label: Text(location.name),
                          avatar: const Icon(Icons.store_outlined, size: 18),
                          onSelected: (selected) => setState(
                            () => selected
                                ? _locationIds.add(location.id)
                                : _locationIds.remove(location.id),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section('Media', [
              _fileButton(
                icon: Icons.add_photo_alternate_outlined,
                label:
                    _imageName ??
                    (editing && widget.product!.imageUrl.isNotEmpty
                        ? 'Replace product image'
                        : 'Choose product image'),
                help: 'Maximum 5 MB • square 1:1 image recommended',
                onPressed: _pickImage,
              ),
              _fileButton(
                icon: Icons.description_outlined,
                label: _brochureName ?? 'Choose product brochure',
                help: 'PDF, document, spreadsheet, ZIP or image',
                onPressed: _pickBrochure,
              ),
            ]),
            const SizedBox(height: 16),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Tax and product type'),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: 330,
                        child: _dropdown(
                          'Applicable tax',
                          _taxId,
                          state.taxes,
                          (v) {
                            setState(() => _taxId = v);
                            _recalculatePrices(state);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 330,
                        child: _choice(
                          'Selling price tax type',
                          _taxType,
                          const [
                            LookupOption(id: 'exclusive', name: 'Exclusive'),
                            LookupOption(id: 'inclusive', name: 'Inclusive'),
                          ],
                          (v) => setState(() => _taxType = v!),
                        ),
                      ),
                      SizedBox(
                        width: 330,
                        child: _choice('Product type', 'single', const [
                          LookupOption(id: 'single', name: 'Single product'),
                        ], (_) {}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4FAF7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD8EAE2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                context.tr('Default purchase price'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                context.tr('Margin (%)'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                context.tr('Default selling price'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _priceField(
                                      _purchase,
                                      'Excluding tax',
                                      () => _recalculatePrices(state),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _priceField(
                                      _purchaseInc,
                                      'Including tax',
                                      null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _priceField(
                                _margin,
                                'Margin',
                                () => _recalculatePrices(state),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _priceField(
                                      _selling,
                                      'Excluding tax',
                                      () => _recalculateSellingInc(state),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _priceField(
                                      _sellingInc,
                                      'Including tax',
                                      null,
                                    ),
                                  ),
                                ],
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
            if (widget.quick) ...[
              const SizedBox(height: 16),
              _section('Opening stock', [
                _field(_opening, 'Opening quantity', number: true),
              ]),
            ],
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
                if (!editing && !widget.quick)
                  FilledButton.tonalIcon(
                    onPressed: _saving
                        ? null
                        : () => _save(_SaveMode.openingStock),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(context.tr('Save & add opening stock')),
                  ),
                if (!editing && !widget.quick)
                  FilledButton.tonalIcon(
                    onPressed: _saving
                        ? null
                        : () => _save(_SaveMode.addAnother),
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(context.tr('Save and add another')),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(_SaveMode.save),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(context.tr(editing ? 'Save changes' : 'Save')),
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
          context.tr(title),
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
    decoration: InputDecoration(labelText: context.tr(label)),
    validator: (v) {
      if (required && (v == null || v.trim().isEmpty))
        return '$label is required';
      if (number && v?.isNotEmpty == true && double.tryParse(v!) == null)
        return 'Enter a valid number';
      return null;
    },
  );

  Widget _priceField(
    TextEditingController controller,
    String label,
    VoidCallback? changed,
  ) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: context.tr(label),
      prefixText:
          '${ref.read(appStoreProvider).business?.currencySymbol ?? ''} ',
    ),
    onChanged: changed == null ? null : (_) => changed(),
    validator: (v) => double.tryParse(v ?? '') == null ? 'Required' : null,
  );

  Widget _dropdown(
    String label,
    String? value,
    List<LookupOption> options,
    ValueChanged<String?> changed, {
    bool required = false,
  }) => DropdownButtonFormField<String>(
    initialValue: options.any((e) => e.id == value) ? value : null,
    decoration: InputDecoration(labelText: context.tr(label)),
    items: options
        .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
        .toList(),
    onChanged: changed,
    validator: required ? (v) => v == null ? '$label is required' : null : null,
  );

  Widget _choice(
    String label,
    String value,
    List<LookupOption> options,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: context.tr(label)),
    items: options
        .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
        .toList(),
    onChanged: changed,
  );

  List<LookupOption> _subCategories(AppState state) {
    final category = state.categories
        .where((e) => e.id == _categoryId)
        .firstOrNull;
    return category?.subCategories
            .map((e) => LookupOption(id: e.id, name: e.name))
            .toList() ??
        const [];
  }

  Widget _fileButton({
    required IconData icon,
    required String label,
    required String help,
    required VoidCallback onPressed,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
      const SizedBox(height: 5),
      Text(help, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    ],
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

  Future<void> _pickBrochure() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file?.bytes != null)
      setState(() {
        _brochureBytes = file!.bytes;
        _brochureName = file.name;
      });
  }

  double _taxPercent(AppState state) {
    return state.taxes.where((e) => e.id == _taxId).firstOrNull?.value ?? 0;
  }

  void _recalculatePrices(AppState state) {
    final purchase = double.tryParse(_purchase.text) ?? 0;
    final margin = double.tryParse(_margin.text) ?? 0;
    final tax = _taxPercent(state) / 100;
    _purchaseInc.text = (purchase * (1 + tax)).toStringAsFixed(2);
    final selling = purchase * (1 + margin / 100);
    _selling.text = selling.toStringAsFixed(2);
    _sellingInc.text = (selling * (1 + tax)).toStringAsFixed(2);
  }

  void _recalculateSellingInc(AppState state) {
    final selling = double.tryParse(_selling.text) ?? 0;
    _sellingInc.text = (selling * (1 + _taxPercent(state) / 100))
        .toStringAsFixed(2);
  }

  int _cents(String value) => ((double.tryParse(value) ?? 0) * 100).round();

  Future<void> _save(_SaveMode mode) async {
    if (!_formKey.currentState!.validate() || _unitId == null) return;
    if (mode == _SaveMode.openingStock) {
      final proceed = await _requestOpeningStock();
      if (!proceed) return;
    }
    setState(() => _saving = true);
    try {
      final draft = ProductDraft(
        name: _name.text,
        sku: _sku.text,
        unitId: _unitId!,
        categoryId: _categoryId ?? '',
        subCategoryId: _subCategoryId ?? '',
        brandId: _brandId ?? '',
        taxId: _taxId ?? '',
        barcodeType: _barcodeType,
        taxType: _taxType,
        purchasePrice: _cents(_purchase.text),
        purchasePriceIncTax: _cents(_purchaseInc.text),
        sellingPrice: _cents(_selling.text),
        sellingPriceIncTax: _cents(_sellingInc.text),
        profitPercent: double.tryParse(_margin.text) ?? 0,
        minimumStock: int.tryParse(_minimum.text) ?? 0,
        manageStock: _manageStock,
        locationIds: _locationIds.toList(),
        openingStock: int.tryParse(_opening.text) ?? 0,
        description: _description.text,
        weight: _weight.text,
        preparationMinutes: int.tryParse(_preparation.text),
        enableSerialNumber: _serialNumber,
        notForSelling: _notForSelling,
        imageBytes: _imageBytes,
        imageName: _imageName,
        brochureBytes: _brochureBytes,
        brochureName: _brochureName,
      );
      if (widget.product == null) {
        await ref
            .read(backendControllerProvider.notifier)
            .createProduct(
              draft,
              quick: widget.quick || mode == _SaveMode.openingStock,
            );
      } else {
        await ref
            .read(backendControllerProvider.notifier)
            .updateProduct(widget.product!, draft);
      }
      if (!mounted) return;
      if (mode == _SaveMode.addAnother) {
        _resetForAnother();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product saved. Add the next product.')),
        );
      } else {
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _requestOpeningStock() async {
    if (_locationIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a business location first.')),
      );
      return false;
    }
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Add opening stock'),
            content: TextField(
              controller: _opening,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Opening quantity'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _resetForAnother() {
    for (final controller in [
      _name,
      _sku,
      _purchase,
      _purchaseInc,
      _selling,
      _sellingInc,
      _description,
      _weight,
      _preparation,
    ]) {
      controller.clear();
    }
    _margin.text = '25.00';
    _minimum.text = '0';
    _opening.text = '0';
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _brochureBytes = null;
      _brochureName = null;
    });
  }
}

enum _SaveMode { save, openingStock, addAnother }

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
