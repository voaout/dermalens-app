// "나의 화장대" data models.
//
// Routines (title + ordered product steps) are persisted on the backend via
// `/api/recommendation/routine/`. Popular routines are aggregated by skin type.

/// 루틴 한 스텝: 백엔드가 `product_id`로 식별하므로 id가 필수, 화면 표시용
/// `name`과 선택 `memo`도 함께 들고 다닙니다.
class RoutineStep {
  final Object? productId;
  final String name;
  final String memo;

  const RoutineStep({this.productId, required this.name, this.memo = ''});

  /// 백엔드 응답에서 한 스텝을 만든다.
  /// 예) {step_order: 1, product_id: 10, product_name: '독도 토너', memo: ''}
  ///   또는 {product: '독도 토너'} 같은 단순 형태도 수용.
  factory RoutineStep.fromJson(dynamic v) {
    if (v is Map) {
      final m = v.cast<String, dynamic>();
      return RoutineStep(
        productId: m['product_id'] ?? m['productId'],
        name: '${m['product_name'] ?? m['name'] ?? m['product'] ?? m['step'] ?? ''}',
        memo: '${m['memo'] ?? ''}',
      );
    }
    return RoutineStep(name: '$v');
  }
}

List<RoutineStep> _stepsFrom(dynamic v) {
  if (v is List) {
    return v
        .map(RoutineStep.fromJson)
        .where((s) => s.name.isNotEmpty || s.productId != null)
        .toList();
  }
  return const [];
}

/// (호환용) 이름만 필요한 화면이 있을 때 사용.
List<String> routineStepsFrom(dynamic v) =>
    _stepsFrom(v).map((s) => s.name).where((n) => n.isNotEmpty).toList();

/// A user's saved routine.
class Routine {
  final Object? id;
  final String title;
  final List<RoutineStep> steps;
  final bool isPublic;

  const Routine({
    this.id,
    required this.title,
    required this.steps,
    this.isPublic = true,
  });

  factory Routine.fromJson(Map<String, dynamic> j) {
    return Routine(
      id: j['routine_id'] ?? j['id'],
      title: '${j['title'] ?? j['name'] ?? j['routine_name'] ?? '내 루틴'}',
      steps: _stepsFrom(
          j['steps'] ?? j['step_list'] ?? j['routine_steps'] ?? j['products']),
      isPublic: j['is_public'] == true || j['isPublic'] == true,
    );
  }
}

/// A popular routine statistic for a skin type.
/// steps는 RoutineStep으로 들고 다녀 product_id 기반 네비게이션이 가능합니다.
class PopularRoutine {
  final int percent;
  final List<RoutineStep> steps;

  const PopularRoutine({required this.percent, required this.steps});

  factory PopularRoutine.fromJson(Map<String, dynamic> j) {
    final raw = j['percent'] ??
        j['percentage'] ??
        j['ratio'] ??
        j['rate'] ??
        j['count'] ??
        0;
    num p = raw is num ? raw : (num.tryParse('$raw') ?? 0);
    // A ratio in 0..1 is shown as a percentage.
    if (p > 0 && p <= 1) p = p * 100;
    return PopularRoutine(
      percent: p.round(),
      steps: _stepsFrom(
          j['steps'] ?? j['step_list'] ?? j['routine_steps'] ?? j['products']),
    );
  }
}
