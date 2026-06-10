import '../../core/network/api.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';

/// ⭐ Recommendation & likes — `/api/recommendation/`
class RecommendationService {
  RecommendationService._();

  static Object _uid([Object? userId]) => userId ?? AuthSession.userId!;

  /// 추천 알고리즘 실행.
  static Future<dynamic> generate([Object? userId]) =>
      ApiClient.I.post(RecommendationApi.generate,
          body: {'user_id': _uid(userId)});

  /// 유저 추천 결과 조회.
  static Future<dynamic> forUser([Object? userId]) =>
      ApiClient.I.get(RecommendationApi.user(_uid(userId)));

  /// 추천 결과 저장.
  static Future<dynamic> save(Map<String, dynamic> body) =>
      ApiClient.I.post(RecommendationApi.save, body: body);

  /// 제품 찜 / 찜 취소 (토글).
  static Future<dynamic> toggleLike(Object productId, [Object? userId]) =>
      ApiClient.I.post(RecommendationApi.like,
          body: {'user_id': _uid(userId), 'product_id': productId});

  /// 찜 여부 확인.
  static Future<dynamic> likeStatus(Object productId, [Object? userId]) =>
      ApiClient.I.get(RecommendationApi.likeStatus(_uid(userId), productId));
}
