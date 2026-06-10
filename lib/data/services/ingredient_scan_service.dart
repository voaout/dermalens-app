import '../../core/network/api.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';

/// 🎯 사용자 OCR 성분 등록 (베타 보상 시스템) — `/api/products/{id}/ingredient-scan/`
///
/// - 최초 등록자: 5p
/// - 검증자(이후 9명): 1p
/// - 제품당 10명까지
/// - 1인 1제품 1회 (재등록 차단)
/// - OCR 실패 시 0p + 시도 차감 안 됨 (재시도 가능)
class IngredientScanService {
  IngredientScanService._();

  static Object _uid([Object? userId]) => userId ?? AuthSession.userId!;

  /// 이미지 파일 업로드로 성분 등록.
  static Future<dynamic> scanWithBytes(
    Object productId,
    List<int> bytes, {
    String filename = 'ingredients.jpg',
  }) =>
      ApiClient.I.uploadBytes(
        ProductsApi.ingredientScan(productId),
        field: 'image',
        bytes: bytes,
        filename: filename,
        fields: {'user_id': '${_uid()}'},
      );

  /// 여러 장의 사진을 한 번에 보내 성분 등록.
  /// 같은 `image` 필드명을 반복해서 multipart로 전송 → 백엔드는
  /// `request.FILES.getlist('image')`로 리스트를 받습니다.
  ///
  /// "1인 1제품 1회" 룰은 호출 단위라 이게 한 번의 시도로 카운트됩니다.
  static Future<dynamic> scanWithMultipleBytes(
    Object productId,
    List<List<int>> filesBytes,
  ) {
    final names = List.generate(
      filesBytes.length,
      (i) => 'ingredients_${i + 1}.jpg',
    );
    return ApiClient.I.uploadBytesMulti(
      ProductsApi.ingredientScan(productId),
      field: 'image',
      filesBytes: filesBytes,
      filenames: names,
      fields: {'user_id': '${_uid()}'},
    );
  }

  /// URL 기반 성분 등록 (관리자/외부 이미지).
  static Future<dynamic> scanWithUrl(
    Object productId,
    String imageUrl,
  ) =>
      ApiClient.I.uploadBytes(
        ProductsApi.ingredientScan(productId),
        field: 'image',
        bytes: const [],
        fields: {
          'user_id': '${_uid()}',
          'image_url': imageUrl,
        },
      );
}
