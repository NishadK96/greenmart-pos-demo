import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../apis/api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
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
  bool _saving = false, _existingImageRemoved = false;
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
    for (final controller in [
      _name,
      _sku,
      _purchase,
      _selling,
      _margin,
      _minimum,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
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
    return _buildProductWorkspace(state, editing);
  }

  Widget _buildProductWorkspace(AppState state, bool editing) => Form(
    key: _formKey,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: Column(
        children: [
          _productHeader(editing),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 1080;
                final content = _productFormContent(state);
                final sidebar = _productPreview(state);
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 22 : 14,
                    18,
                    desktop ? 22 : 14,
                    100,
                  ),
                  child: desktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: content),
                            const SizedBox(width: 16),
                            SizedBox(width: 300, child: sidebar),
                          ],
                        )
                      : Column(
                          children: [
                            content,
                            const SizedBox(height: 16),
                            sidebar,
                          ],
                        ),
                );
              },
            ),
          ),
          _productActions(editing),
        ],
      ),
    ),
  );

  Widget _productHeader(bool editing) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    child: Row(
      children: [
        IconButton(
          onPressed: () => context.go('/products'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Products  /  Create product',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              Text(
                editing ? 'Edit product' : 'Create product',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Add product details, pricing, inventory and availability.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: _saving ? null : () => _save(_SaveMode.save),
          child: const Text('Save draft'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _saving ? null : () => _save(_SaveMode.save),
          icon: const Icon(Icons.save_outlined),
          label: Text(editing ? 'Save changes' : 'Save product'),
        ),
      ],
    ),
  );

  Widget _productFormContent(AppState state) => Column(
    children: [
      _productSection(
        1,
        'Product information',
        'Basic information used to identify this product.',
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 500
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _field(_name, 'Product name', required: true),
                ),
                SizedBox(
                  width: width,
                  child: TextFormField(
                    controller: _sku,
                    decoration: InputDecoration(
                      labelText: 'SKU',
                      hintText: 'Leave blank to auto-generate',
                      suffixIcon: _sku.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Check SKU availability',
                              onPressed: _checkSkuAvailability,
                              icon: const Icon(Icons.fact_check_outlined),
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _choice(
                    'Barcode type',
                    _barcodeType,
                    const [
                      LookupOption(id: 'C128', name: 'Code 128 (C128)'),
                      LookupOption(id: 'C39', name: 'Code 39 (C39)'),
                      LookupOption(id: 'EAN13', name: 'EAN-13'),
                    ],
                    (v) => setState(() => _barcodeType = v!),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _dropdown(
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
                ),
                SizedBox(
                  width: width,
                  child: _dropdown(
                    'Subcategory',
                    _subCategoryId,
                    _subCategories(state),
                    (v) => setState(() => _subCategoryId = v),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _dropdown(
                    'Brand',
                    _brandId,
                    state.brands,
                    (v) => setState(() => _brandId = v),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _dropdown(
                          'Unit',
                          _unitId,
                          state.units,
                          (v) => setState(() => _unitId = v),
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: SizedBox.square(
                          dimension: 38,
                          child: IconButton.outlined(
                            tooltip: 'Create unit of measure',
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: Color(0xFFD5DEDB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _showCreateUnitDialog,
                            icon: const Icon(Icons.add_rounded, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: width, child: _field(_weight, 'Weight')),
                SizedBox(
                  width: width,
                  child: _field(
                    _preparation,
                    'Preparation time (minutes)',
                    number: true,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      _productSection(
        2,
        'Product media',
        'Add an image and supporting product documents.',
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _uploadPanel(
                    Icons.image_outlined,
                    'Product image',
                    _imageName ?? 'Upload product image',
                    'PNG, JPG or WEBP • Max 5 MB • 1:1 recommended',
                    _pickImage,
                    image: true,
                  ),
                  if (widget.product?.imageUrl.isNotEmpty == true &&
                      !_existingImageRemoved) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: _saving ? null : _removeExistingImage,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove existing image'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _uploadPanel(
                Icons.description_outlined,
                'Product brochure (optional)',
                _brochureName ?? 'Upload brochure',
                'PDF, document, spreadsheet, ZIP or image',
                _pickBrochure,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _productSection(
        3,
        'Inventory',
        'Configure stock tracking and inventory behaviour.',
        Column(
          children: [
            _settingRow(
              Icons.inventory_2_outlined,
              'Track inventory',
              'Track stock quantities and receive low-stock alerts.',
              _manageStock,
              (v) => setState(() => _manageStock = v),
              trailing: SizedBox(
                width: 210,
                child: _field(
                  _minimum,
                  'Low-stock alert quantity',
                  number: true,
                ),
              ),
            ),
            _settingRow(
              Icons.sell_outlined,
              'Not for selling',
              'Keep this item in inventory but prevent it from being sold through POS.',
              _notForSelling,
              (v) => setState(() => _notForSelling = v),
            ),
            _settingRow(
              Icons.qr_code_2_rounded,
              'Track serial / IMEI numbers',
              'Record a unique serial or IMEI number for each item.',
              _serialNumber,
              (v) => setState(() => _serialNumber = v),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _productSection(
        4,
        'Product description',
        'Add product details, specifications or internal notes.',
        TextFormField(
          controller: _description,
          minLines: 4,
          maxLines: 7,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText:
                'Add product details, specifications or internal notes...',
          ),
        ),
      ),
      const SizedBox(height: 14),
      _productSection(
        5,
        'Business locations',
        'Choose where this product will be available for sale.',
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: state.locations
              .map(
                (location) => _locationCard(
                  LookupOption(id: location.id, name: location.name),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 14),
      _productSection(
        6,
        'Tax & product type',
        'Configure how this product will be taxed and sold.',
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: _dropdown('Applicable tax', _taxId, state.taxes, (v) {
                setState(() => _taxId = v);
                _recalculatePrices(state);
              }),
            ),
            SizedBox(
              width: 260,
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
              width: 260,
              child: _choice('Product type', 'single', const [
                LookupOption(id: 'single', name: 'Single product'),
              ], (_) {}),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _productSection(
        7,
        'Pricing',
        'Configure purchase cost, margin and selling price.',
        Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Purchase cost'),
                SizedBox(width: 22),
                Icon(Icons.arrow_forward, color: AppColors.primary),
                SizedBox(width: 22),
                Text('Margin'),
                SizedBox(width: 22),
                Icon(Icons.arrow_forward, color: AppColors.primary),
                SizedBox(width: 22),
                Text('Selling price'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _priceField(
                        _purchase,
                        'Purchase cost excluding tax',
                        () => _recalculatePrices(state),
                        required: false,
                      ),
                      const SizedBox(height: 10),
                      _priceField(
                        _purchaseInc,
                        'Purchase cost including tax',
                        null,
                        required: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _margin,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Margin (%)',
                      suffixText: '%',
                    ),
                    onChanged: (_) => _recalculatePrices(state),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _priceField(
                        _selling,
                        'Selling price excluding tax',
                        () => _recalculateSellingInc(state),
                        required: false,
                      ),
                      const SizedBox(height: 10),
                      _priceField(
                        _sellingInc,
                        'Selling price including tax',
                        null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ⓘ  Estimated profit per unit: ',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  RiyalAmount(
                    toPaise(
                      (double.tryParse(_selling.text) ?? 0) -
                          (double.tryParse(_purchase.text) ?? 0),
                    ),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _productSection(
    int number,
    String title,
    String subtitle,
    Widget child,
  ) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primary,
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _uploadPanel(
    IconData icon,
    String title,
    String label,
    String help,
    VoidCallback action, {
    bool image = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 190,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFBFD7CF),
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFFFBFDFC),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (image && _imageBytes != null)
                Image.memory(
                  Uint8List.fromList(_imageBytes!),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                )
              else
                Icon(icon, size: 34, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                help,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _settingRow(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> changed, {
    Widget? trailing,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE5EAE8))),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFEAF4F1),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[trailing, const SizedBox(width: 12)],
        Switch.adaptive(value: value, onChanged: changed),
      ],
    ),
  );

  Widget _locationCard(LookupOption location) {
    final selected = _locationIds.contains(location.id);
    return InkWell(
      onTap: () => setState(
        () => selected
            ? _locationIds.remove(location.id)
            : _locationIds.add(location.id),
      ),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF2FAF7) : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFDDE5E2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            const CircleAvatar(child: Icon(Icons.storefront_outlined)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                location.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productPreview(AppState state) => Column(
    children: [
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product preview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _imageBytes == null
                  ? const Icon(
                      Icons.storefront_outlined,
                      size: 46,
                      color: Color(0xFFB8BFBC),
                    )
                  : Image.memory(
                      Uint8List.fromList(_imageBytes!),
                      fit: BoxFit.contain,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              _name.text.trim().isEmpty ? 'Untitled product' : _name.text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            Text(
              _sku.text.trim().isEmpty ? 'SKU will be generated' : _sku.text,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const Text(
              'Pricing',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _previewAmountLine('Purchase cost', _purchase.text),
            _previewAmountLine('Selling price', _selling.text),
            _previewLine('Margin', '${_margin.text}%'),
            const SizedBox(height: 14),
            const Divider(),
            const Text(
              'Inventory',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _previewLine('Tracking', _manageStock ? 'Enabled' : 'Disabled'),
            _previewLine('Low-stock alert', _minimum.text),
            _previewLine('Locations', '${_locationIds.length}'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product setup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _progressItem(
              'Basic information',
              _name.text.trim().isNotEmpty && _unitId != null,
            ),
            _progressItem(
              'Media',
              _imageBytes != null ||
                  (widget.product?.imageUrl.isNotEmpty ?? false),
            ),
            _progressItem('Inventory', true),
            _progressItem('Location', _locationIds.isNotEmpty),
            _progressItem('Pricing', double.tryParse(_selling.text) != null),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _completion / 5),
          ],
        ),
      ),
    ],
  );

  int get _completion => [
    _name.text.trim().isNotEmpty && _unitId != null,
    _imageBytes != null || (widget.product?.imageUrl.isNotEmpty ?? false),
    true,
    _locationIds.isNotEmpty,
    double.tryParse(_selling.text) != null,
  ].where((e) => e).length;
  Widget _progressItem(String label, bool done) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.circle_outlined,
          size: 18,
          color: done ? AppColors.primary : AppColors.muted,
        ),
        const SizedBox(width: 9),
        Text(label),
      ],
    ),
  );
  Widget _previewLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ],
    ),
  );
  Widget _previewAmountLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        RiyalAmount(
          toPaise(double.tryParse(value) ?? 0),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _productActions(bool editing) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: _saving ? null : () => context.go('/products'),
          child: const Text('Cancel'),
        ),
        if (!editing && !widget.quick)
          FilledButton.tonalIcon(
            onPressed: _saving ? null : () => _save(_SaveMode.addAnother),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Save & add another'),
          ),
        if (!editing && !widget.quick)
          FilledButton.tonalIcon(
            onPressed: _saving ? null : () => _save(_SaveMode.openingStock),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Save & add opening stock'),
          ),
        FilledButton.icon(
          onPressed: _saving ? null : () => _save(_SaveMode.save),
          icon: const Icon(Icons.save_outlined),
          label: Text(editing ? 'Save changes' : 'Save product'),
        ),
      ],
    ),
  );

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
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
                  onPressed: _saving ? null : () => context.go('/products'),
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
    VoidCallback? changed, {
    bool required = true,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: context.tr(label),
      prefixIcon: const Padding(
        padding: EdgeInsets.all(14),
        child: RiyalSymbol(size: 16),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    ),
    onChanged: changed == null ? null : (_) => changed(),
    validator: (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return required ? context.tr('Required') : null;
      return double.tryParse(text) == null
          ? context.tr('Enter a valid number')
          : null;
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
    decoration: InputDecoration(labelText: context.tr(label)),
    items: options
        .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
        .toList(),
    onChanged: changed,
    validator: required ? (v) => v == null ? '$label is required' : null : null,
  );

  Future<void> _showCreateUnitDialog() async {
    final created = await showDialog<LookupOption>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateUnitDialog(),
    );
    if (created != null && mounted) {
      setState(() => _unitId = created.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${created.name} was added and selected.')),
      );
    }
  }

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

  Future<void> _checkSkuAvailability() async {
    final sku = _sku.text.trim();
    if (sku.isEmpty) return;
    try {
      final available = await ref
          .read(backendControllerProvider.notifier)
          .checkSku(sku, excludeProductId: widget.product?.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            available ? 'SKU is available.' : 'SKU is already in use.',
          ),
          backgroundColor: available ? AppColors.primary : AppColors.danger,
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _removeExistingImage() async {
    final product = widget.product;
    if (product == null) return;
    try {
      await ref
          .read(backendControllerProvider.notifier)
          .removeProductImage(product);
      if (!mounted) return;
      setState(() => _existingImageRemoved = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product image removed.')));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  double _taxPercent(AppState state) {
    return state.taxes.where((e) => e.id == _taxId).firstOrNull?.value ?? 0;
  }

  void _recalculatePrices(AppState state) {
    final purchase = double.tryParse(_purchase.text);
    if (purchase == null) return;
    final margin = double.tryParse(_margin.text) ?? 0;
    final tax = _taxPercent(state) / 100;
    _purchaseInc.text = (purchase * (1 + tax)).toStringAsFixed(2);
    final selling = purchase * (1 + margin / 100);
    _selling.text = selling.toStringAsFixed(2);
    _sellingInc.text = (selling * (1 + tax)).toStringAsFixed(2);
  }

  void _recalculateSellingInc(AppState state) {
    final selling = double.tryParse(_selling.text);
    if (selling == null) return;
    _sellingInc.text = (selling * (1 + _taxPercent(state) / 100))
        .toStringAsFixed(2);
  }

  int _cents(String value) => ((double.tryParse(value) ?? 0) * 100).round();

  int? _optionalCents(String value) {
    final amount = double.tryParse(value.trim());
    return amount == null ? null : (amount * 100).round();
  }

  Future<void> _save(_SaveMode mode) async {
    if (!_formKey.currentState!.validate() || _unitId == null) return;
    final sku = _sku.text.trim();
    if (sku.isNotEmpty) {
      try {
        final available = await ref
            .read(backendControllerProvider.notifier)
            .checkSku(sku, excludeProductId: widget.product?.id);
        if (!available) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This SKU is already in use.'),
                backgroundColor: AppColors.danger,
              ),
            );
          }
          return;
        }
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
        return;
      }
    }
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
        purchasePrice: _optionalCents(_purchase.text),
        purchasePriceIncTax: _optionalCents(_purchaseInc.text),
        sellingPrice: _optionalCents(_selling.text),
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
        context.go('/products');
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

class _CreateUnitDialog extends ConsumerStatefulWidget {
  const _CreateUnitDialog();

  @override
  ConsumerState<_CreateUnitDialog> createState() => _CreateUnitDialogState();
}

class _CreateUnitDialogState extends ConsumerState<_CreateUnitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  bool _allowDecimal = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _shortName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.straighten_rounded,
                        color: AppColors.primary,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create unit of measure',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add a reusable UOM for products and inventory.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Unit name *',
                    hintText: 'e.g. Kilogram, Box, Litre',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a unit name'
                      : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _shortName,
                  decoration: const InputDecoration(
                    labelText: 'Symbol / short name *',
                    hintText: 'e.g. kg, box, L',
                    prefixIcon: Icon(Icons.short_text_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a short name'
                      : null,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8E6)),
                  ),
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _allowDecimal,
                    onChanged: (value) => setState(() => _allowDecimal = value),
                    title: const Text(
                      'Allow decimal quantities',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _allowDecimal
                          ? 'Supports quantities such as 0.5 kg or 1.25 L.'
                          : 'Use whole quantities only, such as 1 box or 2 pieces.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The new UOM will be available across product creation, purchasing and inventory.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving…' : 'Create UOM'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final unit = await ref
          .read(backendControllerProvider.notifier)
          .createUnit(
            name: _name.text.trim(),
            shortName: _shortName.text.trim(),
            allowDecimal: _allowDecimal,
          );
      if (mounted) Navigator.pop(context, unit);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create the unit. Try again.')),
      );
    }
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
      if (mounted) context.go('/products');
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
        context.go('/products');
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
              onPressed: () => context.go('/products'),
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
