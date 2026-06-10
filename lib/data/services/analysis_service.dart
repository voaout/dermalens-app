import '../../core/network/api.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';

/// 🔬 Analysis & chatbot — `/api/analysis/`
class AnalysisService {
  AnalysisService._();

  static Object _uid([Object? userId]) => userId ?? AuthSession.userId!;

  /// 프론트 → 백엔드: 이미지 파일을 직접 업로드해 OCR 요청.
  /// multipart/form-data — `user_id` + `image`.
  /// 응답에서 `analysis_id`(또는 `id`)를 받아 [detail]을 폴링하세요.
  static Future<dynamic> requestOcrWithBytes(
    List<int> bytes, {
    String filename = 'ingredients.jpg',
  }) =>
      ApiClient.I.uploadBytes(
        AnalysisApi.requestOcr,
        field: 'image',
        bytes: bytes,
        filename: filename,
        fields: {'user_id': '${_uid()}'},
      );

  /// 여러 장을 한 번에 보내 OCR 요청. 같은 `image` 필드명을 반복해서
  /// multipart로 전송 → 백엔드는 `request.FILES.getlist('image')`로 받음.
  /// 한 번의 호출 = 한 번의 분석 시도(analysis_id 1개) → 결과 폴링 동일.
  static Future<dynamic> requestOcrWithMultipleBytes(
    List<List<int>> bytesList,
  ) {
    final names = List.generate(
      bytesList.length,
      (i) => 'ingredients_${i + 1}.jpg',
    );
    return ApiClient.I.uploadBytesMulti(
      AnalysisApi.requestOcr,
      field: 'image',
      filesBytes: bytesList,
      filenames: names,
      fields: {'user_id': '${_uid()}'},
    );
  }

  /// 프론트 → 백엔드: 이미지 URL로 OCR 요청.
  static Future<dynamic> requestOcrWithUrl(String imageUrl) =>
      ApiClient.I.uploadBytes(
        AnalysisApi.requestOcr,
        field: 'image',
        bytes: const [], // no file
        fields: {
          'user_id': '${_uid()}',
          'image_url': imageUrl,
        },
      );

  /// (서버 콜백용) OCR 서버 → 백엔드 결과 저장. 프론트는 사용하지 않음.
  static Future<dynamic> submitOcrResult(Map<String, dynamic> body) =>
      ApiClient.I.post(AnalysisApi.ocrResult, body: body);

  /// 제품 ID로 성분 위험도 분석. `user_id`를 함께 보내면 개인화 결과 반환:
  ///   - 민감성(S) 피부면 자극 성분 위험도 +2
  ///   - 여드름성 피부면 여드름 유발 성분 위험도 +1
  ///   - 유저 알레르기 성분 포함 시 personalized_warnings에 포함
  static Future<dynamic> analyzeProduct(Object productId) =>
      ApiClient.I.post(AnalysisApi.analyzeProduct, body: {
        'user_id': _uid(),
        'product_id': productId,
      });

  static Future<dynamic> detail(Object analysisId) =>
      ApiClient.I.get(AnalysisApi.detail(analysisId));

  /// 분석 결과 삭제. `DELETE /api/analysis/delete/{id}/?user_id={uid}`.
  static Future<dynamic> deleteAnalysis(Object analysisId) =>
      ApiClient.I.delete(
        AnalysisApi.delete(analysisId),
        query: {'user_id': '${_uid()}'},
      );

  static Future<dynamic> history([Object? userId]) =>
      ApiClient.I.get(AnalysisApi.history(_uid(userId)));

  // --- chatbot ---

  /// 통합 챗봇 엔드포인트. 자동으로 세션이 저장되고 `session_id`/`intent`/
  /// `components`가 응답에 포함됩니다. [sessionId]를 함께 보내면 같은 세션
  /// 안에서 대화 맥락을 이어갈 수 있어요(백엔드가 지원하는 경우).
  static Future<dynamic> chat(String message, {Object? sessionId}) =>
      ApiClient.I.post(AnalysisApi.chat, body: {
        'user_id': _uid(),
        'message': message,
        'session_id': ?sessionId,
      });

  /// (구) 별도 세션 시작 — 이제 [chat]이 자동 처리하므로 보통은 불필요.
  static Future<dynamic> startChat() =>
      ApiClient.I.post(AnalysisApi.chatStart, body: {'user_id': _uid()});

  static Future<dynamic> sendMessage({
    required Object sessionId,
    required String message,
  }) =>
      ApiClient.I.post(AnalysisApi.chatMessage, body: {
        'user_id': _uid(),
        'session_id': sessionId,
        'message': message,
      });

  static Future<dynamic> chatHistory(Object sessionId) =>
      ApiClient.I.get(AnalysisApi.chatHistory(sessionId));

  static Future<dynamic> chatSessions([Object? userId]) =>
      ApiClient.I.get(AnalysisApi.chatSessions(_uid(userId)));
}
