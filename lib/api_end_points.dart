import 'config.dart';

abstract final class ApiEndPoints {
  static const loginUrl = '${Config.baseUrl}/connector/api/login';
  static const productsUrl = '${Config.baseUrl}/connector/api/product';
  static const productWritesUrl = '${Config.baseUrl}/connector/api/products';
  static const quickProductUrl =
      '${Config.baseUrl}/connector/api/products/save_quick_product';
  static const bulkProductsUrl =
      '${Config.baseUrl}/connector/api/products/bulk-update';
  static const importProductsUrl =
      '${Config.baseUrl}/connector/api/import-products/store';
  static const unitsUrl = '${Config.baseUrl}/connector/api/unit';
  static const taxesUrl = '${Config.baseUrl}/connector/api/tax';
  static const brandsUrl = '${Config.baseUrl}/connector/api/brand';
  static const categoriesUrl = '${Config.baseUrl}/connector/api/taxonomy';
  static String categoryUrl(String id) => '$categoriesUrl/$id';
  static String productUrl(String id) => '$productWritesUrl/$id';
  static String productStatusUrl(String id) => '$productWritesUrl/$id/status';
  static String productImageUrl(String id) => '$productWritesUrl/$id/image';
  static const productSkuCheckUrl = '$productWritesUrl/check-sku';
  static const customersUrl = '${Config.baseUrl}/connector/api/contactapi';
  static const salesUrl = '${Config.baseUrl}/connector/api/sell';
  static const locationsUrl =
      '${Config.baseUrl}/connector/api/business-location';
  static const paymentMethodsUrl =
      '${Config.baseUrl}/connector/api/payment-methods';
  static const paymentAccountsUrl =
      '${Config.baseUrl}/connector/api/payment-accounts';
  static const businessDetailsUrl =
      '${Config.baseUrl}/connector/api/business-details';
  static const loggedInUserUrl =
      '${Config.baseUrl}/connector/api/user/loggedin';
  static const profitLossUrl =
      '${Config.baseUrl}/connector/api/profit-loss-report';
  static const stockReportUrl =
      '${Config.baseUrl}/connector/api/product-stock-report';
  static const purchaseOrdersUrl =
      '${Config.baseUrl}/connector/api/purchase-orders';
  static const purchasesUrl = '${Config.baseUrl}/connector/api/purchases';
  static const purchaseReturnsUrl =
      '${Config.baseUrl}/connector/api/purchase-returns';
}
