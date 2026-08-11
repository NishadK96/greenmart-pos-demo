import 'config.dart';

abstract final class ApiEndPoints {
  static const loginUrl = '${Config.baseUrl}/oauth/token';
  static const productsUrl = '${Config.baseUrl}/connector/api/product';
  static const categoriesUrl = '${Config.baseUrl}/connector/api/taxonomy';
}
