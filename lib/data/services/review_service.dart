import '../../core/network/api.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';

/// 📝 Reviews, feedback & search log — `/api/review/`
class ReviewService {
  ReviewService._();

  static Object _uid([Object? userId]) => userId ?? AuthSession.userId!;

  /// 리뷰 작성. `{ user_id, product_id, rating, review_text }`.
  static Future<dynamic> create({
    required Object productId,
    required int rating,
    required String content,
  }) =>
      ApiClient.I.post(ReviewApi.create, body: {
        'user_id': _uid(),
        'product_id': productId,
        'rating': rating,
        'review_text': content,
      });

  static Future<dynamic> update(
    Object reviewId, {
    required int rating,
    required String content,
  }) =>
      ApiClient.I.patch(ReviewApi.update(reviewId), body: {
        'user_id': _uid(),
        'rating': rating,
        'review_text': content,
      });

  static Future<dynamic> delete(Object reviewId) =>
      ApiClient.I.delete(ReviewApi.delete(reviewId), body: {'user_id': _uid()});

  static Future<dynamic> byProduct(Object productId) =>
      ApiClient.I.get(ReviewApi.byProduct(productId));

  static Future<dynamic> byUser([Object? userId]) =>
      ApiClient.I.get(ReviewApi.byUser(_uid(userId)));

  /// 만족도 / 부작용 피드백 등록.
  /// `{ user_id, product_id?, feedback_type, satisfaction_score?, side_effect_text? }`
  /// feedback_type: SATISFACTION | SIDE_EFFECT | INQUIRY
  static Future<dynamic> submitFeedback({
    required String feedbackType,
    Object? productId,
    int? satisfactionScore,
    String sideEffectText = '',
  }) =>
      ApiClient.I.post(ReviewApi.feedback, body: {
        'user_id': _uid(),
        'product_id': ?productId,
        'feedback_type': feedbackType,
        'satisfaction_score': ?satisfactionScore,
        'side_effect_text': sideEffectText,
      });

  static Future<dynamic> feedbackHistory([Object? userId]) =>
      ApiClient.I.get(ReviewApi.feedbackByUser(_uid(userId)));

  /// 검색어 로그 저장. `{ user_id, keyword, clicked_product_id? }`
  static Future<dynamic> logSearch(String keyword, {Object? clickedProductId}) =>
      ApiClient.I.post(ReviewApi.searchLog, body: {
        'user_id': _uid(),
        'keyword': keyword,
        'clicked_product_id': ?clickedProductId,
      });

  static Future<dynamic> searchHistory([Object? userId]) =>
      ApiClient.I.get(ReviewApi.searchHistory(_uid(userId)));

  /// 제품 조회 로그 저장. `{ user_id, product_id }`
  static Future<dynamic> logProductView(Object productId) =>
      ApiClient.I.post(ReviewApi.productView, body: {
        'user_id': _uid(),
        'product_id': productId,
      });

  /// 최근 본 제품 (중복제거 최대 20개).
  static Future<dynamic> recentlyViewed([Object? userId]) =>
      ApiClient.I.get(ReviewApi.recentlyViewed(_uid(userId)));

  /// 급상승 검색어 Top 10 (최근 7일 기준). 비로그인도 호출 가능.
  static Future<dynamic> trending() => ApiClient.I.get(ReviewApi.trending);
}
