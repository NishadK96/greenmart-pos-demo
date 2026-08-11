import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_end_points.dart';
import '../config.dart';
import '../shared/models/entities.dart';

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
    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => Category(
            id: item['id'].toString(),
            name: item['name']?.toString() ?? '',
            icon: '',
          ),
        )
        .toList(growable: false);
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
      unit: (json['unit'] is Map<String, dynamic>)
          ? (json['unit']['short_name']?.toString() ?? 'pc')
          : 'pc',
      active: json['is_inactive'] != 1,
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

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
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
