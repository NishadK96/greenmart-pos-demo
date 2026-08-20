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
  static const saleReturnsUrl = '${Config.baseUrl}/connector/api/sell-return';
  static const saleReturnsListUrl =
      '${Config.baseUrl}/connector/api/list-sell-return';
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
  static const cashRegisterUrl =
      '${Config.baseUrl}/connector/api/cash-register';
  static const cashRegisterOpenUrl = '$cashRegisterUrl/open';
  static const cashRegisterCurrentUrl = '$cashRegisterUrl/current';
  static String cashRegisterCashInUrl(String id) =>
      '$cashRegisterUrl/$id/cash-in';
  static String cashRegisterCashOutUrl(String id) =>
      '$cashRegisterUrl/$id/cash-out';
  static String cashRegisterCloseUrl(String id) => '$cashRegisterUrl/$id/close';
  static String cashRegisterSummaryUrl(String id) =>
      '$cashRegisterUrl/$id/summary';
  static const zatcaStatusUrl = '${Config.baseUrl}/connector/api/zatca/status';
  static String zatcaOnboardingUrl(String locationId) =>
      '${Config.baseUrl}/connector/api/zatca/onboarding/$locationId';
  static String zatcaInvoiceUrl(String saleId) =>
      '${Config.baseUrl}/connector/api/zatca/invoices/$saleId';
  static const zatcaInvoicesUrl =
      '${Config.baseUrl}/connector/api/zatca/invoices';
  static const zatcaInvoicesBulkSyncUrl = '$zatcaInvoicesUrl/syncBulk';
  static const zatcaReturnsUrl =
      '${Config.baseUrl}/connector/api/zatca/returns';
  static const zatcaReturnsBulkSyncUrl = '$zatcaReturnsUrl/syncBulk';
  static String zatcaReturnUrl(String returnId) => '$zatcaReturnsUrl/$returnId';
  static String zatcaInvoiceSyncUrl(String saleId) =>
      '${zatcaInvoiceUrl(saleId)}/sync';
  static String zatcaReturnSyncUrl(String returnId) =>
      '${zatcaReturnUrl(returnId)}/sync';
  static String zatcaReturnQrUrl(String returnId) =>
      '${zatcaReturnUrl(returnId)}/qr';
  static String zatcaReturnXmlUrl(String returnId) =>
      '${zatcaReturnUrl(returnId)}/xml';
  static String zatcaReturnPdfUrl(String returnId) =>
      '${zatcaReturnUrl(returnId)}/pdf';
  static String zatcaInvoiceQrUrl(String saleId) =>
      '${zatcaInvoiceUrl(saleId)}/qr';
  static String zatcaInvoiceXmlUrl(String saleId) =>
      '${zatcaInvoiceUrl(saleId)}/xml';
  static String zatcaInvoicePdfUrl(String saleId) =>
      '${zatcaInvoiceUrl(saleId)}/pdf';
  static const zatcaSettingsUrl =
      '${Config.baseUrl}/connector/api/zatca/settings';
  static const zatcaSyncSummaryUrl =
      '${Config.baseUrl}/connector/api/zatca/sync-summary';
}
