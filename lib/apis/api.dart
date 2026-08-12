import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import '../api_end_points.dart';
import '../config.dart';
import '../shared/models/entities.dart';
import '../features/purchases/domain/purchase_entities.dart';

enum LoginFailure { invalidCredentials, configuration, network, server }

class LoginResult {
  const LoginResult.success(this.accessToken) : failure = null, message = null;

  const LoginResult.failure(this.failure, {this.message}) : accessToken = null;

  final String? accessToken;
  final LoginFailure? failure;
  final String? message;
  bool get isSuccess => accessToken != null;
}

class Api {
  Api({
    http.Client? client,
    String? loginUrl,
    String? clientId,
    String? clientSecret,
  }) : _client = client ?? http.Client(),
       _loginUrl = loginUrl ?? ApiEndPoints.loginUrl,
       _clientId = clientId ?? Config.clientId,
       _clientSecret = clientSecret ?? Config.clientSecret;
  final http.Client _client;
  final String _loginUrl, _clientId, _clientSecret;

  Future<LoginResult> login(String username, String password) async {
    if (_clientSecret.isEmpty) {
      return const LoginResult.failure(LoginFailure.configuration);
    }

    try {
      final response = await _client
          .post(
            Uri.parse(_loginUrl),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'password',
              'client_id': _clientId,
              'client_secret': _clientSecret,
              'username': username,
              'password': password,
            },
          )
          .timeout(const Duration(seconds: 20));

      final json = _decode(response.body);
      final token = json['access_token']?.toString();
      if (response.statusCode == 200 && token != null && token.isNotEmpty) {
        return LoginResult.success(token);
      }
      if (response.statusCode == 401 ||
          (response.statusCode == 400 && json['error'] == 'invalid_grant')) {
        return LoginResult.failure(
          LoginFailure.invalidCredentials,
          message: _message(json),
        );
      }
      return LoginResult.failure(LoginFailure.server, message: _message(json));
    } catch (_) {
      return const LoginResult.failure(LoginFailure.network);
    }
  }

  Future<List<Product>> products(String accessToken) async {
    final uri = Uri.parse(
      ApiEndPoints.productsUrl,
    ).replace(queryParameters: const {'per_page': '-1'});
    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException('Unable to load products (${response.statusCode}).');
    }
    final payload = _decode(response.body);
    final data = payload['data'];
    if (data is! List) throw const ApiException('Invalid product response.');
    return data
        .whereType<Map<String, dynamic>>()
        .map(_productFromJson)
        .toList(growable: false);
  }

  Future<List<LookupOption>> units(String accessToken) =>
      _lookupOptions(ApiEndPoints.unitsUrl, accessToken, 'units');

  Future<List<LookupOption>> taxes(String accessToken) =>
      _lookupOptions(ApiEndPoints.taxesUrl, accessToken, 'taxes');

  Future<List<LookupOption>> brands(String accessToken) =>
      _lookupOptions(ApiEndPoints.brandsUrl, accessToken, 'brands');

  Future<List<LookupOption>> _lookupOptions(
    String url,
    String accessToken,
    String resource,
  ) async {
    final data = await _getDataList(Uri.parse(url), accessToken, resource);
    return data
        .map(
          (item) => LookupOption(
            id: item['id'].toString(),
            name:
                item['actual_name']?.toString() ??
                item['name']?.toString() ??
                item['short_name']?.toString() ??
                '',
            value: _number(item['amount']),
          ),
        )
        .toList(growable: false);
  }

  Future<Product> createProduct({
    required String accessToken,
    required ProductDraft draft,
    bool quick = false,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        quick ? ApiEndPoints.quickProductUrl : ApiEndPoints.productWritesUrl,
      ),
    );
    request.headers.addAll(_authorizedHeaders(accessToken));
    request.fields.addAll(_productFields(draft, includeType: !quick));
    if (quick && draft.openingStock > 0 && draft.locationIds.isNotEmpty) {
      final location = draft.locationIds.first;
      request.fields['opening_stock[$location][quantity]'] =
          '${draft.openingStock}';
      request.fields['opening_stock[$location][purchase_price]'] =
          '${draft.purchasePrice / 100}';
    }
    _attachImage(request, draft);
    return _productFromWriteResponse(
      await _sendMultipart(request),
      'create product',
    );
  }

  Future<Product> updateProduct({
    required String accessToken,
    required Product product,
    required ProductDraft draft,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiEndPoints.productWritesUrl}/${product.id}'),
    );
    request.headers.addAll(_authorizedHeaders(accessToken));
    request.fields['_method'] = 'PATCH';
    request.fields.addAll(_productFields(draft));
    _attachImage(request, draft);
    return _productFromWriteResponse(
      await _sendMultipart(request),
      'update product',
    );
  }

  Future<List<Product>> bulkUpdateProducts({
    required String accessToken,
    required List<Product> products,
    String? categoryId,
    String? locationId,
    int? sellingPrice,
  }) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.bulkProductsUrl),
          headers: {
            ..._authorizedHeaders(accessToken),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'products': [
              for (final product in products)
                {
                  'id': int.parse(product.id),
                  if (categoryId != null) 'category_id': int.parse(categoryId),
                  if (locationId != null)
                    'product_locations': [int.parse(locationId)],
                  if (sellingPrice != null)
                    'variations': {
                      product.variationId: {
                        'default_sell_price': sellingPrice / 100,
                        'sell_price_inc_tax': sellingPrice / 100,
                      },
                    },
                },
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));
    final payload = _requireObject(response, 'bulk product update');
    final data = payload['data'];
    if (data is! List)
      throw const ApiException('Invalid bulk product response.');
    return data
        .whereType<Map<String, dynamic>>()
        .map(_productFromJson)
        .toList();
  }

  Future<List<Product>> importProducts({
    required String accessToken,
    required List<int> bytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiEndPoints.importProductsUrl),
    );
    request.headers.addAll(_authorizedHeaders(accessToken));
    request.files.add(
      http.MultipartFile.fromBytes('products_file', bytes, filename: fileName),
    );
    final payload = await _sendMultipart(request);
    final data = payload['data'];
    if (data is! List)
      throw const ApiException('Invalid product import response.');
    return data
        .whereType<Map<String, dynamic>>()
        .map(_productFromJson)
        .toList();
  }

  Map<String, String> _productFields(
    ProductDraft draft, {
    bool includeType = false,
  }) => {
    'name': draft.name.trim(),
    if (includeType) 'type': 'single',
    'unit_id': draft.unitId,
    // EazyERP's server-side SKU generator currently reads web-session state,
    // which is unavailable on stateless Connector API requests. Preserve the
    // documented blank-SKU UX by generating a collision-resistant SKU here.
    'sku': draft.sku.trim().isEmpty
        ? 'GM-${DateTime.now().microsecondsSinceEpoch}'
        : draft.sku.trim(),
    'enable_stock': draft.manageStock ? '1' : '0',
    'enable_sr_no': draft.enableSerialNumber ? '1' : '0',
    'not_for_selling': draft.notForSelling ? '1' : '0',
    'barcode_type': draft.barcodeType,
    'tax_type': draft.taxType,
    'alert_quantity': '${draft.minimumStock}',
    'single_dpp': '${draft.purchasePrice / 100}',
    'single_dpp_inc_tax':
        '${(draft.purchasePriceIncTax ?? draft.purchasePrice) / 100}',
    'profit_percent': '${draft.profitPercent}',
    'single_dsp': '${draft.sellingPrice / 100}',
    'single_dsp_inc_tax':
        '${(draft.sellingPriceIncTax ?? draft.sellingPrice) / 100}',
    if (draft.categoryId.isNotEmpty) 'category_id': draft.categoryId,
    if (draft.subCategoryId.isNotEmpty) 'sub_category_id': draft.subCategoryId,
    if (draft.brandId.isNotEmpty) 'brand_id': draft.brandId,
    if (draft.taxId.isNotEmpty) 'tax': draft.taxId,
    if (draft.description.isNotEmpty) 'product_description': draft.description,
    if (draft.weight.isNotEmpty) 'weight': draft.weight,
    if (draft.preparationMinutes != null)
      'preparation_time_in_minutes': '${draft.preparationMinutes}',
    for (var i = 0; i < draft.locationIds.length; i++)
      'product_locations[$i]': draft.locationIds[i],
  };

  void _attachImage(http.MultipartRequest request, ProductDraft draft) {
    if (draft.imageBytes != null && draft.imageName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          draft.imageBytes!,
          filename: draft.imageName,
        ),
      );
    }
    if (draft.brochureBytes != null && draft.brochureName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'product_brochure',
          draft.brochureBytes!,
          filename: draft.brochureName,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _sendMultipart(
    http.MultipartRequest request,
  ) async {
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    return _requireObject(response, 'product');
  }

  Product _productFromWriteResponse(
    Map<String, dynamic> payload,
    String resource,
  ) {
    final data = payload['data'];
    if (data is! Map) throw ApiException('Invalid $resource response.');
    return _productFromJson(Map<String, dynamic>.from(data));
  }

  Future<List<Category>> categories(String accessToken) async {
    final uri = Uri.parse(
      ApiEndPoints.categoriesUrl,
    ).replace(queryParameters: const {'type': 'product'});
    final response = await _client
        .get(uri, headers: _authorizedHeaders(accessToken))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException('Unable to load categories (${response.statusCode}).');
    }
    final data = _decode(response.body)['data'];
    if (data is! List) throw const ApiException('Invalid category response.');
    Category mapCategory(Map<String, dynamic> item) => Category(
      id: item['id'].toString(),
      name: item['name']?.toString() ?? '',
      icon: '',
      subCategories: (item['sub_categories'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(mapCategory)
          .toList(growable: false),
    );
    return data
        .whereType<Map<String, dynamic>>()
        .map(mapCategory)
        .toList(growable: false);
  }

  Future<List<Customer>> customers(String accessToken) async {
    final uri = Uri.parse(
      ApiEndPoints.customersUrl,
    ).replace(queryParameters: const {'type': 'customer', 'per_page': '-1'});
    final data = await _getDataList(uri, accessToken, 'customers');
    return data.map(_customerFromJson).toList(growable: false);
  }

  Future<List<Supplier>> suppliers(String accessToken) async {
    final uri = Uri.parse(
      ApiEndPoints.customersUrl,
    ).replace(queryParameters: const {'type': 'supplier', 'per_page': '-1'});
    final data = await _getDataList(uri, accessToken, 'suppliers');
    return data
        .map(
          (item) => Supplier(
            id: item['id'].toString(),
            name:
                item['supplier_business_name']?.toString().trim().isNotEmpty ==
                    true
                ? item['supplier_business_name'].toString()
                : item['name']?.toString() ?? 'Supplier',
          ),
        )
        .toList(growable: false);
  }

  Future<List<PurchaseDocument>> purchaseDocuments(
    String accessToken,
    PurchaseDocumentType type,
  ) async {
    final uri = Uri.parse(
      _purchaseUrl(type),
    ).replace(queryParameters: const {'per_page': '-1'});
    final response = await _client
        .get(uri, headers: _authorizedHeaders(accessToken))
        .timeout(const Duration(seconds: 20));
    final json = _requireObject(response, _purchaseLabel(type));
    final raw = json['data'];
    final list = raw is List
        ? raw
        : raw is Map && raw['data'] is List
        ? raw['data'] as List
        : const [];
    return list
        .whereType<Map>()
        .map((item) => _purchaseFromJson(Map<String, dynamic>.from(item), type))
        .toList(growable: false);
  }

  Future<PurchaseDocument> purchaseDocument(
    String accessToken,
    PurchaseDocumentType type,
    String id,
  ) async {
    final response = await _client
        .get(
          Uri.parse('${_purchaseUrl(type)}/$id'),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    final json = _requireObject(response, _purchaseLabel(type));
    final data = _map(json['data']);
    return _purchaseFromJson(data.isEmpty ? json : data, type);
  }

  Future<PurchaseDocument> savePurchaseDocument({
    required String accessToken,
    required PurchaseDraft draft,
    String? id,
  }) async {
    final uri = Uri.parse(
      id == null ? _purchaseUrl(draft.type) : '${_purchaseUrl(draft.type)}/$id',
    );
    final body = jsonEncode(draft.toJson());
    final response =
        await (id == null
                ? _client.post(
                    uri,
                    headers: _jsonHeaders(accessToken),
                    body: body,
                  )
                : _client.patch(
                    uri,
                    headers: _jsonHeaders(accessToken),
                    body: body,
                  ))
            .timeout(const Duration(seconds: 30));
    final json = _requireObject(response, _purchaseLabel(draft.type));
    final data = _map(json['data']);
    if (data.isNotEmpty) return _purchaseFromJson(data, draft.type);
    final savedId = json['id']?.toString() ?? id;
    if (savedId != null && savedId.isNotEmpty) {
      return purchaseDocument(accessToken, draft.type, savedId);
    }
    return PurchaseDocument(
      id: id ?? '',
      type: draft.type,
      reference: draft.reference,
      supplierId: draft.supplierId,
      supplierName: '',
      locationId: draft.locationId,
      locationName: '',
      date: draft.date,
      status: draft.status,
      shippingStatus: draft.shippingStatus,
      notes: draft.notes,
      purchaseOrderId: draft.purchaseOrderId,
      lines: draft.lines,
      total: draft.lines.fold(0, (sum, line) => sum + line.lineTotal.round()),
    );
  }

  Future<void> deletePurchaseDocument(
    String accessToken,
    PurchaseDocumentType type,
    String id,
  ) async {
    final response = await _client
        .delete(
          Uri.parse('${_purchaseUrl(type)}/$id'),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    _requireObject(response, _purchaseLabel(type));
  }

  Future<PurchaseDocument> updatePurchaseOrderStatus(
    String accessToken,
    String id,
    String status,
  ) async {
    final response = await _client
        .patch(
          Uri.parse('${ApiEndPoints.purchaseOrdersUrl}/$id/status'),
          headers: _jsonHeaders(accessToken),
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 20));
    final json = _requireObject(response, 'purchase order status');
    final data = _map(json['data']);
    return data.isEmpty
        ? purchaseDocument(accessToken, PurchaseDocumentType.order, id)
        : _purchaseFromJson(data, PurchaseDocumentType.order);
  }

  String _purchaseUrl(PurchaseDocumentType type) => switch (type) {
    PurchaseDocumentType.order => ApiEndPoints.purchaseOrdersUrl,
    PurchaseDocumentType.invoice => ApiEndPoints.purchasesUrl,
    PurchaseDocumentType.purchaseReturn => ApiEndPoints.purchaseReturnsUrl,
  };

  String _purchaseLabel(PurchaseDocumentType type) => switch (type) {
    PurchaseDocumentType.order => 'purchase orders',
    PurchaseDocumentType.invoice => 'purchase invoices',
    PurchaseDocumentType.purchaseReturn => 'purchase returns',
  };

  Map<String, String> _jsonHeaders(String token) => {
    ..._authorizedHeaders(token),
    'Content-Type': 'application/json',
  };

  PurchaseDocument _purchaseFromJson(
    Map<String, dynamic> json,
    PurchaseDocumentType type,
  ) {
    final contact = _map(json['contact'] ?? json['supplier']);
    final location = _map(json['location'] ?? json['business_location']);
    final rawLines =
        json['purchase_lines'] ??
        json['purchase_order_lines'] ??
        json['return_lines'] ??
        json['products'] ??
        json['lines'] ??
        const [];
    final lines = rawLines is List
        ? rawLines
              .whereType<Map>()
              .map((raw) {
                final line = Map<String, dynamic>.from(raw);
                final product = _map(line['product']);
                final variation = _map(line['variation']);
                final quantity = _number(
                  line['quantity_returned'] ?? line['quantity'] ?? line['qty'],
                );
                final cost = _number(
                  line['purchase_price_inc_tax'] ??
                      line['purchase_price'] ??
                      line['unit_cost'] ??
                      line['unit_price'],
                );
                return PurchaseLineRecord(
                  id: line['id']?.toString(),
                  productId: (line['product_id'] ?? product['id'] ?? '')
                      .toString(),
                  variationId: (line['variation_id'] ?? variation['id'] ?? '')
                      .toString(),
                  name:
                      product['name']?.toString() ??
                      line['product_name']?.toString() ??
                      variation['name']?.toString() ??
                      'Product',
                  sku:
                      variation['sub_sku']?.toString() ??
                      line['sub_sku']?.toString() ??
                      '',
                  quantity: quantity,
                  unitCost: cost * 100,
                  discountPercent: _number(line['discount_percent']),
                  taxId: line['tax_id']?.toString(),
                );
              })
              .toList(growable: false)
        : const <PurchaseLineRecord>[];
    final parsedDate = DateTime.tryParse(
      (json['transaction_date'] ?? json['created_at'] ?? '').toString(),
    );
    return PurchaseDocument(
      id: json['id']?.toString() ?? '',
      type: type,
      reference: (json['ref_no'] ?? json['invoice_no'] ?? '#${json['id']}')
          .toString(),
      supplierId:
          (json['contact_id'] ?? json['supplier_id'] ?? contact['id'] ?? '')
              .toString(),
      supplierName:
          contact['supplier_business_name']?.toString() ??
          contact['name']?.toString() ??
          json['supplier_name']?.toString() ??
          'Supplier',
      locationId: (json['location_id'] ?? location['id'] ?? '').toString(),
      locationName:
          location['name']?.toString() ??
          json['location_name']?.toString() ??
          '',
      date: parsedDate ?? DateTime.now(),
      status: json['status']?.toString() ?? 'draft',
      shippingStatus: json['shipping_status']?.toString() ?? '',
      notes: (json['additional_notes'] ?? json['notes'] ?? '').toString(),
      purchaseOrderId: json['purchase_order_id']?.toString(),
      lines: lines,
      total: _money(json['final_total'] ?? json['total']),
    );
  }

  Future<List<BusinessLocation>> locations(String accessToken) async {
    final data = await _getDataList(
      Uri.parse(ApiEndPoints.locationsUrl),
      accessToken,
      'locations',
    );
    return data
        .map(
          (item) => BusinessLocation(
            id: item['id'].toString(),
            name: item['name']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<List<PaymentOption>> paymentOptions(String accessToken) async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.paymentMethodsUrl),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    final json = _requireObject(response, 'payment methods');
    return json.entries
        .map(
          (entry) => PaymentOption(
            code: entry.key,
            label: entry.value?.toString() ?? entry.key,
          ),
        )
        .toList(growable: false);
  }

  Future<BusinessProfile> businessDetails(String accessToken) async {
    final json = await _getDataObject(
      Uri.parse(ApiEndPoints.businessDetailsUrl),
      accessToken,
      'business details',
    );
    final currency = _map(json['currency']);
    return BusinessProfile(
      name: json['name']?.toString() ?? '',
      currencyCode: currency['code']?.toString() ?? '',
      currencySymbol: currency['symbol']?.toString() ?? '',
      timeZone: json['time_zone']?.toString() ?? '',
      taxLabel: json['tax_label_1']?.toString() ?? '',
    );
  }

  Future<UserProfile> loggedInUser(String accessToken) async {
    final json = await _getDataObject(
      Uri.parse(ApiEndPoints.loggedInUserUrl),
      accessToken,
      'user profile',
    );
    final names = [
      json['first_name'],
      json['last_name'],
    ].where((value) => value?.toString().trim().isNotEmpty == true).join(' ');
    return UserProfile(
      name: names.isEmpty ? json['username']?.toString() ?? '' : names,
      username: json['username']?.toString() ?? '',
      isAdmin: json['is_admin'] == true || json['is_admin'] == 1,
    );
  }

  Future<ProfitLoss> profitLoss(String accessToken) async {
    final json = await _getDataObject(
      Uri.parse(ApiEndPoints.profitLossUrl),
      accessToken,
      'profit and loss report',
    );
    return ProfitLoss(
      totalSales: _money(json['total_sell']),
      totalPurchases: _money(json['total_purchase']),
      totalExpenses: _money(json['total_expense']),
      grossProfit: _money(json['gross_profit']),
      netProfit: _money(json['net_profit']),
    );
  }

  Future<List<StockItem>> stockReport(String accessToken) async {
    final data = await _getAllPages(
      Uri.parse(ApiEndPoints.stockReportUrl),
      accessToken,
      'stock report',
    );
    return data
        .map(
          (item) => StockItem(
            productId: item['product_id'].toString(),
            variationId: item['variation_id'].toString(),
            name: item['product']?.toString() ?? '',
            sku: item['sku']?.toString() ?? '',
            unit: item['unit']?.toString() ?? '',
            stock: _number(item['stock']).floor(),
            minimumStock: _number(item['alert_quantity']).floor(),
            unitPrice: _money(item['unit_price']),
            locationName: item['location_name']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<List<Sale>> sales(
    String accessToken,
    List<Product> products,
    List<Customer> customers,
  ) async {
    final uri = Uri.parse(
      ApiEndPoints.salesUrl,
    ).replace(queryParameters: const {'per_page': '-1'});
    final data = await _getDataList(uri, accessToken, 'sales');
    final productById = {for (final item in products) item.id: item};
    final customerById = {for (final item in customers) item.id: item};
    return data
        .map((item) => _saleFromJson(item, productById, customerById))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createSale({
    required String accessToken,
    required String locationId,
    required Customer customer,
    required List<CartLine> lines,
    required String paymentMethod,
    required int total,
  }) async {
    final body = {
      'sells': [
        {
          'location_id': int.parse(locationId),
          'contact_id': int.parse(customer.id),
          'status': 'final',
          'discount_type': 'fixed',
          'discount_amount': 0,
          'products': [
            for (final line in lines)
              {
                'product_id': int.parse(line.product.id),
                'variation_id': int.parse(line.product.variationId),
                'quantity': line.quantity,
                'unit_price': line.product.sellingPrice / 100,
                'discount_type': 'fixed',
                'discount_amount': line.discount / 100,
              },
          ],
          'payment': [
            {'amount': total / 100, 'method': paymentMethod},
          ],
        },
      ],
    };
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.salesUrl),
          headers: {
            ..._authorizedHeaders(accessToken),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    final decoded = _decodeAny(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _apiMessage(decoded, 'Unable to create sale.'),
        statusCode: response.statusCode,
      );
    }
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      throw const ApiException('Invalid create-sale response.');
    }
    var result = Map<String, dynamic>.from(decoded.first as Map);
    if (result['original'] is Map) result = _map(result['original']);
    if (result['error'] != null || result['success'] == false) {
      throw ApiException(_apiMessage(result, 'Unable to create sale.'));
    }
    return result;
  }

  Future<Customer> createCustomer({
    required String accessToken,
    required String name,
    required String mobile,
    String email = '',
    String taxNumber = '',
  }) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.customersUrl),
          headers: {
            ..._authorizedHeaders(accessToken),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'type': 'customer',
            'first_name': name,
            'mobile': mobile,
            if (email.isNotEmpty) 'email': email,
            if (taxNumber.isNotEmpty) 'tax_number': taxNumber,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final payload = _requireObject(response, 'customer');
    return _customerFromJson(_map(payload['data']));
  }

  Future<Customer> updateCustomer({
    required String accessToken,
    required Customer customer,
    required String name,
    required String mobile,
    String email = '',
    String taxNumber = '',
  }) async {
    final response = await _client
        .put(
          Uri.parse('${ApiEndPoints.customersUrl}/${customer.id}'),
          headers: {
            ..._authorizedHeaders(accessToken),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'type': 'customer',
            'first_name': name,
            'mobile': mobile,
            'email': email,
            'tax_number': taxNumber,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final payload = _requireObject(response, 'customer');
    return _customerFromJson(_map(payload['data']));
  }

  Map<String, String> _authorizedHeaders(String accessToken) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };

  Product _productFromJson(Map<String, dynamic> json) {
    final variationGroups = json['product_variations'];
    final variationGroup = variationGroups is List && variationGroups.isNotEmpty
        ? variationGroups.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final variations = variationGroup['variations'];
    final variation = variations is List && variations.isNotEmpty
        ? variations.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final locationDetails = variation['variation_location_details'];
    final stock = locationDetails is List
        ? locationDetails.whereType<Map<String, dynamic>>().fold<double>(
            0,
            (sum, item) => sum + _number(item['qty_available']),
          )
        : 0;
    final category = json['category'];
    final categoryId = category is Map<String, dynamic>
        ? category['id']?.toString() ?? ''
        : '';
    final sku = json['sku']?.toString() ?? '';
    final productTax = _map(json['product_tax']);
    return Product(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      sku: sku,
      barcode: sku,
      categoryId: categoryId,
      purchasePrice: (_number(variation['dpp_inc_tax']) * 100).round(),
      sellingPrice: (_number(variation['sell_price_inc_tax']) * 100).round(),
      stock: stock.floor(),
      minimumStock: _number(json['alert_quantity']).floor(),
      variationId: variation['id']?.toString() ?? '',
      taxPercent: _number(productTax['amount']),
      unit: (json['unit'] is Map<String, dynamic>)
          ? (json['unit']['short_name']?.toString() ?? 'pc')
          : 'pc',
      unitId:
          _map(json['unit'])['id']?.toString() ??
          json['unit_id']?.toString() ??
          '',
      taxId: productTax['id']?.toString() ?? json['tax']?.toString() ?? '',
      active: json['is_inactive'] != 1,
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  int _money(dynamic value) => (_number(value) * 100).round();

  Customer _customerFromJson(Map<String, dynamic> json) => Customer(
    id: json['id'].toString(),
    name: json['name']?.toString().trim().isNotEmpty == true
        ? json['name'].toString()
        : json['first_name']?.toString() ?? '',
    phone: json['mobile']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    address: [
      json['address_line_1'],
      json['address_line_2'],
      json['city'],
      json['state'],
      json['country'],
    ].where((value) => value?.toString().trim().isNotEmpty == true).join(', '),
    taxNumber: json['tax_number']?.toString(),
  );

  Sale _saleFromJson(
    Map<String, dynamic> json,
    Map<String, Product> products,
    Map<String, Customer> customers,
  ) {
    final lines = (json['sell_lines'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((line) {
          final product = products[line['product_id'].toString()];
          if (product == null) return null;
          return CartLine(
            product: product,
            quantity: _number(line['quantity']).round(),
            discount: _money(line['line_discount_amount']),
          );
        })
        .whereType<CartLine>()
        .toList(growable: false);
    final payments = json['payment_lines'] as List? ?? const [];
    final payment = payments.whereType<Map<String, dynamic>>().firstOrNull;
    final created = DateTime.tryParse(
      json['transaction_date']?.toString() ?? '',
    );
    return Sale(
      localId: 'server-${json['id']}',
      serverId: json['id']?.toString(),
      invoiceNo: json['invoice_no']?.toString() ?? '',
      createdAt: created ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          created ??
          DateTime.now(),
      customer:
          customers[json['contact_id'].toString()] ??
          Customer(
            id: json['contact_id'].toString(),
            name: _map(json['contact'])['name']?.toString() ?? 'Customer',
          ),
      items: lines,
      paymentMethod: payment?['method']?.toString() ?? 'due',
      total: _money(json['final_total']),
      tax: _money(json['tax_amount']),
      discount: _money(json['discount_amount']),
      syncStatus: SyncStatus.synced,
    );
  }

  Future<List<Map<String, dynamic>>> _getDataList(
    Uri uri,
    String accessToken,
    String resource,
  ) async {
    final response = await _client
        .get(uri, headers: _authorizedHeaders(accessToken))
        .timeout(const Duration(seconds: 20));
    final json = _requireObject(response, resource);
    final data = json['data'];
    if (data is! List) throw ApiException('Invalid $resource response.');
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _getAllPages(
    Uri uri,
    String accessToken,
    String resource,
  ) async {
    final items = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = await _client
          .get(
            uri.replace(queryParameters: {'page': '$page'}),
            headers: _authorizedHeaders(accessToken),
          )
          .timeout(const Duration(seconds: 20));
      final json = _requireObject(response, resource);
      final data = json['data'];
      if (data is! List) throw ApiException('Invalid $resource response.');
      items.addAll(data.whereType<Map<String, dynamic>>());
      lastPage =
          int.tryParse(_map(json['meta'])['last_page']?.toString() ?? '') ?? 1;
      page++;
    } while (page <= lastPage);
    return items;
  }

  Future<Map<String, dynamic>> _getDataObject(
    Uri uri,
    String accessToken,
    String resource,
  ) async {
    final response = await _client
        .get(uri, headers: _authorizedHeaders(accessToken))
        .timeout(const Duration(seconds: 20));
    final json = _requireObject(response, resource);
    return _map(json['data']);
  }

  Map<String, dynamic> _requireObject(http.Response response, String resource) {
    final decoded = _decodeAny(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _apiMessage(decoded, 'Unable to load $resource.'),
        statusCode: response.statusCode,
        validationErrors: decoded is Map ? _map(decoded['errors']) : const {},
      );
    }
    if (decoded is! Map) throw ApiException('Invalid $resource response.');
    return Map<String, dynamic>.from(decoded);
  }

  dynamic _decodeAny(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  String _apiMessage(dynamic value, String fallback) {
    if (value is Map) {
      final message = value['message'] ?? value['error_description'];
      if (message != null) return message.toString();
      if (value['error'] != null) return _apiMessage(value['error'], fallback);
    }
    return fallback;
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : const {};
    } catch (_) {
      return const {};
    }
  }

  String? _message(Map<String, dynamic> json) =>
      (json['message'] ?? json['error_description'] ?? json['error'])
          ?.toString();
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.validationErrors = const {},
  });
  final String message;
  final int? statusCode;
  final Map<String, dynamic> validationErrors;
  @override
  String toString() => message;
}
