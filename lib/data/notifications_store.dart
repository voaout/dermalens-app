import 'package:flutter/foundation.dart';

import '../core/network/auth_session.dart';
import 'services/parsing.dart';
import 'services/user_service.dart';

/// Backend notifications badge — `unread_count` from
/// `GET /api/users/notifications/{user_id}/`.
///
/// In-flight OCR jobs live in [AnalysisJobsStore]; this store only tracks
/// the server-side unread count.
class NotificationsStore extends ChangeNotifier {
  NotificationsStore._();
  static final NotificationsStore I = NotificationsStore._();

  int _unreadCount = 0;

  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  /// Refetches the unread count from the server. Safe to call any time —
  /// silently no-ops when logged out or on transient errors.
  Future<void> refresh() async {
    if (!AuthSession.isLoggedIn) return;
    try {
      final data = await UserService.notifications();
      final m = mapOf(data);
      final raw = m['unread_count'] ?? m['unreadCount'] ?? 0;
      final n = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
      _unreadCount = n;
      notifyListeners();
    } catch (_) {
      // best-effort
    }
  }

  /// Mark a single notification as read and refresh the badge.
  Future<void> markRead(Object notificationId) async {
    try {
      await UserService.markNotificationRead(notificationId);
      await refresh();
    } catch (_) {}
  }

  /// Clear the unread badge (optimistic + server).
  Future<void> markAllRead() async {
    _unreadCount = 0;
    notifyListeners();
    try {
      await UserService.markAllNotificationsRead();
    } catch (_) {}
  }

  /// Local-only reset (e.g. on logout).
  void reset() {
    _unreadCount = 0;
    notifyListeners();
  }
}
