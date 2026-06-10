/// Holds the authenticated session (JWT + user id) for the current run.
///
/// Stored in memory only — it resets on app restart. When you want the login
/// to survive restarts, persist [token]/[userId] with `shared_preferences` or
/// `flutter_secure_storage` in [save]/[load]/[clear].
class AuthSession {
  AuthSession._();

  /// JWT access token — attached as `Authorization: Bearer <token>` on every
  /// request via [Api.headers].
  static String? token;

  /// JWT refresh token (SimpleJWT). Used to obtain a new access token.
  static String? refreshToken;

  static Object? userId;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  /// Call after a successful login/signup response.
  static void save({
    required String token,
    required Object userId,
    String? refreshToken,
  }) {
    AuthSession.token = token;
    AuthSession.userId = userId;
    AuthSession.refreshToken = refreshToken;
    // TODO(backend): persist to secure storage here.
  }

  /// Call on logout / withdraw / 401.
  static void clear() {
    token = null;
    refreshToken = null;
    userId = null;
    // TODO(backend): remove from secure storage here.
  }
}
