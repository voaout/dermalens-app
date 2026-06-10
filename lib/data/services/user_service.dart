import '../../core/network/api.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';

/// 👤 User profile & mypage — `/api/users/`
class UserService {
  UserService._();

  static Object _uid([Object? userId]) => userId ?? AuthSession.userId!;

  static Future<dynamic> profile([Object? userId]) =>
      ApiClient.I.get(UsersApi.profile(_uid(userId)));

  static Future<dynamic> updateNickname(String nickname, [Object? userId]) =>
      ApiClient.I.patch(UsersApi.updateNickname(_uid(userId)),
          body: {'nickname': nickname});

  static Future<dynamic> skinProfile([Object? userId]) =>
      ApiClient.I.get(UsersApi.skinProfile(_uid(userId)));

  static Future<dynamic> updateSkinProfile(
    Map<String, dynamic> body, [
    Object? userId,
  ]) =>
      ApiClient.I.patch(UsersApi.updateSkinProfile(_uid(userId)), body: body);

  /// 설문 응답 저장 → 피부타입 자동 분류. `{ user_id, selected_option_ids, ... }`.
  static Future<dynamic> submitSurvey(Map<String, dynamic> answers) =>
      ApiClient.I.post(UsersApi.survey, body: {
        'user_id': _uid(),
        ...answers,
      });

  static Future<dynamic> mypage([Object? userId]) =>
      ApiClient.I.get(UsersApi.mypage(_uid(userId)));

  static Future<dynamic> likes([Object? userId]) =>
      ApiClient.I.get(UsersApi.mypageLikes(_uid(userId)));

  static Future<dynamic> reviews([Object? userId]) =>
      ApiClient.I.get(UsersApi.mypageReviews(_uid(userId)));

  static Future<dynamic> analysisHistory([Object? userId]) =>
      ApiClient.I.get(UsersApi.mypageAnalysis(_uid(userId)));

  static Future<dynamic> recommendations([Object? userId]) =>
      ApiClient.I.get(UsersApi.mypageRecommendations(_uid(userId)));

  /// 🎯 Beta — 누적 포인트 + 적립 내역.
  static Future<dynamic> points([Object? userId]) =>
      ApiClient.I.get(UsersApi.mypagePoints(_uid(userId)));

  // 🔔 알림
  /// 알림 목록 + unread_count.
  static Future<dynamic> notifications([Object? userId]) =>
      ApiClient.I.get(UsersApi.notifications(_uid(userId)));

  /// 단건 읽음 처리.
  static Future<dynamic> markNotificationRead(Object notificationId) =>
      ApiClient.I.patch(UsersApi.markNotificationRead(notificationId),
          body: {'user_id': _uid()});

  /// 전체 읽음 처리.
  static Future<dynamic> markAllNotificationsRead([Object? userId]) =>
      ApiClient.I.post(UsersApi.readAllNotifications(_uid(userId)), body: {});
}
