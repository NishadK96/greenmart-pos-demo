import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/entities.dart';
import '../domain/offline_pos_entities.dart';

class OfflinePosStorage {
  static const _contextKey = 'offline_pos_context_v1';
  static const _queueKey = 'offline_pos_queue_v1';
  static const _catalogKey = 'offline_pos_catalog_v1';
  static const _resumeAllowedKey = 'offline_pos_resume_allowed_v1';

  Future<OfflinePosState> load() async {
    final preferences = await SharedPreferences.getInstance();
    final contextText = preferences.getString(_contextKey);
    final queueText = preferences.getString(_queueKey);
    final catalogText = preferences.getString(_catalogKey);
    final queueJson = queueText == null ? const [] : jsonDecode(queueText);
    return OfflinePosState(
      context: contextText == null
          ? null
          : OfflinePosContext.fromJson(
              Map<String, dynamic>.from(jsonDecode(contextText) as Map),
            ),
      catalog: catalogText == null
          ? const OfflineCatalog()
          : _catalogFromJson(
              Map<String, dynamic>.from(jsonDecode(catalogText) as Map),
            ),
      queue: queueJson is List
          ? queueJson
                .whereType<Map>()
                .map(
                  (item) => OfflineSaleRecord.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  Future<void> save(OfflinePosState state) async {
    final preferences = await SharedPreferences.getInstance();
    final context = state.context;
    if (context != null) {
      await preferences.setString(_contextKey, jsonEncode(context.toJson()));
    }
    await preferences.setString(
      _queueKey,
      jsonEncode(state.queue.map((item) => item.toJson()).toList()),
    );
    await preferences.setString(
      _catalogKey,
      jsonEncode(_catalogToJson(state.catalog)),
    );
    if (state.context?.active == true && state.catalog.isNotEmpty) {
      await preferences.setBool(_resumeAllowedKey, true);
    }
  }

  Future<bool> canResumeOffline() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_resumeAllowedKey) != true) return false;
    final state = await load();
    return state.ready && state.catalog.isNotEmpty;
  }

  Future<void> disableOfflineResume() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_resumeAllowedKey, false);
  }

  Future<void> clearCatalog() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_contextKey);
    await preferences.remove(_catalogKey);
    await preferences.setBool(_resumeAllowedKey, false);
  }

  Map<String, dynamic> _catalogToJson(OfflineCatalog catalog) => {
    'changes_cursor': catalog.changesCursor,
    'allow_overselling': catalog.allowOverselling,
    'cached_at': catalog.cachedAt?.toIso8601String(),
    'products': catalog.products
        .map(
          (product) => {
            'id': product.id,
            'name': product.name,
            'name_en': product.nameEn,
            'name_ar': product.nameAr,
            'sku': product.sku,
            'barcode': product.barcode,
            'category_id': product.categoryId,
            'purchase_price': product.purchasePrice,
            'selling_price': product.sellingPrice,
            'stock': product.stock,
            'minimum_stock': product.minimumStock,
            'variation_id': product.variationId,
            'tax_percent': product.taxPercent,
            'unit': product.unit,
            'unit_id': product.unitId,
            'tax_id': product.taxId,
            'active': product.active,
            'image_url': product.imageUrl,
          },
        )
        .toList(),
    'categories': catalog.categories.map(_categoryToJson).toList(),
    'customers': catalog.customers
        .map(
          (customer) => {
            'id': customer.id,
            'name': customer.name,
            'phone': customer.phone,
            'email': customer.email,
            'address': customer.address,
            'tax_number': customer.taxNumber,
            'business_name': customer.businessName,
            'contact_id': customer.contactId,
            'pay_term_number': customer.payTermNumber,
            'pay_term_type': customer.payTermType,
          },
        )
        .toList(),
    'locations': catalog.locations
        .map((item) => {'id': item.id, 'name': item.name})
        .toList(),
    'payment_options': catalog.paymentOptions
        .map((item) => {'code': item.code, 'label': item.label})
        .toList(),
    'taxes': catalog.taxes
        .map((item) => {'id': item.id, 'name': item.name, 'value': item.value})
        .toList(),
  };

  OfflineCatalog _catalogFromJson(Map<String, dynamic> json) => OfflineCatalog(
    changesCursor: (json['changes_cursor'] as num?)?.toInt() ?? 0,
    allowOverselling: json['allow_overselling'] == true,
    cachedAt: DateTime.tryParse('${json['cached_at'] ?? ''}'),
    products: (json['products'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return Product(
            id: '${item['id'] ?? ''}',
            name: '${item['name'] ?? ''}',
            nameEn: '${item['name_en'] ?? ''}',
            nameAr: '${item['name_ar'] ?? ''}',
            sku: '${item['sku'] ?? ''}',
            barcode: '${item['barcode'] ?? ''}',
            categoryId: '${item['category_id'] ?? ''}',
            purchasePrice: (item['purchase_price'] as num?)?.toInt() ?? 0,
            sellingPrice: (item['selling_price'] as num?)?.toInt() ?? 0,
            stock: (item['stock'] as num?)?.toInt() ?? 0,
            minimumStock: (item['minimum_stock'] as num?)?.toInt() ?? 0,
            variationId: '${item['variation_id'] ?? ''}',
            taxPercent: (item['tax_percent'] as num?)?.toDouble() ?? 0,
            unit: '${item['unit'] ?? 'pc'}',
            unitId: '${item['unit_id'] ?? ''}',
            taxId: '${item['tax_id'] ?? ''}',
            active: item['active'] != false,
            imageUrl: '${item['image_url'] ?? ''}',
          );
        })
        .toList(growable: false),
    categories: (json['categories'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => _categoryFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
    customers: (json['customers'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return Customer(
            id: '${item['id'] ?? ''}',
            name: '${item['name'] ?? ''}',
            phone: '${item['phone'] ?? ''}',
            email: '${item['email'] ?? ''}',
            address: '${item['address'] ?? ''}',
            taxNumber: item['tax_number']?.toString(),
            businessName: '${item['business_name'] ?? ''}',
            contactId: '${item['contact_id'] ?? ''}',
            payTermNumber: '${item['pay_term_number'] ?? ''}',
            payTermType: '${item['pay_term_type'] ?? 'days'}',
          );
        })
        .toList(growable: false),
    locations: (json['locations'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              BusinessLocation(id: '${item['id']}', name: '${item['name']}'),
        )
        .toList(growable: false),
    paymentOptions: (json['payment_options'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              PaymentOption(code: '${item['code']}', label: '${item['label']}'),
        )
        .toList(growable: false),
    taxes: (json['taxes'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => LookupOption(
            id: '${item['id']}',
            name: '${item['name']}',
            value: (item['value'] as num?)?.toDouble(),
          ),
        )
        .toList(growable: false),
  );

  Map<String, dynamic> _categoryToJson(Category category) => {
    'id': category.id,
    'name': category.name,
    'name_en': category.nameEn,
    'name_ar': category.nameAr,
    'icon': category.icon,
    'active': category.active,
    'subcategories': category.subCategories.map(_categoryToJson).toList(),
  };

  Category _categoryFromJson(Map<String, dynamic> json) => Category(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    nameEn: '${json['name_en'] ?? ''}',
    nameAr: '${json['name_ar'] ?? ''}',
    icon: '${json['icon'] ?? ''}',
    active: json['active'] != false,
    subCategories: (json['subcategories'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => _categoryFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
  );
}
