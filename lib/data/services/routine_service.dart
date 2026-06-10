import '../../core/network/api.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';
import '../vanity_store.dart';

/// 💄 화장 순서 루틴 — `/api/recommendation/routine/`
class RoutineService {
  RoutineService._();

  static Object _uid([Object? userId]) => userId ?? AuthSession.userId!;

  /// 루틴 생성.
  /// 백엔드 스펙:
  /// ```
  /// { user_id, title, is_public, steps: [{step_order, product_id, memo}] }
  /// ```
  /// `product_id`가 없는 step은 폐기됩니다 (백엔드가 필수).
  static Future<dynamic> create({
    required String title,
    required List<RoutineStep> steps,
    bool isPublic = true,
  }) {
    final body = _routineBody(
      title: title,
      steps: steps,
      isPublic: isPublic,
    );
    return ApiClient.I.post(RoutineApi.create, body: body);
  }

  /// 루틴 수정.
  static Future<dynamic> update(
    Object routineId, {
    required String title,
    required List<RoutineStep> steps,
    bool isPublic = true,
  }) {
    final body = _routineBody(
      title: title,
      steps: steps,
      isPublic: isPublic,
    );
    return ApiClient.I.patch(RoutineApi.update(routineId), body: body);
  }

  /// 루틴 삭제.
  static Future<dynamic> delete(Object routineId) =>
      ApiClient.I.delete(RoutineApi.delete(routineId), body: {'user_id': _uid()});

  /// 내 루틴 목록.
  static Future<dynamic> myRoutines([Object? userId]) =>
      ApiClient.I.get(RoutineApi.byUser(_uid(userId)));

  /// 피부타입별 인기 루틴.
  static Future<dynamic> popular(String skinTypeCode) =>
      ApiClient.I.get(RoutineApi.popular(skinTypeCode));

  /// create/update가 같은 바디 모양을 쓰므로 공통 빌더.
  static Map<String, dynamic> _routineBody({
    required String title,
    required List<RoutineStep> steps,
    required bool isPublic,
  }) {
    final ordered = <Map<String, dynamic>>[];
    var idx = 1;
    for (final s in steps) {
      if (s.productId == null) continue; // product_id 없는 step은 보낼 수 없음.
      ordered.add({
        'step_order': idx++,
        'product_id': s.productId,
        'memo': s.memo,
      });
    }
    return {
      'user_id': _uid(),
      'title': title,
      'is_public': isPublic,
      'steps': ordered,
    };
  }
}
