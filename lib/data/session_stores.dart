import 'activity_store.dart';
import 'analysis_jobs_store.dart';
import 'beta_rewards_store.dart';
import 'notifications_store.dart';
import 'user_profile.dart';

/// 모든 사용자별(static) in-memory store를 비웁니다.
///
/// 로그인 / 회원가입 / 로그아웃 / 회원탈퇴 시 호출해서 이전 계정의 데이터가
/// 새 계정 화면에 새어 나오지 않게 합니다.
///
/// **Why this exists**: 각 도메인 store가 정적 리스트(`static final items`)라
/// 앱이 살아있는 동안 메모리에 계속 남습니다. AuthSession만 비워도 store는
/// 그대로라, 다음 사용자가 잠깐이라도 이전 데이터를 보게 됩니다.
void resetUserScopedStores() {
  AnalysisHistoryStore.clear();
  LikedProductsStore.clear();
  MyReviewsStore.clear();
  RecommendationHistoryStore.clear();
  AnalysisJobsStore.I.reset();
  NotificationsStore.I.reset();
  BetaRewardsStore.I.reset();
  UserProfile.reset();
}
