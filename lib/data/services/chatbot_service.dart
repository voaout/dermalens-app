import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api_client.dart' show ApiException;
import '../../core/network/auth_session.dart';

/// 🤖 외부 챗봇 서버 (Railway 배포)
///
/// 백엔드 DB 호출은 챗봇 서버가 내부적으로 수행하므로, 프론트는 이 한 곳만
/// 호출하면 의도 분류 → 백엔드 데이터 조회 → 정형 응답까지 한 번에 받는다.
///
/// 응답 형식 (그대로 렌더링):
/// ```
/// {
///   "intent": "PRODUCT_RECOMMEND",
///   "score": 0.92,
///   "keywords": { "skin_type": "민지형", "category": "크림" },
///   "message": "민지형 피부에 맞는 크림 제품을 추천해드릴게요.",
///   "components": [
///     { "type": "card", "title": "...", "buttonText": "제품 상세보기", ... }
///   ],
///   "quickReplies": ["성분 분석", "피부 진단", "처음으로"]
/// }
/// ```
class ChatbotService {
  ChatbotService._();

  static const String _baseUrl =
      'https://dermalens-chatbot-production.up.railway.app';
  static const Duration _timeout = Duration(seconds: 30);

  static final http.Client _client = http.Client();

  /// 메시지를 챗봇에 보내고 정형 응답을 받는다.
  static Future<Map<String, dynamic>> chat(
    String message, {
    Object? sessionId,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'user_id': ?AuthSession.userId,
      'session_id': ?sessionId,
    };

    final uri = Uri.parse('$_baseUrl/chat');
    if (kDebugMode) {
      debugPrint('[Chatbot →] POST $uri  body=${jsonEncode(body)}');
    }

    final http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        0,
        '챗봇 응답이 30초를 넘어 중단됐어요. 챗봇 서버가 응답을 못 하고 있어요.',
      );
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[Chatbot SocketException] $e');
      throw ApiException(0, '챗봇 서버에 연결할 수 없어요. 네트워크를 확인해 주세요.');
    } on http.ClientException catch (e) {
      // 웹에서 CORS 차단·DNS 실패·서버 다운 등이 모두 이쪽으로 옵니다.
      if (kDebugMode) debugPrint('[Chatbot ClientException] $e');
      throw ApiException(
        0,
        '챗봇 서버 응답이 막혔어요. (CORS 또는 서버 상태 확인 필요)',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Chatbot ${e.runtimeType}] $e');
      throw ApiException(0, '챗봇 요청 중 오류: $e');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (kDebugMode) {
        debugPrint('[Chatbot ${res.statusCode}] ${res.body}');
      }
      throw ApiException(
        res.statusCode,
        '챗봇이 ${res.statusCode}로 응답했어요. (서버 측 오류 가능성)',
      );
    }

    if (kDebugMode) {
      final preview = res.body.length > 300
          ? '${res.body.substring(0, 300)}…'
          : res.body;
      debugPrint('[Chatbot 200] $preview');
    }

    if (res.body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // 본문 파싱 실패 — 빈 응답으로 fallthrough.
    }
    return const {};
  }

  /// 자동완성 (선택 사용). 챗봇 서버의 별도 엔드포인트.
  /// 실패는 silent — 자동완성은 UX 보조 기능이라 에러를 띄우지 않는다.
  static Future<List<String>> suggest(String q) async {
    final query = q.trim();
    if (query.isEmpty) return const [];
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/suggest')
              .replace(queryParameters: {'q': query}))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode < 200 || res.statusCode >= 300) return const [];
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is List) return decoded.whereType<String>().toList();
      if (decoded is Map && decoded['suggestions'] is List) {
        return (decoded['suggestions'] as List).whereType<String>().toList();
      }
    } catch (_) {}
    return const [];
  }
}
