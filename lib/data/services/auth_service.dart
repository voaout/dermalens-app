import '../../core/network/api.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';
import '../session_stores.dart';
import '../user_profile.dart';

/// 👤 Auth / session — `/api/users/`
class AuthService {
  AuthService._();

  /// 회원가입. `{ email, password, nickname }`.
  /// On success the API returns user + tokens, so we establish the session.
  static Future<dynamic> signup({
    required String email,
    required String password,
    String? nickname,
  }) async {
    final data = await ApiClient.I.post(UsersApi.signup, body: {
      'email': email,
      'password': password,
      'nickname': ?nickname,
    });
    // 새 계정 시작 — 직전 사용자의 in-memory 데이터를 미리 비웁니다.
    resetUserScopedStores();
    _saveSessionFrom(data);
    return data;
  }

  /// 이메일 중복 확인. `available: true` → 사용 가능.
  static Future<bool> isEmailAvailable(String email) async {
    final data =
        await ApiClient.I.get(UsersApi.checkEmail, query: {'email': email});
    if (data is Map && data['available'] is bool) {
      return data['available'] as bool;
    }
    return true;
  }

  /// 로그인 → JWT. On success, stores access/refresh + userId in [AuthSession].
  static Future<dynamic> login({
    required String email,
    required String password,
  }) async {
    final data = await ApiClient.I.post(UsersApi.login, body: {
      'email': email,
      'password': password,
    });
    // 로그인 성공 → 이전 사용자 데이터를 비우고 새 세션 저장.
    resetUserScopedStores();
    _saveSessionFrom(data);
    return data;
  }

  /// 로그아웃 — blacklists the refresh token, then clears the local session.
  static Future<void> logout() async {
    try {
      await ApiClient.I.post(UsersApi.logout, body: {
        'refresh': ?AuthSession.refreshToken,
      });
    } finally {
      AuthSession.clear();
      resetUserScopedStores();
    }
  }

  /// 회원 탈퇴.
  static Future<dynamic> withdraw([Object? userId]) async {
    final uid = userId ?? AuthSession.userId;
    final res = await ApiClient.I.delete(UsersApi.delete(uid!));
    AuthSession.clear();
    resetUserScopedStores();
    return res;
  }

  /// 카카오 로그인 URL 요청 (웹 OAuth 리다이렉트용 — 거의 안 씀).
  static Future<dynamic> kakaoLoginUrl() =>
      ApiClient.I.get(UsersApi.kakaoLoginUrl);

  /// 카카오 SDK access_token → 우리 JWT 발급.
  /// 응답이 일반 로그인과 동일하게 `{user, tokens}` 모양이라 같은 헬퍼로 세션
  /// 저장. 이전 사용자 데이터 누수 방지를 위해 저장 전에 store 리셋.
  static Future<dynamic> kakaoAppLogin(String accessToken) async {
    final data = await ApiClient.I.post(
      UsersApi.kakaoAppLogin,
      body: {'access_token': accessToken},
    );
    resetUserScopedStores();
    _saveSessionFrom(data);
    return data;
  }

  // --- helpers ---

  // Response shape: { user: { user_id, ... }, tokens: { access, refresh } }
  static void _saveSessionFrom(dynamic data) {
    if (data is! Map) return;
    final tokens = data['tokens'];
    final user = data['user'];
    final access = (tokens is Map ? tokens['access'] : null) ?? data['access'];
    final refresh =
        (tokens is Map ? tokens['refresh'] : null) ?? data['refresh'];
    final uid = (user is Map ? user['user_id'] ?? user['id'] : null) ??
        data['user_id'];

    if (access is String && access.isNotEmpty && uid != null) {
      AuthSession.save(
        token: access,
        userId: uid,
        refreshToken: refresh is String ? refresh : null,
      );
    }

    // Populate the local profile so screens (mypage/home) show user info
    // immediately after login/signup.
    if (user is Map) {
      final email = user['email'];
      final nickname = user['nickname'];
      if (email is String && email.isNotEmpty) UserProfile.email = email;
      if (nickname is String && nickname.isNotEmpty) {
        UserProfile.nickname = nickname;
      }
      // 🎯 Beta — 누적 포인트도 함께 들어옴.
      final pts = user['points'];
      if (pts is num) UserProfile.betaPoints = pts.toInt();
    }
  }
}
