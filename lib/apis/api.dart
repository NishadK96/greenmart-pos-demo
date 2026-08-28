import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import '../api_end_points.dart';
import '../shared/models/entities.dart';
import '../features/cash_register/domain/cash_register_entities.dart';
import '../features/purchases/domain/purchase_entities.dart';
import '../features/zatca/domain/zatca_entities.dart';

enum LoginFailure { invalidCredentials, network, server }

class LoginResult {
  const LoginResult.success(this.accessToken) : failure = null, message = null;

  const LoginResult.failure(this.failure, {this.message}) : accessToken = null;

  final String? accessToken;
  final LoginFailure? failure;
  final String? message;
  bool get isSuccess => accessToken != null;
}

class SavedAccountProfile {
  const SavedAccountProfile({
    required this.id,
    required this.username,
    required this.name,
    required this.businessId,
  });
  final String id;
  final String username;
  final String name;
  final String businessId;
  factory SavedAccountProfile.fromJson(Map<String, dynamic> json) =>
      SavedAccountProfile(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        name: json['name']?.toString() ?? json['username']?.toString() ?? '',
        businessId: json['business_id']?.toString() ?? '',
      );
}

class SavedAccountSession {
  const SavedAccountSession({
    required this.sessionId,
    required this.profile,
    required this.active,
    required this.expired,
  });
  final String sessionId;
  final SavedAccountProfile profile;
  final bool active;
  final bool expired;
  SavedAccountSession copyWith({bool? active}) => SavedAccountSession(
    sessionId: sessionId,
    profile: profile,
    active: active ?? this.active,
    expired: expired,
  );
  factory SavedAccountSession.fromJson(Map<String, dynamic> json) =>
      SavedAccountSession(
        sessionId: json['session_id']?.toString() ?? '',
        profile: SavedAccountProfile.fromJson(
          Map<String, dynamic>.from(json['profile'] as Map? ?? const {}),
        ),
        active: json['active'] == true,
        expired:
            json['expired'] == true ||
            json['signed_out'] == true ||
            (json['status'] != null && json['status'] != 'active'),
      );
}

class SessionLoginResult {
  const SessionLoginResult({
    required this.sessionId,
    required this.profile,
    required this.accessToken,
    this.refreshToken,
  });
  final String sessionId;
  final SavedAccountProfile profile;
  final String accessToken;
  final String? refreshToken;
}

class WebAuthBootstrap {
  const WebAuthBootstrap({required this.csrfToken});
  final String csrfToken;
}

class Api {
  Api({http.Client? client, String? loginUrl})
    : _client = client ?? http.Client(),
      _loginUrl = loginUrl ?? ApiEndPoints.loginUrl;
  final http.Client _client;
  final String _loginUrl;

  Future<LoginResult> login(String username, String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse(_loginUrl),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'username': username, 'password': password}),
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

  Future<SessionLoginResult> sessionLogin(
    String username,
    String password,
    Map<String, String> deviceHeaders,
  ) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.authLoginUrl),
          headers: {
            ...deviceHeaders,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    return _sessionResult(_requireObject(response, 'saved account login'));
  }

  Future<List<SavedAccountSession>> savedSessions(
    Map<String, String> deviceHeaders,
  ) async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.authSessionsUrl),
          headers: {...deviceHeaders, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));
    final payload = _requireObject(response, 'saved accounts');
    final data = payload['data'] as List? ?? const [];
    return data
        .whereType<Map>()
        .map(
          (item) =>
              SavedAccountSession.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<SessionLoginResult> activateSession(
    String sessionId,
    String refreshToken,
    Map<String, String> deviceHeaders,
  ) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.authSessionActivateUrl(sessionId)),
          headers: {
            ...deviceHeaders,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(const Duration(seconds: 20));
    return _sessionResult(_requireObject(response, 'account switch'));
  }

  Future<void> removeSession(
    String sessionId,
    Map<String, String> deviceHeaders,
  ) async {
    final response = await _client
        .delete(
          Uri.parse(ApiEndPoints.authSessionUrl(sessionId)),
          headers: {...deviceHeaders, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));
    _requireObject(response, 'remove saved account');
  }

  Future<WebAuthBootstrap> webAuthBootstrap() async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.webAuthBootstrapUrl),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));
    final payload = _requireObject(response, 'web authentication bootstrap');
    final csrfToken = payload['csrf_token']?.toString() ?? '';
    if (csrfToken.isEmpty) {
      throw const ApiException('Invalid web authentication bootstrap.');
    }
    return WebAuthBootstrap(csrfToken: csrfToken);
  }

  Future<SessionLoginResult> webSessionLogin(
    String username,
    String password,
    String csrfToken,
  ) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.webAuthLoginUrl),
          headers: _webAuthHeaders(csrfToken, json: true),
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    return _webSessionResult(_requireObject(response, 'web account login'));
  }

  Future<List<SavedAccountSession>> webSavedSessions() async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.webAuthSessionsUrl),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));
    final payload = _requireObject(response, 'saved web accounts');
    final data = payload['data'] as List? ?? const [];
    return data
        .whereType<Map>()
        .map(
          (item) =>
              SavedAccountSession.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<SessionLoginResult> activateWebSession(
    String sessionId,
    String csrfToken,
  ) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.webAuthSessionActivateUrl(sessionId)),
          headers: _webAuthHeaders(csrfToken),
        )
        .timeout(const Duration(seconds: 20));
    return _webSessionResult(_requireObject(response, 'web account switch'));
  }

  Future<void> removeWebSession(String sessionId, String csrfToken) async {
    final response = await _client
        .delete(
          Uri.parse(ApiEndPoints.webAuthSessionUrl(sessionId)),
          headers: _webAuthHeaders(csrfToken),
        )
        .timeout(const Duration(seconds: 20));
    _requireObject(response, 'remove saved web account');
  }

  Future<void> logoutWebSession(String accessToken, String csrfToken) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.webAuthLogoutUrl),
          headers: {
            ..._webAuthHeaders(csrfToken),
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(const Duration(seconds: 20));
    _requireObject(response, 'web logout');
  }

  Map<String, String> _webAuthHeaders(String csrfToken, {bool json = false}) =>
      {
        'Accept': 'application/json',
        'X-CSRF-TOKEN': csrfToken,
        if (json) 'Content-Type': 'application/json',
      };

  SessionLoginResult _sessionResult(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final token = data['access_token']?.toString() ?? '';
    final refresh = data['refresh_token']?.toString() ?? '';
    final id = data['session_id']?.toString() ?? '';
    if (token.isEmpty || refresh.isEmpty || id.isEmpty) {
      throw const ApiException('Invalid account session response.');
    }
    return SessionLoginResult(
      sessionId: id,
      profile: SavedAccountProfile.fromJson(
        Map<String, dynamic>.from(data['profile'] as Map? ?? const {}),
      ),
      accessToken: token,
      refreshToken: refresh,
    );
  }

  SessionLoginResult _webSessionResult(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final token = data['access_token']?.toString() ?? '';
    final id = data['session_id']?.toString() ?? '';
    if (token.isEmpty || id.isEmpty) {
      throw const ApiException('Invalid web account session response.');
    }
    return SessionLoginResult(
      sessionId: id,
      profile: SavedAccountProfile.fromJson(
        Map<String, dynamic>.from(data['profile'] as Map? ?? const {}),
      ),
      accessToken: token,
    );
  }

  Future<CashRegister?> currentCashRegister(String accessToken) async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.cashRegisterCurrentUrl),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    final payload = _requireObject(response, 'current cash register');
    final data = _map(payload['data']);
    return data.isEmpty ? null : CashRegister.fromJson(data);
  }

  Future<CashRegister> openCashRegister(
    String accessToken,
    String locationId,
    double initialCash,
  ) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.cashRegisterOpenUrl),
          headers: _authorizedHeaders(accessToken, json: true),
          body: jsonEncode({
            'location_id': int.tryParse(locationId) ?? locationId,
            'initial_cash': initialCash,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final payload = _requireObject(response, 'cash register');
    return CashRegister.fromJson(_map(payload['data']));
  }

  Future<void> cashRegisterCashIn(
    String accessToken,
    String registerId,
    double amount,
  ) => _cashRegisterMovement(accessToken, registerId, amount, cashIn: true);

  Future<void> cashRegisterCashOut(
    String accessToken,
    String registerId,
    double amount,
  ) => _cashRegisterMovement(accessToken, registerId, amount, cashIn: false);

  Future<void> _cashRegisterMovement(
    String accessToken,
    String registerId,
    double amount, {
    required bool cashIn,
  }) async {
    final response = await _client
        .post(
          Uri.parse(
            cashIn
                ? ApiEndPoints.cashRegisterCashInUrl(registerId)
                : ApiEndPoints.cashRegisterCashOutUrl(registerId),
          ),
          headers: _authorizedHeaders(accessToken, json: true),
          body: jsonEncode({'amount': amount}),
        )
        .timeout(const Duration(seconds: 20));
    _requireObject(response, cashIn ? 'cash in' : 'cash out');
  }

  Future<CashRegisterSummary> cashRegisterSummary(
    String accessToken,
    String registerId,
  ) async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.cashRegisterSummaryUrl(registerId)),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    final payload = _requireObject(response, 'cash register summary');
    return CashRegisterSummary.fromJson(_map(payload['data']));
  }

  Future<CashRegisterSummary> closeCashRegister(
    String accessToken,
    String registerId,
    Map<String, dynamic> closePayload,
  ) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.cashRegisterCloseUrl(registerId)),
          headers: _authorizedHeaders(accessToken, json: true),
          body: jsonEncode(closePayload),
        )
        .timeout(const Duration(seconds: 20));
    final payload = _requireObject(response, 'cash register reconciliation');
    return CashRegisterSummary.fromJson(_map(payload['summary']));
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

  Future<Map<String, dynamic>> offlineBootstrap({
    required String accessToken,
    required String locationId,
    required String cashRegisterId,
    String? contextId,
    int productCursor = 0,
    int customerCursor = 0,
  }) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.offlineBootstrapUrl),
          headers: {
            ..._authorizedHeaders(accessToken, json: true),
            if (contextId != null) 'X-Offline-Context': contextId,
          },
          body: jsonEncode({
            if (contextId == null) ...{
              'location_id': int.parse(locationId),
              'cash_register_id': int.parse(cashRegisterId),
            } else ...{
              'context_id': contextId,
              'product_cursor': productCursor,
              'customer_cursor': customerCursor,
            },
          }),
        )
        .timeout(const Duration(seconds: 30));
    return _map(_requireObject(response, 'offline POS bootstrap')['data']);
  }

  Future<Map<String, dynamic>> syncOfflineSales({
    required String accessToken,
    required String contextId,
    required List<Map<String, dynamic>> batch,
  }) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.offlineSalesSyncUrl),
          headers: {
            ..._authorizedHeaders(accessToken, json: true),
            'X-Offline-Context': contextId,
          },
          body: jsonEncode({'context_id': contextId, 'batch': batch}),
        )
        .timeout(const Duration(seconds: 30));
    return _requireObject(response, 'offline POS synchronization');
  }

  Future<Map<String, dynamic>> offlineChanges({
    required String accessToken,
    required String contextId,
    required int cursor,
    int limit = 500,
  }) async {
    final uri = Uri.parse(ApiEndPoints.offlineChangesUrl).replace(
      queryParameters: {
        'context_id': contextId,
        'cursor': '$cursor',
        'limit': '$limit',
      },
    );
    final response = await _client
        .get(
          uri,
          headers: {
            ..._authorizedHeaders(accessToken),
            'X-Offline-Context': contextId,
          },
        )
        .timeout(const Duration(seconds: 30));
    return _map(_requireObject(response, 'offline POS changes')['data']);
  }

  Future<List<LookupOption>> units(String accessToken) =>
      _lookupOptions(ApiEndPoints.unitsUrl, accessToken, 'units');

  Future<LookupOption> createUnit({
    required String accessToken,
    required String name,
    required String shortName,
    required bool allowDecimal,
  }) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.unitsUrl),
          headers: {
            ..._authorizedHeaders(accessToken),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'actual_name': name,
            'short_name': shortName,
            'allow_decimal': allowDecimal,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final payload = _decode(response.body);
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw ApiException(_message(payload) ?? 'Unable to create unit.');
    }
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid unit response.');
    }
    return LookupOption(
      id: data['id'].toString(),
      name: data['actual_name']?.toString() ?? name,
    );
  }

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
      name: item['name_en']?.toString().trim().isNotEmpty == true
          ? item['name_en'].toString()
          : item['name']?.toString() ?? '',
      nameEn: item['name_en']?.toString() ?? '',
      nameAr: item['name_ar']?.toString() ?? '',
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

  Future<void> createCategory({
    required String accessToken,
    required String name,
    String nameAr = '',
    String? parentId,
  }) => _catalogMutation(
    method: 'POST',
    url: ApiEndPoints.categoriesUrl,
    accessToken: accessToken,
    body: {
      'name': name,
      'name_en': name,
      if (nameAr.isNotEmpty) 'name_ar': nameAr,
      'parent_id': parentId ?? 0,
    },
  );

  Future<void> updateCategory({
    required String accessToken,
    required String id,
    required String name,
    String nameAr = '',
  }) => _catalogMutation(
    method: 'PUT',
    url: ApiEndPoints.categoryUrl(id),
    accessToken: accessToken,
    body: {
      'name': name,
      'name_en': name,
      if (nameAr.isNotEmpty) 'name_ar': nameAr,
    },
  );

  Future<void> deleteCategory({
    required String accessToken,
    required String id,
    String? replacementId,
  }) => _catalogMutation(
    method: 'DELETE',
    url: ApiEndPoints.categoryUrl(id),
    accessToken: accessToken,
    body: {if (replacementId != null) 'replacement_id': replacementId},
  );

  Future<bool> checkSku({
    required String accessToken,
    required String sku,
    String? excludeProductId,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiEndPoints.productSkuCheckUrl),
      headers: _jsonHeaders(accessToken),
      body: jsonEncode({
        'sku': sku,
        if (excludeProductId != null) 'exclude_product_id': excludeProductId,
      }),
    );
    final payload = _requireObject(response, 'SKU availability');
    return payload['available'] == true;
  }

  Future<void> deleteProduct(String accessToken, String id) => _catalogMutation(
    method: 'DELETE',
    url: ApiEndPoints.productUrl(id),
    accessToken: accessToken,
  );

  Future<Product> updateProductStatus({
    required String accessToken,
    required Product product,
    required bool active,
  }) async {
    final response = await _client.patch(
      Uri.parse(ApiEndPoints.productStatusUrl(product.id)),
      headers: _jsonHeaders(accessToken),
      body: jsonEncode({'status': active ? 'active' : 'inactive'}),
    );
    _requireObject(response, 'product status');
    return product.copyWith(active: active);
  }

  Future<Product> removeProductImage({
    required String accessToken,
    required Product product,
  }) async {
    await _catalogMutation(
      method: 'DELETE',
      url: ApiEndPoints.productImageUrl(product.id),
      accessToken: accessToken,
    );
    return product.copyWith(imageUrl: '');
  }

  Future<void> _catalogMutation({
    required String method,
    required String url,
    required String accessToken,
    Map<String, Object?> body = const {},
  }) async {
    final request = http.Request(method, Uri.parse(url));
    request.headers.addAll(_jsonHeaders(accessToken));
    if (body.isNotEmpty) request.body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    _requireObject(response, 'catalog operation');
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

  Future<Supplier> createSupplier({
    required String accessToken,
    required String businessName,
    required String contactName,
    required String mobile,
    String email = '',
    String address = '',
    int? payTermNumber,
    String payTermType = 'days',
  }) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.customersUrl),
          headers: _jsonHeaders(accessToken),
          body: jsonEncode({
            'type': 'supplier',
            'supplier_business_name': businessName.trim(),
            'first_name': contactName.trim(),
            'mobile': mobile.trim(),
            if (email.trim().isNotEmpty) 'email': email.trim(),
            if (address.trim().isNotEmpty) 'address_line_1': address.trim(),
            if (payTermNumber != null) 'pay_term_number': payTermNumber,
            if (payTermNumber != null) 'pay_term_type': payTermType,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final payload = _requireObject(response, 'supplier');
    final item = _map(payload['data']);
    return Supplier(
      id: item['id'].toString(),
      name: item['supplier_business_name']?.toString() ?? businessName.trim(),
    );
  }

  Future<List<LookupOption>> paymentAccounts(String accessToken) async {
    final data = await _getDataList(
      Uri.parse(ApiEndPoints.paymentAccountsUrl),
      accessToken,
      'payment accounts',
    );
    return data
        .map(
          (item) => LookupOption(
            id: item['id'].toString(),
            name: item['name']?.toString() ?? 'Account',
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
                  type == PurchaseDocumentType.purchaseReturn
                      ? line['quantity_returned'] ??
                            line['quantity'] ??
                            line['qty']
                      : line['quantity'] ?? line['qty'],
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
    final expenses = <PurchaseExpense>[
      for (var i = 1; i <= 4; i++)
        if ((json['additional_expense_key_$i'] ?? '').toString().isNotEmpty ||
            _number(json['additional_expense_value_$i']) > 0)
          PurchaseExpense(
            name: (json['additional_expense_key_$i'] ?? '').toString(),
            amount: _number(json['additional_expense_value_$i']),
          ),
    ];
    final rawPayments = json['payments'];
    final payments = rawPayments is List
        ? rawPayments
              .whereType<Map>()
              .map((raw) {
                final payment = Map<String, dynamic>.from(raw);
                return PurchasePaymentDraft(
                  amount: _number(payment['amount']),
                  method: payment['method']?.toString() ?? 'cash',
                  paidOn:
                      DateTime.tryParse(payment['paid_on']?.toString() ?? '') ??
                      DateTime.now(),
                  accountId: payment['account_id']?.toString(),
                  note: payment['note']?.toString() ?? '',
                );
              })
              .toList(growable: false)
        : const <PurchasePaymentDraft>[];
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
      exchangeRate: _number(json['exchange_rate']) > 0
          ? _number(json['exchange_rate'])
          : 1,
      discountType: json['discount_type']?.toString() ?? 'fixed',
      discountAmount: _number(json['discount_amount']),
      taxId: json['tax_id']?.toString(),
      shippingDetails: json['shipping_details']?.toString() ?? '',
      shippingCharges: _number(json['shipping_charges']),
      deliveryDate: DateTime.tryParse(json['delivery_date']?.toString() ?? ''),
      payTermNumber: int.tryParse(json['pay_term_number']?.toString() ?? ''),
      payTermType: json['pay_term_type']?.toString() ?? 'days',
      expenses: expenses,
      payments: payments,
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

  Future<SubscriptionSummary> activeSubscription(String accessToken) async {
    final subscription = await _getDataObject(
      Uri.parse(ApiEndPoints.activeSubscriptionUrl),
      accessToken,
      'active subscription',
    );
    final details = _map(subscription['package_details']);
    final name = details['name']?.toString().trim() ?? 'Current plan';
    final normalized = name.toLowerCase();
    final tier = normalized.contains('lite')
        ? SubscriptionTier.lite
        : normalized.contains('basic')
        ? SubscriptionTier.basic
        : normalized.contains('standard')
        ? SubscriptionTier.standard
        : normalized.contains('advance')
        ? SubscriptionTier.advance
        : SubscriptionTier.unknown;
    final includedUsers = switch (tier) {
      SubscriptionTier.lite || SubscriptionTier.basic => 1,
      SubscriptionTier.standard => 3,
      SubscriptionTier.advance => 5,
      SubscriptionTier.unknown => _number(details['user_count']).floor(),
    };
    final configuredLimit = _number(details['user_count']).floor();
    final userLimit = tier == SubscriptionTier.lite
        ? 1
        : configuredLimit > 0
        ? configuredLimit
        : includedUsers;
    final users = await _getDataList(
      Uri.parse(ApiEndPoints.usersUrl),
      accessToken,
      'users',
    );
    final activeUsers = users.where((user) {
      final login = user['allow_login'];
      final status = user['status']?.toString().toLowerCase();
      return (login == true || login == 1 || login?.toString() == '1') &&
          status != 'inactive' &&
          status != 'terminated';
    }).length;
    return SubscriptionSummary(
      name: name,
      tier: tier,
      includedUsers: includedUsers,
      userLimit: userLimit,
      activeUsers: activeUsers,
      endDate: DateTime.tryParse(subscription['end_date']?.toString() ?? ''),
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

  Future<Map<String, dynamic>> report(
    String accessToken,
    String report,
    Map<String, String> parameters,
  ) async {
    final uri = Uri.parse(
      ApiEndPoints.reportUrl(report),
    ).replace(queryParameters: parameters);
    final response = await _client
        .get(uri, headers: _authorizedHeaders(accessToken))
        .timeout(const Duration(seconds: 30));
    return _requireObject(response, '$report report');
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

  Future<List<SaleReturnRecord>> saleReturns(String accessToken) async {
    final uri = Uri.parse(
      ApiEndPoints.saleReturnsListUrl,
    ).replace(queryParameters: const {'per_page': '-1'});
    final data = await _getDataList(uri, accessToken, 'sale returns');
    return data
        .map((item) {
          final parent = _map(item['return_parent_sell']);
          final contact = _map(item['contact']);
          final parentContact = _map(parent['contact']);
          final payments = item['payment_lines'] as List? ?? const [];
          final payment = payments
              .whereType<Map<String, dynamic>>()
              .firstOrNull;
          return SaleReturnRecord(
            id: item['id']?.toString() ?? '',
            invoiceNo: item['invoice_no']?.toString() ?? '',
            parentSaleId:
                item['return_parent_id']?.toString() ??
                parent['id']?.toString() ??
                '',
            parentInvoiceNo: parent['invoice_no']?.toString() ?? '',
            createdAt:
                DateTime.tryParse(item['transaction_date']?.toString() ?? '') ??
                DateTime.now(),
            customerName:
                contact['name']?.toString() ??
                parentContact['name']?.toString() ??
                'Walk-In Customer',
            total: _money(item['final_total']).abs(),
            paymentStatus: item['payment_status']?.toString() ?? 'due',
            paymentMethod: payment?['method']?.toString() ?? 'due',
          );
        })
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createSale({
    required String accessToken,
    required String locationId,
    required String cashRegisterId,
    required Customer customer,
    required List<CartLine> lines,
    required String paymentMethod,
    required int total,
    required int grossDiscount,
  }) async {
    final body = {
      'sells': [
        {
          'location_id': int.parse(locationId),
          'cash_register_id': int.parse(cashRegisterId),
          'contact_id': int.parse(customer.id),
          'status': 'final',
          'discount_type': 'fixed',
          'discount_amount': grossDiscount / 100,
          'products': [
            for (final line in lines)
              {
                'product_id': int.parse(line.product.id),
                'variation_id': int.parse(line.product.variationId),
                'quantity': line.quantity,
                'unit_price': line.unitPrice / 100,
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

  Future<Map<String, dynamic>> createSaleReturn({
    required String accessToken,
    required Sale sale,
    required Map<String, int> quantities,
  }) async {
    if (sale.serverId == null || sale.serverId!.isEmpty) {
      throw const ApiException('This sale has not been synchronized yet.');
    }
    final products = <Map<String, dynamic>>[];
    for (final line in sale.items) {
      final quantity = quantities[line.sellLineId];
      if (line.sellLineId == null || quantity == null || quantity <= 0) {
        continue;
      }
      if (quantity > line.returnableQuantity) {
        throw ApiException(
          'Return quantity exceeds the available quantity for ${line.product.name}.',
        );
      }
      products.add({
        'sell_line_id': int.parse(line.sellLineId!),
        'quantity': quantity,
        'unit_price_inc_tax': line.product.sellingPrice / 100,
      });
    }
    if (products.isEmpty) {
      throw const ApiException('Select at least one item to return.');
    }
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final body = {
      'transaction_id': int.parse(sale.serverId!),
      'transaction_date':
          '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
      'discount_type': 'fixed',
      'discount_amount': 0,
      'products': products,
    };
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.saleReturnsUrl),
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
        _apiMessage(decoded, 'Unable to create the sale return.'),
        statusCode: response.statusCode,
        validationErrors: decoded is Map ? _map(decoded['errors']) : const {},
      );
    }
    if (decoded is! Map) {
      throw const ApiException('Invalid sale-return response.');
    }
    final result = Map<String, dynamic>.from(decoded);
    if (result['error'] != null || result['success'] == false) {
      throw ApiException(
        _apiMessage(result, 'Unable to create the sale return.'),
      );
    }
    return result;
  }

  Future<ZatcaIntegrationStatus> zatcaStatus(String accessToken) async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.zatcaStatusUrl),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    final root = _requireObject(response, 'ZATCA status');
    final data = _map(root['data']);
    final totals = _map(data['totals']);
    final rawLocations = data['locations'];
    return ZatcaIntegrationStatus(
      installed: data['installed'] == true || data['installed'] == 1,
      subscriptionEnabled:
          data['subscription_enabled'] == true ||
          data['subscription_enabled'] == 1,
      syncFrequency: data['sync_frequency']?.toString() ?? 'disable',
      version: data['version']?.toString(),
      locations: rawLocations is List
          ? rawLocations
                .whereType<Map>()
                .map((raw) {
                  final item = Map<String, dynamic>.from(raw);
                  return ZatcaLocationStatus(
                    id: item['id'].toString(),
                    name: item['name']?.toString() ?? 'Location',
                    configured:
                        item['configured'] == true || item['configured'] == 1,
                    portalMode: item['portal_mode']?.toString(),
                    syncFrom: item['sync_from_datetime']?.toString(),
                  );
                })
                .toList(growable: false)
          : const [],
      totals: ZatcaTotals(
        pending: _number(totals['pending']).round(),
        success: _number(totals['success']).round(),
        failed: _number(totals['failed']).round(),
      ),
    );
  }

  Future<ZatcaLocationStatus> onboardZatca({
    required String accessToken,
    required String locationId,
    required ZatcaOnboardingDraft draft,
  }) async {
    final response = await _client
        .post(
          Uri.parse(ApiEndPoints.zatcaOnboardingUrl(locationId)),
          headers: _jsonHeaders(accessToken),
          body: jsonEncode(draft.toJson()),
        )
        .timeout(const Duration(seconds: 60));
    final root = _requireObject(response, 'ZATCA device onboarding');
    final data = _map(root['data']);
    return ZatcaLocationStatus(
      id: data['location_id']?.toString() ?? locationId,
      name: data['name']?.toString() ?? 'Location',
      configured: data['configured'] == true || data['configured'] == 1,
      portalMode: data['portal_mode']?.toString(),
      syncFrom: data['sync_from_datetime']?.toString(),
    );
  }

  Future<ZatcaInvoiceStatus> zatcaInvoiceStatus(
    String accessToken,
    String saleId,
  ) async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.zatcaInvoiceUrl(saleId)),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    final root = _requireObject(response, 'ZATCA invoice status');
    final data = _map(root['data']);
    return ZatcaInvoiceStatus(
      saleId: data['sale_id']?.toString() ?? saleId,
      invoiceNo: data['invoice_no']?.toString() ?? '',
      status: data['zatca_status']?.toString() ?? 'pending',
      document: _zatcaDocument(data['document']),
    );
  }

  Future<ZatcaOperationResult> syncZatcaInvoice(
    String accessToken,
    String saleId,
  ) => _syncZatca(accessToken, ApiEndPoints.zatcaInvoiceSyncUrl(saleId));

  Future<ZatcaOperationResult> syncZatcaReturn(
    String accessToken,
    String returnId,
  ) => _syncZatca(accessToken, ApiEndPoints.zatcaReturnSyncUrl(returnId));

  Future<ZatcaOperationResult> _syncZatca(
    String accessToken,
    String url,
  ) async {
    final response = await _client
        .post(Uri.parse(url), headers: _jsonHeaders(accessToken))
        .timeout(const Duration(seconds: 60));
    final decoded = _decodeAny(response.body);
    if (decoded is! Map)
      throw const ApiException('Invalid ZATCA sync response.');
    final root = Map<String, dynamic>.from(decoded);
    if ((response.statusCode < 200 || response.statusCode >= 300) &&
        response.statusCode != 409) {
      throw ApiException(
        _apiMessage(root, 'Unable to sync with ZATCA.'),
        statusCode: response.statusCode,
      );
    }
    final data = _map(root['data']);
    return ZatcaOperationResult(
      success: root['success'] == true || root['success'] == 1,
      message: root['message']?.toString() ?? 'ZATCA sync completed.',
      status: data['zatca_status']?.toString() ?? 'pending',
    );
  }

  Future<ZatcaQrPayload> zatcaQr(String accessToken, String saleId) async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.zatcaInvoiceQrUrl(saleId)),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    final root = _requireObject(response, 'ZATCA QR');
    final data = _map(root['data']);
    return ZatcaQrPayload(
      saleId: data['sale_id']?.toString() ?? saleId,
      value: data['qr_value']?.toString() ?? '',
      format: data['format']?.toString() ?? 'base64_tlv',
    );
  }

  Future<ZatcaDownload> downloadZatcaXml(String accessToken, String saleId) =>
      _zatcaDownload(
        accessToken,
        ApiEndPoints.zatcaInvoiceXmlUrl(saleId),
        'zatca-$saleId.xml',
      );

  Future<ZatcaDownload> downloadZatcaPdf(String accessToken, String saleId) =>
      _zatcaDownload(
        accessToken,
        ApiEndPoints.zatcaInvoicePdfUrl(saleId),
        'zatca-$saleId.pdf',
      );

  Future<ZatcaPage> zatcaInvoices(String accessToken, ZatcaListFilter filter) =>
      _zatcaTransactions(accessToken, ApiEndPoints.zatcaInvoicesUrl, filter);

  Future<ZatcaPage> zatcaReturns(String accessToken, ZatcaListFilter filter) =>
      _zatcaTransactions(accessToken, ApiEndPoints.zatcaReturnsUrl, filter);

  Future<ZatcaPage> _zatcaTransactions(
    String accessToken,
    String url,
    ZatcaListFilter filter,
  ) async {
    final response = await _client
        .get(
          Uri.parse(url).replace(queryParameters: filter.toQuery()),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 30));
    final root = _requireObject(response, 'ZATCA transactions');
    final meta = _map(root['meta']);
    final raw = root['data'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map((entry) {
                final item = Map<String, dynamic>.from(entry);
                final customer = _map(item['customer']);
                return ZatcaTransaction(
                  id: item['id']?.toString() ?? '',
                  invoiceNo: item['invoice_no']?.toString() ?? '',
                  status: item['zatca_status']?.toString() ?? 'pending',
                  transactionDate: item['transaction_date']?.toString() ?? '',
                  total: _number(item['final_total']),
                  locationId: item['location_id']?.toString(),
                  locationName: item['location_name']?.toString(),
                  customerName: customer['name']?.toString(),
                  customerMobile: customer['mobile']?.toString(),
                  parentSaleId: item['parent_sale_id']?.toString(),
                  parentInvoiceNo: item['parent_invoice_no']?.toString(),
                  document: _zatcaDocument(item['document']),
                );
              })
              .toList(growable: false)
        : const <ZatcaTransaction>[];
    return ZatcaPage(
      items: items,
      currentPage: _number(meta['current_page']).round().clamp(1, 999999),
      lastPage: _number(meta['last_page']).round().clamp(1, 999999),
      perPage: _number(meta['per_page']).round(),
      total: _number(meta['total']).round(),
    );
  }

  Future<ZatcaInvoiceStatus> zatcaReturnStatus(
    String accessToken,
    String returnId,
  ) async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.zatcaReturnUrl(returnId)),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    final data = _map(_requireObject(response, 'ZATCA return status')['data']);
    return ZatcaInvoiceStatus(
      saleId: data['return_id']?.toString() ?? returnId,
      invoiceNo: data['invoice_no']?.toString() ?? '',
      status: data['zatca_status']?.toString() ?? 'pending',
      document: _zatcaDocument(data['document']),
    );
  }

  Future<ZatcaBulkResult> syncZatcaInvoicesBulk(
    String accessToken,
    List<String> ids,
  ) => _syncZatcaBulk(accessToken, ApiEndPoints.zatcaInvoicesBulkSyncUrl, ids);

  Future<ZatcaBulkResult> syncZatcaReturnsBulk(
    String accessToken,
    List<String> ids,
  ) => _syncZatcaBulk(accessToken, ApiEndPoints.zatcaReturnsBulkSyncUrl, ids);

  Future<ZatcaBulkResult> _syncZatcaBulk(
    String accessToken,
    String url,
    List<String> ids,
  ) async {
    final response = await _client
        .post(
          Uri.parse(url),
          headers: _jsonHeaders(accessToken),
          body: jsonEncode({'invoice_ids': ids.map(int.parse).toList()}),
        )
        .timeout(const Duration(seconds: 120));
    final root = _requireObject(response, 'ZATCA bulk sync');
    final summary = _map(root['summary']);
    final raw = root['data'];
    return ZatcaBulkResult(
      requested: _number(summary['requested']).round(),
      successful: _number(summary['successful']).round(),
      failed: _number(summary['failed']).round(),
      results: raw is List
          ? raw
                .whereType<Map>()
                .map((entry) {
                  final item = Map<String, dynamic>.from(entry);
                  return ZatcaOperationResult(
                    success: item['success'] == true || item['success'] == 1,
                    message: item['message']?.toString() ?? 'Sync completed.',
                    status: item['zatca_status']?.toString() ?? 'pending',
                  );
                })
                .toList(growable: false)
          : const [],
    );
  }

  Future<ZatcaQrPayload> zatcaReturnQr(String accessToken, String returnId) =>
      _zatcaQrAt(
        accessToken,
        ApiEndPoints.zatcaReturnQrUrl(returnId),
        returnId,
      );

  Future<ZatcaQrPayload> _zatcaQrAt(
    String accessToken,
    String url,
    String id,
  ) async {
    final response = await _client
        .get(Uri.parse(url), headers: _authorizedHeaders(accessToken))
        .timeout(const Duration(seconds: 20));
    final data = _map(_requireObject(response, 'ZATCA QR')['data']);
    return ZatcaQrPayload(
      saleId:
          data['return_id']?.toString() ?? data['sale_id']?.toString() ?? id,
      value: data['qr_value']?.toString() ?? '',
      format: data['format']?.toString() ?? 'base64_tlv',
    );
  }

  Future<ZatcaDownload> downloadZatcaReturnXml(
    String accessToken,
    String returnId,
  ) => _zatcaDownload(
    accessToken,
    ApiEndPoints.zatcaReturnXmlUrl(returnId),
    'zatca-return-$returnId.xml',
  );

  Future<ZatcaDownload> downloadZatcaReturnPdf(
    String accessToken,
    String returnId,
  ) => _zatcaDownload(
    accessToken,
    ApiEndPoints.zatcaReturnPdfUrl(returnId),
    'zatca-return-$returnId.pdf',
  );

  Future<ZatcaSettings> zatcaSettings(String accessToken) async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.zatcaSettingsUrl),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    return _zatcaSettings(
      _map(_requireObject(response, 'ZATCA settings')['data']),
    );
  }

  Future<ZatcaSettings> updateZatcaSettings(
    String accessToken,
    Map<String, dynamic> changes,
  ) async {
    final response = await _client
        .patch(
          Uri.parse(ApiEndPoints.zatcaSettingsUrl),
          headers: _jsonHeaders(accessToken),
          body: jsonEncode(changes),
        )
        .timeout(const Duration(seconds: 30));
    return _zatcaSettings(
      _map(_requireObject(response, 'ZATCA settings update')['data']),
    );
  }

  ZatcaSettings _zatcaSettings(Map<String, dynamic> data) {
    final raw = data['locations'];
    return ZatcaSettings(
      syncFrequency: data['sync_frequency']?.toString() ?? 'disable',
      disableDiscount:
          data['disable_discount'] == true || data['disable_discount'] == 1,
      disableOrderTax:
          data['disable_order_tax'] == true || data['disable_order_tax'] == 1,
      defaultSalesDiscount: _number(data['default_sales_discount']),
      locations: raw is List
          ? raw
                .whereType<Map>()
                .map((entry) {
                  final item = Map<String, dynamic>.from(entry);
                  return ZatcaSettingLocation(
                    id: item['location_id']?.toString() ?? '',
                    name: item['location_name']?.toString() ?? 'Location',
                    syncFrom: item['sync_from_datetime']?.toString(),
                  );
                })
                .toList(growable: false)
          : const [],
    );
  }

  Future<ZatcaSyncSummary> zatcaSyncSummary(String accessToken) async {
    final response = await _client
        .get(
          Uri.parse(ApiEndPoints.zatcaSyncSummaryUrl),
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 20));
    final data = _map(_requireObject(response, 'ZATCA sync summary')['data']);
    return ZatcaSyncSummary(
      totalInvoices: _number(data['total_invoices']).round(),
      pending: _number(data['pending_not_synced']).round(),
      successful: _number(data['successful']).round(),
      failed: _number(data['failed']).round(),
      developerSynced: _number(data['developer_synced']).round(),
      simulationSynced: _number(data['simulation_synced']).round(),
    );
  }

  Future<ZatcaDownload> _zatcaDownload(
    String accessToken,
    String url,
    String fallbackName,
  ) async {
    final response = await _client
        .get(Uri.parse(url), headers: _authorizedHeaders(accessToken))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _apiMessage(
          _decodeAny(response.body),
          'Unable to download ZATCA document.',
        ),
        statusCode: response.statusCode,
      );
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp('filename="?([^";]+)').firstMatch(disposition);
    return ZatcaDownload(
      bytes: response.bodyBytes,
      fileName: match?.group(1) ?? fallbackName,
    );
  }

  ZatcaDocumentInfo? _zatcaDocument(dynamic raw) {
    final item = _map(raw);
    if (item.isEmpty) return null;
    return ZatcaDocumentInfo(
      id: item['id']?.toString() ?? '',
      status: item['status']?.toString() ?? 'pending',
      sentToZatca: item['sent_to_zatca'] == true || item['sent_to_zatca'] == 1,
      icv: item['icv']?.toString(),
      uuid: item['uuid']?.toString(),
      portalMode: item['portal_mode']?.toString(),
      signingTime: item['signing_time']?.toString(),
    );
  }

  Future<Customer> createCustomer({
    required String accessToken,
    required String name,
    required String mobile,
    String email = '',
    String taxNumber = '',
    String businessName = '',
    String commercialRegistrationNumber = '',
    String addressLine1 = '',
    String addressLine2 = '',
    String city = '',
    String state = '',
    String country = '',
    String zipCode = '',
    String contactId = '',
    String prefix = '',
    String middleName = '',
    String lastName = '',
    String alternateNumber = '',
    String landline = '',
    String dateOfBirth = '',
    String customerGroupId = '',
    String payTermNumber = '',
    String payTermType = 'days',
    String shippingAddress = '',
    String position = '',
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
            if (contactId.isNotEmpty) 'contact_id': contactId,
            if (prefix.isNotEmpty) 'prefix': prefix,
            if (middleName.isNotEmpty) 'middle_name': middleName,
            if (lastName.isNotEmpty) 'last_name': lastName,
            if (alternateNumber.isNotEmpty) 'alternate_number': alternateNumber,
            if (landline.isNotEmpty) 'landline': landline,
            if (dateOfBirth.isNotEmpty) 'dob': dateOfBirth,
            if (customerGroupId.isNotEmpty)
              'customer_group_id': customerGroupId,
            if (payTermNumber.isNotEmpty) 'pay_term_number': payTermNumber,
            if (payTermNumber.isNotEmpty) 'pay_term_type': payTermType,
            if (shippingAddress.isNotEmpty) 'shipping_address': shippingAddress,
            if (position.isNotEmpty) 'position': position,
            if (email.isNotEmpty) 'email': email,
            if (taxNumber.isNotEmpty) 'tax_number': taxNumber,
            if (businessName.isNotEmpty) 'supplier_business_name': businessName,
            if (commercialRegistrationNumber.isNotEmpty)
              'commercial_registration_number': commercialRegistrationNumber,
            if (addressLine1.isNotEmpty) 'address_line_1': addressLine1,
            if (addressLine2.isNotEmpty) 'address_line_2': addressLine2,
            if (city.isNotEmpty) 'city': city,
            if (state.isNotEmpty) 'state': state,
            if (country.isNotEmpty) 'country': country,
            if (zipCode.isNotEmpty) 'zip_code': zipCode,
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
    String businessName = '',
    String commercialRegistrationNumber = '',
    String addressLine1 = '',
    String addressLine2 = '',
    String city = '',
    String state = '',
    String country = '',
    String zipCode = '',
    String contactId = '',
    String prefix = '',
    String middleName = '',
    String lastName = '',
    String alternateNumber = '',
    String landline = '',
    String dateOfBirth = '',
    String customerGroupId = '',
    String payTermNumber = '',
    String payTermType = 'days',
    String shippingAddress = '',
    String position = '',
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
            'contact_id': contactId,
            'prefix': prefix,
            'middle_name': middleName,
            'last_name': lastName,
            'alternate_number': alternateNumber,
            'landline': landline,
            'dob': dateOfBirth,
            'customer_group_id': customerGroupId,
            'pay_term_number': payTermNumber,
            'pay_term_type': payTermType,
            'shipping_address': shippingAddress,
            'position': position,
            'email': email,
            'tax_number': taxNumber,
            'supplier_business_name': businessName,
            'commercial_registration_number': commercialRegistrationNumber,
            'address_line_1': addressLine1,
            'address_line_2': addressLine2,
            'city': city,
            'state': state,
            'country': country,
            'zip_code': zipCode,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final payload = _requireObject(response, 'customer');
    return _customerFromJson(_map(payload['data']));
  }

  Map<String, String> _authorizedHeaders(
    String accessToken, {
    bool json = false,
  }) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $accessToken',
    if (json) 'Content-Type': 'application/json',
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
    businessName: json['supplier_business_name']?.toString() ?? '',
    commercialRegistrationNumber:
        json['commercial_registration_number']?.toString() ?? '',
    addressLine1: json['address_line_1']?.toString() ?? '',
    addressLine2: json['address_line_2']?.toString() ?? '',
    city: json['city']?.toString() ?? '',
    state: json['state']?.toString() ?? '',
    country: json['country']?.toString() ?? '',
    zipCode: json['zip_code']?.toString() ?? '',
    contactId: json['contact_id']?.toString() ?? '',
    prefix: json['prefix']?.toString() ?? '',
    middleName: json['middle_name']?.toString() ?? '',
    lastName: json['last_name']?.toString() ?? '',
    alternateNumber: json['alternate_number']?.toString() ?? '',
    landline: json['landline']?.toString() ?? '',
    dateOfBirth: json['dob']?.toString() ?? '',
    customerGroupId: json['customer_group_id']?.toString() ?? '',
    payTermNumber: json['pay_term_number']?.toString() ?? '',
    payTermType: json['pay_term_type']?.toString() ?? 'days',
    shippingAddress: json['shipping_address']?.toString() ?? '',
    position: json['position']?.toString() ?? '',
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
            sellLineId: line['id']?.toString(),
            quantityReturned: _number(line['quantity_returned']).round(),
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
