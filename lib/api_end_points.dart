import 'config.dart';

abstract final class ApiEndPoints {
  static const loginUrl = '${Config.baseUrl}/oauth/token';
  static const productsUrl = '${Config.baseUrl}/connector/api/product';
  static const categoriesUrl = '${Config.baseUrl}/connector/api/taxonomy';
  static const customersUrl = '${Config.baseUrl}/connector/api/contactapi';
  static const salesUrl = '${Config.baseUrl}/connector/api/sell';
  static const locationsUrl =
      '${Config.baseUrl}/connector/api/business-location';
  static const paymentMethodsUrl =
      '${Config.baseUrl}/connector/api/payment-methods';
  static const businessDetailsUrl =
      '${Config.baseUrl}/connector/api/business-details';
  static const loggedInUserUrl =
      '${Config.baseUrl}/connector/api/user/loggedin';
  static const profitLossUrl =
      '${Config.baseUrl}/connector/api/profit-loss-report';
  static const stockReportUrl =
      '${Config.baseUrl}/connector/api/product-stock-report';
}
