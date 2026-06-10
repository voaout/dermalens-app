// In-memory user profile store. Persists within the current session only;
// resets on app restart. Replace with a real repository (API/local storage)
// when the backend is connected.
class UserProfile {
  // User table fields — populated from the API after login.
  // TODO(backend): hydrate these from the authenticated user session.
  static String userId = '';
  static String nickname = '';
  static String email = '';

  // Skin profile fields — set by the survey or loaded from the API.
  static String skinType = '';
  static String skinTypeCode = ''; // e.g. "DN+" — preferred for matching
  static final Set<String> allergies = <String>{};

  /// 🎯 Beta — 누적 포인트 (성분 등록 보상). 로그인/마이페이지/스캔 응답에서 갱신.
  static int betaPoints = 0;

  /// 계정 전환/로그아웃 시 호출 — 이전 사용자 정보가 새 화면에 노출되지 않게.
  static void reset() {
    userId = '';
    nickname = '';
    email = '';
    skinType = '';
    skinTypeCode = '';
    allergies.clear();
    betaPoints = 0;
  }

  static const List<String> skinTypeOptions = [
    '건성',
    '지성',
    '복합성',
    '민감성',
    '중성',
  ];

  static const List<String> allergyOptions = [
    // 보존료 / 방부제
    '파라벤',
    '메틸파라벤',
    '프로필파라벤',
    '페녹시에탄올',
    '메틸이소티아졸리논(MIT)',
    '폼알데하이드 방출제',

    // 향
    '인공향료',
    '천연향료',
    '에센셜오일',
    '라벤더 오일',
    '티트리 오일',
    '캐모마일 추출물',
    '시트러스 추출물',

    // 자극성
    '알코올(에탄올)',
    '설페이트(SLS)',
    '설페이트(SLES)',
    '실리콘',
    'PEG 계열',

    // 색소
    '인공 색소',
    '타르 색소',

    // 산 / 필링
    '산성분(AHA)',
    '산성분(BHA)',
    '살리실산',
    '글리콜산',
    '레티놀',

    // 자외선 차단제
    '옥시벤존',
    '아보벤존',
    '호모살레이트',

    // 기타 자주 거론되는 성분
    '미네랄 오일',
    '라놀린',
    '글루텐',
    '특정 식물 추출물',
  ];
}
