/// Centralized API / server address management.
///
/// All backend calls build their URL through these classes so the server
/// address lives in exactly one place. Override the base URL at build time:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://dermalens-production.up.railway.app
/// ```
///
/// The HTTP client itself (http / dio) is not wired here — add it when
/// integrating, e.g. `dio.get(Api.uri(ProductsApi.list).toString())`.
class Api {
  Api._();

  /// Production server. Override with `--dart-define=API_BASE_URL=...`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dermalens-production.up.railway.app',
  );

  /// Network timeout used by the HTTP client.
  static const Duration timeout = Duration(seconds: 15);

  /// Default headers. Pass the JWT returned by [UsersApi.login].
  static Map<String, String> headers({String? token}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// Builds a full [Uri] from an endpoint path and optional query params.
  ///
  /// ```dart
  /// Api.uri(ProductsApi.search, {'q': '토너'});
  /// // → https://.../api/products/search/?q=토너
  /// ```
  static Uri uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: query.map((k, v) => MapEntry(k, '$v')),
    );
  }

  /// Server health check.
  static const String health = '/health/';

  /// Django admin.
  static const String admin = '/admin/';
}

/// 👤 Users — `/api/users/`
class UsersApi {
  UsersApi._();

  static const String signup = '/api/users/signup/';
  static const String login = '/api/users/login/'; // → JWT
  static const String logout = '/api/users/logout/'; // body: { refresh }
  static const String tokenRefresh = '/api/users/token/refresh/'; // { refresh }
  static const String checkEmail = '/api/users/check-email/'; // ?email=...
  static const String kakaoLoginUrl = '/api/users/kakao/';
  /// 카카오 SDK access_token → 우리 JWT 발급.
  static const String kakaoAppLogin = '/api/users/kakao/app-login/';

  static String delete(Object userId) => '/api/users/delete/$userId/';
  static String profile(Object userId) => '/api/users/profile/$userId/';
  static String updateNickname(Object userId) =>
      '/api/users/profile/$userId/nickname/';

  static String skinProfile(Object userId) =>
      '/api/users/skin-profile/$userId/';
  static String updateSkinProfile(Object userId) =>
      '/api/users/skin-profile/$userId/update/';

  static const String survey = '/api/users/survey/';

  static String mypage(Object userId) => '/api/users/mypage/$userId/';
  static String mypageLikes(Object userId) =>
      '/api/users/mypage/$userId/likes/';
  static String mypageReviews(Object userId) =>
      '/api/users/mypage/$userId/reviews/';
  static String mypageAnalysis(Object userId) =>
      '/api/users/mypage/$userId/analysis/';
  static String mypageRecommendations(Object userId) =>
      '/api/users/mypage/$userId/recommendations/';

  // 🎯 Beta — 누적 포인트 (성분 등록 보상).
  static String mypagePoints(Object userId) =>
      '/api/users/mypage/$userId/points/';

  // 🔔 알림
  static String notifications(Object userId) =>
      '/api/users/notifications/$userId/';
  static String markNotificationRead(Object notificationId) =>
      '/api/users/notifications/$notificationId/read/';
  static String readAllNotifications(Object userId) =>
      '/api/users/notifications/read-all/$userId/';
}

/// 🧴 Products — `/api/products/`
class ProductsApi {
  ProductsApi._();

  static const String list = '/api/products/';
  static const String search = '/api/products/search/'; // ?q=키워드
  static const String popular = '/api/products/popular/';

  static String detail(Object productId) => '/api/products/$productId/';
  static String ingredients(Object productId) =>
      '/api/products/$productId/ingredients/';

  static const String categories = '/api/products/categories/';
  static String categoryProducts(Object categoryId) =>
      '/api/products/categories/$categoryId/';

  // 🎯 Beta — 사용자가 OCR로 성분을 찍어 DB에 등록.
  static String ingredientScan(Object productId) =>
      '/api/products/$productId/ingredient-scan/';

  static const String ingredientList = '/api/products/ingredients/';
  static const String ingredientSearch =
      '/api/products/ingredients/search/'; // ?q=키워드
  static String ingredientDetail(Object ingredientId) =>
      '/api/products/ingredients/$ingredientId/';
}

/// 🔬 Analysis — `/api/analysis/`
class AnalysisApi {
  AnalysisApi._();

  /// 프론트 → 백엔드: 이미지(또는 URL) 업로드 + OCR 요청.
  /// multipart/form-data — `user_id` + (`image` 파일 OR `image_url` 문자열)
  static const String requestOcr = '/api/analysis/request-ocr/';

  /// OCR 서버 → 백엔드 콜백 (프론트는 호출하지 않음).
  static const String ocrResult = '/api/analysis/ocr-result/';

  static const String analyzeProduct = '/api/analysis/analyze-product/';

  static String detail(Object analysisId) =>
      '/api/analysis/detail/$analysisId/';
  static String delete(Object analysisId) =>
      '/api/analysis/delete/$analysisId/';
  static String history(Object userId) => '/api/analysis/history/$userId/';

  static const String chat = '/api/analysis/chat/'; // { user_id, message }
  static const String chatStart = '/api/analysis/chat/start/';
  static const String chatMessage = '/api/analysis/chat/message/';
  static String chatHistory(Object sessionId) =>
      '/api/analysis/chat/history/$sessionId/';
  static String chatSessions(Object userId) =>
      '/api/analysis/chat/sessions/$userId/';
}

/// ⭐ Recommendation — `/api/recommendation/`
class RecommendationApi {
  RecommendationApi._();

  static const String generate = '/api/recommendation/generate/';
  static String user(Object userId) => '/api/recommendation/user/$userId/';
  static const String save = '/api/recommendation/save/';

  static const String like = '/api/recommendation/like/'; // toggle (POST)
  static String likeStatus(Object userId, Object productId) =>
      '/api/recommendation/like/$userId/$productId/';
}

/// 💄 Routine (화장 순서) — `/api/recommendation/routine/`
class RoutineApi {
  RoutineApi._();

  static const String create = '/api/recommendation/routine/';
  static String update(Object routineId) =>
      '/api/recommendation/routine/$routineId/';
  static String delete(Object routineId) =>
      '/api/recommendation/routine/$routineId/delete/';

  static String byUser(Object userId) =>
      '/api/recommendation/routine/user/$userId/';
  static String popular(String skinTypeCode) =>
      '/api/recommendation/routine/popular/$skinTypeCode/';
}

/// 📝 Review — `/api/review/`
class ReviewApi {
  ReviewApi._();

  static const String create = '/api/review/';
  static String update(Object reviewId) => '/api/review/$reviewId/update/';
  static String delete(Object reviewId) => '/api/review/$reviewId/delete/';

  static String byProduct(Object productId) =>
      '/api/review/product/$productId/';
  static String byUser(Object userId) => '/api/review/user/$userId/';

  static const String feedback = '/api/review/feedback/';
  static String feedbackByUser(Object userId) =>
      '/api/review/feedback/$userId/';

  static const String searchLog = '/api/review/search-log/';
  static String searchHistory(Object userId) =>
      '/api/review/search-history/$userId/';

  // Note: the endpoints below use the plural `/api/reviews/` prefix.
  static const String productView = '/api/reviews/product-view/';
  static String recentlyViewed(Object userId) =>
      '/api/reviews/recently-viewed/$userId/';
  static const String trending = '/api/reviews/trending/';
}
