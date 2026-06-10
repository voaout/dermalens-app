import '../../core/network/api.dart';
import '../../core/network/api_client.dart';

/// 🧴 Products & ingredients — `/api/products/`
class ProductService {
  ProductService._();

  static Future<dynamic> list({int page = 1}) =>
      ApiClient.I.get(ProductsApi.list, query: {'page': page});

  static Future<dynamic> search(String keyword) =>
      ApiClient.I.get(ProductsApi.search, query: {'q': keyword});

  static Future<dynamic> popular() => ApiClient.I.get(ProductsApi.popular);

  static Future<dynamic> detail(Object productId) =>
      ApiClient.I.get(ProductsApi.detail(productId));

  static Future<dynamic> ingredients(Object productId) =>
      ApiClient.I.get(ProductsApi.ingredients(productId));

  static Future<dynamic> categories() =>
      ApiClient.I.get(ProductsApi.categories);

  static Future<dynamic> categoryProducts(Object categoryId, {int page = 1}) =>
      ApiClient.I.get(ProductsApi.categoryProducts(categoryId),
          query: {'page': page});

  static Future<dynamic> ingredientList() =>
      ApiClient.I.get(ProductsApi.ingredientList);

  static Future<dynamic> ingredientSearch(String keyword) =>
      ApiClient.I.get(ProductsApi.ingredientSearch, query: {'q': keyword});

  static Future<dynamic> ingredientDetail(Object ingredientId) =>
      ApiClient.I.get(ProductsApi.ingredientDetail(ingredientId));
}
