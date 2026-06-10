import 'dart:typed_data';

import '../../core/network/api_client.dart';
import 'analysis_service.dart';
import 'parsing.dart';

/// Final payload from a completed OCR analysis.
class OcrJobResult {
  final Object analysisId;
  final Map<String, dynamic> data;
  const OcrJobResult({required this.analysisId, required this.data});
}

class OcrJobError implements Exception {
  final String message;
  const OcrJobError(this.message);
  @override
  String toString() => message;
}

/// Runs the full OCR pipeline (upload → poll detail) as a self-contained
/// top-level Future, so it keeps running even if the originating screen
/// (e.g. [OcrLoadingScreen]) is popped — the user can hit "홈으로 가기"
/// and the analysis continues in the background, updating
/// [NotificationsStore] for the nav-bar badge.
class OcrJobRunner {
  OcrJobRunner._();

  // 백오프 — 빠른 결과는 빨리 캐치, 오래 걸리면 부담 적게.
  //   0~30초:    1.5초 간격 (~20회)
  //   30초~5분:  3초 간격 (~90회)
  //   5분~30분:  10초 간격 (~150회)
  // 30분 안전망 — 그 이상은 서버 행/장애로 판단해 종료.
  static const Duration _safetyCap = Duration(minutes: 30);

  static Duration _intervalForElapsed(Duration elapsed) {
    if (elapsed < const Duration(seconds: 30)) {
      return const Duration(milliseconds: 1500);
    }
    if (elapsed < const Duration(minutes: 5)) {
      return const Duration(seconds: 3);
    }
    return const Duration(seconds: 10);
  }

  /// Pure pipeline: upload + poll detail → result. Lifecycle/badge updates
  /// happen in [AnalysisJobsStore.start], which wraps this call.
  static Future<OcrJobResult> run(List<Uint8List> bytesList) async {
    assert(bytesList.isNotEmpty, 'OCR job needs at least one image');
    try {
      // 1) 업로드 + OCR 요청 → analysis_id 수신. 같은 image 필드를 반복해서
      //    여러 장을 한 번의 multipart로 전송 → 한 번의 분석으로 묶임.
      final res =
          await AnalysisService.requestOcrWithMultipleBytes(bytesList);
      final body = mapOf(res);
      final analysisId = _pickAnalysisId(body);
      if (analysisId == null) {
        throw const OcrJobError('분석 ID를 받지 못했어요.');
      }

      // 일부 백엔드는 업로드 응답에 결과를 같이 보낼 수도 있음.
      final inlineResult = _extractResult(body);
      if (inlineResult != null && _isReady(inlineResult)) {
        return OcrJobResult(analysisId: analysisId, data: inlineResult);
      }

      // 2) detail 폴링 — OCR 서버 콜백이 채울 때까지 백오프하며 대기.
      final start = DateTime.now();
      while (true) {
        final elapsed = DateTime.now().difference(start);
        if (elapsed >= _safetyCap) {
          throw const OcrJobError(
              '30분이 지나도 결과가 오지 않았어요. 다시 시도해 주세요.');
        }
        await Future.delayed(_intervalForElapsed(elapsed));
        try {
          final detail = await AnalysisService.detail(analysisId);
          final result = _extractResult(mapOf(detail));
          if (result != null && _isReady(result)) {
            return OcrJobResult(analysisId: analysisId, data: result);
          }
        } on ApiException {
          // 분석 레코드 생성 중 일시적 404 등은 무시하고 계속 폴링.
        }
      }
    } on ApiException catch (e) {
      throw OcrJobError(e.message);
    }
  }

  static Object? _pickAnalysisId(Map<String, dynamic> body) {
    final candidates = [
      body['analysis_id'],
      body['id'],
      (body['analysis'] is Map ? body['analysis']['id'] : null),
      (body['analysis'] is Map ? body['analysis']['analysis_id'] : null),
      (body['data'] is Map ? body['data']['analysis_id'] : null),
      (body['data'] is Map ? body['data']['id'] : null),
    ];
    for (final c in candidates) {
      if (c != null) return c;
    }
    return null;
  }

  /// Public alias — 같은 추출 로직을 분석 탭(history detail 응답)에서도 씁니다.
  static Map<String, dynamic>? extractResult(Map<String, dynamic> top) =>
      _extractResult(top);

  /// 분석 결과 추출. 백엔드 응답 모양이 다음 패턴 모두 지원:
  ///
  /// A) 신규 형태:
  ///    { result: { sent_payload: {...}, backend_response: { body: {...} },
  ///                matched_product: {...} } }
  ///    → body가 본체. sent_payload는 image_url 등 보조. matched_product 등
  ///      result 레벨 직속 필드(컨테이너 제외)도 함께 병합한다.
  ///
  /// B) 단순 인라인:
  ///    { result: {...} } 또는 { analysis: {...} } 또는 { data: {...} } 또는 top.
  static Map<String, dynamic>? _extractResult(Map<String, dynamic> top) {
    Map<String, dynamic>? body;
    Map<String, dynamic>? payload;
    Map<String, dynamic> resultLevel = const {};

    final r = top['result'];
    if (r is Map) {
      final rm = r.cast<String, dynamic>();
      final br = rm['backend_response'];
      if (br is Map && br['body'] is Map) {
        body = (br['body'] as Map).cast<String, dynamic>();
      }
      if (rm['sent_payload'] is Map) {
        payload = (rm['sent_payload'] as Map).cast<String, dynamic>();
      }
      // result 레벨의 직속 필드 — matched_product 같이 컨테이너 밖에 있는
      // 데이터를 보존하기 위해 별도로 모음. 컨테이너 키(이미 펼친 것)는 제외.
      const skipKeys = {'backend_response', 'sent_payload'};
      resultLevel = <String, dynamic>{
        for (final e in rm.entries)
          if (!skipKeys.contains(e.key)) e.key: e.value,
      };
      // 중첩이 없으면 result 자체를 결과로 사용.
      if (body == null && payload == null) return rm;
    }

    if (body != null || payload != null) {
      // 우선순위 (낮은 → 높은): resultLevel → payload → body
      // 같은 키가 있으면 body가 가장 권위 있음.
      return <String, dynamic>{...resultLevel, ...?payload, ...?body};
    }

    // C) Production 백엔드 형태:
    //    { success, matched_product, analysis: {...}, ingredient_details: [...] }
    //    → analysis(본체) + 같은 레벨의 보조 필드(matched_product 등)를 함께 보존.
    for (final key in ['analysis', 'data']) {
      if (top[key] is Map) {
        final inner = (top[key] as Map).cast<String, dynamic>();
        // 컨테이너 키와 단순 메타(success 등)는 제외하고 최상위 보조 필드만 모음.
        const skip = {'analysis', 'data', 'result', 'success'};
        final topAux = <String, dynamic>{
          for (final e in top.entries)
            if (!skip.contains(e.key)) e.key: e.value,
        };
        // inner가 가장 권위 있음. 같은 키 있으면 inner가 이김.
        return <String, dynamic>{...topAux, ...inner};
      }
    }
    return top.isEmpty ? null : top;
  }

  static bool _isReady(Map<String, dynamic> r) {
    // 백엔드 분석이 채워졌다는 표지(우선순위 순):
    if (r['traffic_light'] is String &&
        (r['traffic_light'] as String).isNotEmpty) {
      return true;
    }
    if (r['risk_score'] != null) return true;
    final matched = r['matched_ingredients'];
    if (matched is List && matched.isNotEmpty) return true;
    final ings = r['ingredients'];
    if (ings is List && ings.isNotEmpty) return true;
    final raw = r['raw_text'] ?? r['ocr_text'];
    if (raw is String && raw.trim().isNotEmpty) return true;
    return false;
  }
}
