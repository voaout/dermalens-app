import 'package:flutter/foundation.dart';

import 'user_profile.dart';

/// 🎯 Beta 성분 등록 보상 시스템 store.
///
/// - `totalPoints`: 누적 포인트 (마이페이지/홈 등에 표시)
/// - 홈 진입 시 안내 팝업이 "오늘 그만보기"로 닫혔는지 날짜 단위로 추적
///   (앱 재시작 시 초기화됨 — 본격 영속화는 SharedPreferences로 추후)
class BetaRewardsStore extends ChangeNotifier {
  BetaRewardsStore._();
  static final BetaRewardsStore I = BetaRewardsStore._();

  /// 같은 인스턴스: 누적 포인트는 [UserProfile.betaPoints]에 둠.
  int get totalPoints => UserProfile.betaPoints;

  /// 팝업이 마지막으로 "오늘 그만보기"로 닫힌 날짜.
  DateTime? _dismissedDate;

  /// 오늘 이미 "오늘 그만보기"로 닫혔는가.
  bool get dismissedToday {
    final d = _dismissedDate;
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// 사용자가 "오늘 그만보기"를 눌렀을 때.
  void dismissForToday() {
    _dismissedDate = DateTime.now();
    notifyListeners();
  }

  /// 서버 응답에서 받은 누적 포인트로 갱신.
  void setTotalPoints(int points) {
    if (UserProfile.betaPoints == points) return;
    UserProfile.betaPoints = points;
    notifyListeners();
  }

  /// 로그아웃/계정 전환 시 호출.
  void reset() {
    _dismissedDate = null;
    UserProfile.betaPoints = 0;
    notifyListeners();
  }
}
