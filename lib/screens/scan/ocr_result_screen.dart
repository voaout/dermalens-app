import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/services/parsing.dart';
import '../../data/services/product_service.dart';
import '../../widgets/common/product_image.dart';
import '../main/main_tab_screen.dart';

/// 매칭된 단일 성분 + 플래그.
class IngredientItem {
  final String name;
  final bool allergy;
  final bool irritant;
  final bool acneCaution;
  final bool moisturizing;
  final bool soothing;

  const IngredientItem({
    required this.name,
    this.allergy = false,
    this.irritant = false,
    this.acneCaution = false,
    this.moisturizing = false,
    this.soothing = false,
  });

  factory IngredientItem.fromJson(Map<String, dynamic> m) {
    return IngredientItem(
      name: '${m['ingredient_name_kr'] ?? m['name_kr'] ?? m['detected_text'] ?? m['name'] ?? ''}',
      allergy: m['allergy_flag'] == true,
      irritant: m['irritant_flag'] == true,
      acneCaution: m['acne_caution_flag'] == true,
      moisturizing: m['moisturizing_flag'] == true,
      soothing: m['soothing_flag'] == true,
    );
  }

  bool get hasWarning => allergy || irritant || acneCaution;
  bool get hasBenefit => moisturizing || soothing;
}

/// Builds an [OcrResultScreen] from a backend analysis json (already
/// extracted by [OcrJobRunner._extractResult] — i.e. body + sent_payload
/// merged into a flat map).
OcrResultScreen buildResultScreen(
  Map<String, dynamic> r, {
  Uint8List? imageBytes,
}) {
  String s(List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v != null) return '$v';
    }
    return '';
  }

  List<String> strList(dynamic v) {
    if (v is List) {
      return v
          .map((e) {
            if (e is Map) {
              return '${e['name'] ?? e['ingredient'] ?? e['text'] ?? ''}';
            }
            return '$e';
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  final matchedRaw = r['matched_ingredients'];
  final matched = matchedRaw is List
      ? matchedRaw
          .whereType<Map>()
          .map((m) => IngredientItem.fromJson(m.cast<String, dynamic>()))
          .where((i) => i.name.isNotEmpty)
          .toList()
      : <IngredientItem>[];

  final efficacy = r['efficacy'];
  final moist = (efficacy is Map && efficacy['moisturizing'] is List)
      ? List<String>.from((efficacy['moisturizing'] as List).map((e) => '$e'))
      : const <String>[];
  final sooth = (efficacy is Map && efficacy['soothing'] is List)
      ? List<String>.from((efficacy['soothing'] as List).map((e) => '$e'))
      : const <String>[];

  // 🆕 백엔드가 제품명으로 DB를 자동 매칭해서 보내주는 객체.
  // 있으면 제품명·브랜드·이미지·가격을 정확한 DB 값으로 표시.
  final mp = r['matched_product'];
  final matchedProduct = mp is Map ? mp.cast<String, dynamic>() : null;

  // 디버그 — 브라우저 콘솔에서 matched_product가 도착했는지/추출됐는지 확인.
  debugPrint(
    '[OCR Result] keys=${r.keys.toList()} '
    'matched_product=${matchedProduct != null ? matchedProduct.keys.toList() : "null"}',
  );
  String mpStr(List<String> keys) {
    if (matchedProduct == null) return '';
    for (final k in keys) {
      final v = matchedProduct[k];
      if (v != null) return '$v';
    }
    return '';
  }

  num? mpNum(List<String> keys) {
    if (matchedProduct == null) return null;
    for (final k in keys) {
      final v = matchedProduct[k];
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
    }
    return null;
  }

  return OcrResultScreen(
    imageBytes: imageBytes,
    imageUrl: s(['image_url', 'imageUrl']),
    productName: s(['product_name', 'name']),
    capacity: s(['capacity', 'volume']),
    matchedProductName: mpStr(['product_name', 'name']),
    matchedBrandName: mpStr(['brand_name', 'brand']),
    matchedImageUrl: mpStr(['image_url', 'imageUrl']),
    matchedPrice: mpNum(['price']),
    rawText: s(['raw_text', 'ocr_text', 'text']),
    confidence: (r['ocr_confidence'] ?? r['confidence']) as num?,
    ingredients: strList(r['ingredients']),
    unmatchedIngredients: strList(r['unmatched_ingredients']),
    effects: strList(r['effects']),
    usage: strList(r['usage']),
    cautions: strList(r['cautions']),
    matchedIngredients: matched,
    trafficLight: s(['traffic_light']),
    riskScore: r['risk_score'] as num?,
    summary: s(['summary']),
    allergyWarnings: strList(r['allergy_warnings']),
    acneWarnings: strList(r['acne_warnings']),
    highRiskIngredients: strList(r['high_risk_ingredients']),
    personalizedWarnings: strList(r['personalized_warnings']),
    moisturizingIngredients: moist,
    soothingIngredients: sooth,
  );
}

/// OCR + 백엔드 분석 결과 화면.
class OcrResultScreen extends StatelessWidget {
  // 기존 필드
  final Uint8List? imageBytes;
  final String imageUrl;
  final String productName;
  final String capacity;
  final String rawText;
  final num? confidence;
  final List<String> ingredients;
  final List<String> effects;
  final List<String> usage;
  final List<String> cautions;
  // 신규 — 분석 본체
  final List<IngredientItem> matchedIngredients;
  final List<String> unmatchedIngredients;
  final String trafficLight; // ''/GREEN/YELLOW/ORANGE/RED
  final num? riskScore; // 0~1
  final String summary;
  final List<String> allergyWarnings;
  final List<String> acneWarnings;
  final List<String> highRiskIngredients;
  final List<String> personalizedWarnings;
  final List<String> moisturizingIngredients;
  final List<String> soothingIngredients;

  // 🆕 백엔드가 자동 매칭해 보내주는 제품 정보. 비어 있으면(매칭 실패)
  // 기존 OCR 결과 + 이름 검색 폴백으로 표시.
  final String matchedProductName;
  final String matchedBrandName;
  final String matchedImageUrl;
  final num? matchedPrice;

  const OcrResultScreen({
    super.key,
    this.imageBytes,
    this.imageUrl = '',
    this.productName = '',
    this.capacity = '',
    this.matchedProductName = '',
    this.matchedBrandName = '',
    this.matchedImageUrl = '',
    this.matchedPrice,
    this.rawText = '',
    this.confidence,
    this.ingredients = const [],
    this.effects = const [],
    this.usage = const [],
    this.cautions = const [],
    this.matchedIngredients = const [],
    this.unmatchedIngredients = const [],
    this.trafficLight = '',
    this.riskScore,
    this.summary = '',
    this.allergyWarnings = const [],
    this.acneWarnings = const [],
    this.highRiskIngredients = const [],
    this.personalizedWarnings = const [],
    this.moisturizingIngredients = const [],
    this.soothingIngredients = const [],
  });

  /// 표시용 제품명 — 백엔드 매칭이 있으면 그 정식 이름, 없으면 OCR 추출명.
  String get _displayName =>
      matchedProductName.isNotEmpty ? matchedProductName : productName;

  /// 제품명 아래에 한 줄로 들어가는 부제.
  /// 매칭 성공: "브랜드 · 14,800원" / 가격만 있으면 가격만 / 둘 다 없으면 빈 문자열.
  /// 매칭 실패: 기존 OCR capacity 값(예: "100ml" 또는 "확인 불가").
  String get _subtitleText {
    if (matchedBrandName.isNotEmpty || matchedPrice != null) {
      final parts = <String>[];
      if (matchedBrandName.isNotEmpty) parts.add(matchedBrandName);
      if (matchedPrice != null) parts.add(_formatPrice(matchedPrice!));
      return parts.join(' · ');
    }
    return capacity;
  }

  static String _formatPrice(num p) {
    final i = p.round();
    final s = i.toString();
    final buf = StringBuffer();
    for (var j = 0; j < s.length; j++) {
      if (j > 0 && (s.length - j) % 3 == 0) buf.write(',');
      buf.write(s[j]);
    }
    return '${buf.toString()}원';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 18),
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new, size: 22),
                ),
                const Spacer(),
                const Text(
                  '분석 결과',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 22),
              ],
            ),
            const SizedBox(height: 24),

            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              // 백엔드 matched_product가 image_url을 주면 그걸 직접 쓰고,
              // 없으면 기존 이름 기반 검색으로 폴백.
              child: matchedImageUrl.isNotEmpty
                  ? _MatchedProductImage(url: matchedImageUrl)
                  : _LookupProductImage(
                      productName: productName,
                      fallbackImageUrl: imageUrl,
                      fallbackBytes: imageBytes,
                    ),
            ),

            const SizedBox(height: 24),

            if (_displayName.isNotEmpty) ...[
              Text(
                _displayName,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 22,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
              if (_subtitleText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _subtitleText,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    color: AppColors.textSub,
                  ),
                ),
              ],
              const SizedBox(height: 22),
            ],

            // 5단계 위험도 계기판 — 신호등(아래)과 같은 판단 기준으로 그립니다.
            if (trafficLight.isNotEmpty || riskScore != null) ...[
              _RiskGauge(
                trafficLight: trafficLight,
                riskScore: riskScore,
              ),
              const SizedBox(height: 14),
            ],

            // 신호등 + 요약
            if (trafficLight.isNotEmpty || summary.isNotEmpty) ...[
              _TrafficLightBanner(
                trafficLight: trafficLight,
                riskScore: riskScore,
                summary: summary,
              ),
              const SizedBox(height: 18),
            ],

            if (confidence != null) ...[
              _ConfidenceBadge(value: confidence!.toDouble()),
              const SizedBox(height: 22),
            ],

            // 개인화 경고 — 최우선 표시
            if (personalizedWarnings.isNotEmpty) ...[
              _WarningCallout(
                title: '내 피부에 주의가 필요한 성분',
                items: personalizedWarnings,
                color: AppColors.danger,
                icon: Icons.priority_high_rounded,
              ),
              const SizedBox(height: 16),
            ],

            // 효능 (긍정 정보)
            if (moisturizingIngredients.isNotEmpty ||
                soothingIngredients.isNotEmpty) ...[
              _EfficacyCard(
                moisturizing: moisturizingIngredients,
                soothing: soothingIngredients,
              ),
              const SizedBox(height: 16),
            ],

            // 경고 (알레르기/여드름/고위험)
            if (allergyWarnings.isNotEmpty ||
                acneWarnings.isNotEmpty ||
                highRiskIngredients.isNotEmpty) ...[
              _WarningGroupCard(
                allergy: allergyWarnings,
                acne: acneWarnings,
                highRisk: highRiskIngredients,
              ),
              const SizedBox(height: 16),
            ],

            // 성분 — 플래그 있으면 풍부하게, 없으면 단순 칩
            if (matchedIngredients.isNotEmpty) ...[
              _SectionHeader(
                title: '성분',
                count: matchedIngredients.length +
                    unmatchedIngredients.length,
              ),
              const SizedBox(height: 10),
              _IngredientFlagWrap(
                matched: matchedIngredients,
                unmatched: unmatchedIngredients,
              ),
              const SizedBox(height: 22),
            ] else if (ingredients.isNotEmpty) ...[
              _SectionHeader(title: '성분', count: ingredients.length),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ingredients
                    .map((e) => _SimpleIngredientChip(text: e))
                    .toList(),
              ),
              const SizedBox(height: 22),
            ],

            if (effects.isNotEmpty) ...[
              _BulletSection(
                title: '효능',
                icon: Icons.spa_outlined,
                items: effects,
              ),
              const SizedBox(height: 16),
            ],

            if (usage.isNotEmpty) ...[
              _BulletSection(
                title: '사용법',
                icon: Icons.menu_book_outlined,
                items: usage,
              ),
              const SizedBox(height: 16),
            ],

            if (cautions.isNotEmpty) ...[
              _BulletSection(
                title: '주의사항',
                icon: Icons.warning_amber_rounded,
                items: cautions,
                accentColor: AppColors.danger,
              ),
              const SizedBox(height: 16),
            ],

            if (rawText.isNotEmpty) ...[
              _RawTextTile(text: rawText),
              const SizedBox(height: 18),
            ],

            const SizedBox(height: 6),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('내 사용 제품에 등록했어요.'),
                      duration: Duration(milliseconds: 1000),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '이 제품 등록하기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MainTabScreen(),
                    ),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '홈으로 가기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 34),
          ],
        ),
      ),
    );
  }
}

// --- 위젯들 ---

/// 백엔드 `matched_product.image_url`을 그대로 표시 + "제품 DB 매칭" 배지.
/// 이름 검색이 불필요해 즉시 렌더링 — _LookupProductImage보다 우선 사용.
class _MatchedProductImage extends StatelessWidget {
  final String url;
  const _MatchedProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ProductImage(
          url: url,
          width: double.infinity,
          height: 200,
          borderRadius: 0,
        ),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined,
                    size: 11, color: Colors.white),
                SizedBox(width: 3),
                Text(
                  '제품 DB 매칭',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 추출한 제품명으로 제품 DB를 검색해서, 매칭되는 상품의 등록 이미지를
/// 우선 보여줍니다. 매칭 실패 시 OCR이 캡처한 이미지(URL → bytes)로 폴백.
class _LookupProductImage extends StatefulWidget {
  final String productName;
  final String fallbackImageUrl;
  final Uint8List? fallbackBytes;

  const _LookupProductImage({
    required this.productName,
    required this.fallbackImageUrl,
    required this.fallbackBytes,
  });

  @override
  State<_LookupProductImage> createState() => _LookupProductImageState();
}

class _LookupProductImageState extends State<_LookupProductImage> {
  String? _matchedImageUrl;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s\(\)\[\]·,/.\-]+'), '');

  Future<void> _lookup() async {
    final name = widget.productName.trim();
    if (name.isEmpty) return;
    setState(() => _searching = true);
    try {
      final data = await ProductService.search(name);
      final list = listOf(data).map(normalizeProduct).toList();
      if (list.isEmpty) return;

      final wantedKey = _norm(name);
      String? best;

      // 1) 이름 정규화 후 한쪽이 다른쪽을 포함하면 매칭으로 인정.
      for (final p in list) {
        final url = '${p['imageUrl'] ?? ''}';
        if (url.isEmpty) continue;
        final dbKey = _norm('${p['name'] ?? ''}');
        if (dbKey.isEmpty) continue;
        if (dbKey.contains(wantedKey) || wantedKey.contains(dbKey)) {
          best = url;
          break;
        }
      }

      // 2) 그래도 못 찾으면 이미지 있는 첫 결과로 폴백.
      if (best == null) {
        for (final p in list) {
          final url = '${p['imageUrl'] ?? ''}';
          if (url.isNotEmpty) {
            best = url;
            break;
          }
        }
      }

      if (best != null && best.isNotEmpty && mounted) {
        setState(() => _matchedImageUrl = best);
      }
    } catch (_) {
      // best-effort; silently fall back to OCR image.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbUrl = _matchedImageUrl;
    if (dbUrl != null && dbUrl.isNotEmpty) {
      return Stack(
        children: [
          ProductImage(
            url: dbUrl,
            width: double.infinity,
            height: 200,
            borderRadius: 0,
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined,
                      size: 11, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    '제품 DB 매칭',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // DB 매칭 없음 → 기존 우선순위 유지: OCR URL → bytes → placeholder.
    if (widget.fallbackImageUrl.isNotEmpty) {
      return ProductImage(
        url: widget.fallbackImageUrl,
        width: double.infinity,
        height: 200,
        borderRadius: 0,
      );
    }
    if (widget.fallbackBytes != null) {
      return Image.memory(
        widget.fallbackBytes!,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    return Container(
      height: 200,
      color: const Color(0xFFF5F7FA),
      alignment: Alignment.center,
      child: _searching
          ? const CircularProgressIndicator()
          : const Icon(Icons.image_outlined,
              size: 36, color: AppColors.textSub),
    );
  }
}

// 5단계 추천 게이지 — 내 피부 기준 추천/비추천 판단.
const List<Color> _gaugeColors = [
  Color(0xFF34C77B), // 매우 추천
  Color(0xFF9BD24F), // 추천
  Color(0xFFFFD13B), // 보통
  Color(0xFFFF9F40), // 비추천
  Color(0xFFFF5C5C), // 강력 비추천
];
const List<String> _gaugeLabels = ['매우 추천', '추천', '보통', '비추천', '강력 비추천'];
const List<int> _recommendPercents = [95, 80, 60, 35, 15];
const List<String> _gaugeDescriptions = [
  '내 피부에 매우 잘 맞아요. 안심하고 써도 좋아요.',
  '내 피부에 잘 맞는 편이에요.',
  '일부 성분은 한 번 더 확인하고 써 주세요.',
  '내 피부에 자극될 수 있어 신중히 써 주세요.',
  '자극 가능성이 높아 다른 제품을 고려해 보세요.',
];

class _RiskGauge extends StatelessWidget {
  /// 백엔드의 신호등 색 — 게이지 레벨/라벨/색상의 **권위 있는** 기준.
  final String trafficLight;

  /// 백엔드 내부 위험도 점수 (스케일이 일정하지 않을 수 있음). 라벨에 참고치로만
  /// 노출하고, 게이지 위치는 [trafficLight]에서 결정.
  final num? riskScore;

  const _RiskGauge({required this.trafficLight, required this.riskScore});

  /// traffic_light → 5단계 게이지 레벨 매핑.
  /// 백엔드 신호등은 4단계라 "매우 안전"은 risk_score가 낮은 GREEN일 때만 사용.
  int get _levelIndex {
    final key = trafficLight.toUpperCase();
    switch (key) {
      case 'GREEN':
        // GREEN 내에서 매우 낮은 score면 level 0, 아니면 level 1.
        if (riskScore != null && riskScore!.toDouble() <= 0.2) return 0;
        return 1;
      case 'YELLOW':
        return 2;
      case 'ORANGE':
        return 3;
      case 'RED':
        return 4;
      default:
        // traffic_light 누락 — score 기반 폴백 (0~1 가정).
        final s = (riskScore ?? 0).toDouble();
        return (s.clamp(0.0, 1.0) * 5).floor().clamp(0, 4);
    }
  }

  /// 바늘 위치: 해당 레벨 세그먼트 중앙으로 스냅. (스케일 추측 위험 없이 안정.)
  double get _needlePosition {
    const segmentSize = 1.0 / 5;
    return _levelIndex * segmentSize + segmentSize / 2;
  }

  @override
  Widget build(BuildContext context) {
    final level = _levelIndex;
    final color = _gaugeColors[level];
    final label = _gaugeLabels[level];
    final description = _gaugeDescriptions[level];
    final percent = _recommendPercents[level];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            height: 80,
            child: CustomPaint(
              painter: _GaugePainter(progress: _needlePosition),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                          children: [
                            TextSpan(
                              text: '$percent',
                              style: const TextStyle(fontSize: 15),
                            ),
                            const TextSpan(text: '% 추천'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textSub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress; // 0.0 ~ 1.0

  _GaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.18;
    final radius = math.min(size.width / 2, size.height) - stroke / 2 - 6;
    final center = Offset(size.width / 2, size.height - 6);
    final rect = Rect.fromCircle(center: center, radius: radius);

    const totalSweep = math.pi;
    const startAngle = math.pi;
    const segmentSweep = totalSweep / 5;
    const gap = 0.03;

    for (var i = 0; i < 5; i++) {
      final paint = Paint()
        ..color = _gaugeColors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        startAngle + i * segmentSweep + gap / 2,
        segmentSweep - gap,
        false,
        paint,
      );
    }

    final p = progress.clamp(0.0, 1.0);
    final needleAngle = startAngle + totalSweep * p;
    final tipLength = radius - stroke / 2 - 6;
    final tailLength = stroke * 0.45;

    final tip = Offset(
      center.dx + tipLength * math.cos(needleAngle),
      center.dy + tipLength * math.sin(needleAngle),
    );
    final tail = Offset(
      center.dx - tailLength * math.cos(needleAngle),
      center.dy - tailLength * math.sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = AppColors.textMain
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(tail, tip, needlePaint);
    canvas.drawCircle(center, 5.5, Paint()..color = AppColors.textMain);
    canvas.drawCircle(center, 2.4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.progress != progress;
}

const _trafficColors = {
  'GREEN': Color(0xFF34C77B),
  'YELLOW': Color(0xFFFFD13B),
  'ORANGE': Color(0xFFFF9F40),
  'RED': Color(0xFFFF5C5C),
};

const _trafficLabels = {
  'GREEN': '추천',
  'YELLOW': '보통',
  'ORANGE': '비추천',
  'RED': '강력 비추천',
};

const _trafficRecommendPercents = {
  'GREEN': 85,
  'YELLOW': 60,
  'ORANGE': 35,
  'RED': 15,
};

class _TrafficLightBanner extends StatelessWidget {
  final String trafficLight;
  final num? riskScore;
  final String summary;

  const _TrafficLightBanner({
    required this.trafficLight,
    required this.riskScore,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final key = trafficLight.toUpperCase();
    final color = _trafficColors[key] ?? AppColors.primary;
    final label = _trafficLabels[key] ?? '분석 완료';
    final recommendPct = _trafficRecommendPercents[key];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              if (recommendPct != null)
                Text(
                  '$recommendPct% 추천',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              summary,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                height: 1.5,
                color: AppColors.textMain,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double value;

  const _ConfidenceBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    final color = value >= 0.85
        ? const Color(0xFF34C77B)
        : value >= 0.6
            ? const Color(0xFFFFA340)
            : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'OCR 신뢰도 $pct%',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCallout extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  final IconData icon;

  const _WarningCallout({
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map((e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color),
                      ),
                      child: Text(
                        e,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _WarningGroupCard extends StatelessWidget {
  final List<String> allergy;
  final List<String> acne;
  final List<String> highRisk;

  const _WarningGroupCard({
    required this.allergy,
    required this.acne,
    required this.highRisk,
  });

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF9F40);
    final red = AppColors.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: Color(0xFFFF9F40)),
              SizedBox(width: 6),
              Text(
                '확인이 필요한 성분',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          if (highRisk.isNotEmpty) ...[
            const SizedBox(height: 10),
            _WarnGroup(label: '고위험', items: highRisk, color: red),
          ],
          if (allergy.isNotEmpty) ...[
            const SizedBox(height: 10),
            _WarnGroup(label: '알레르기', items: allergy, color: orange),
          ],
          if (acne.isNotEmpty) ...[
            const SizedBox(height: 10),
            _WarnGroup(label: '여드름 주의', items: acne, color: orange),
          ],
        ],
      ),
    );
  }
}

class _WarnGroup extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color color;

  const _WarnGroup({
    required this.label,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      e,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _EfficacyCard extends StatelessWidget {
  final List<String> moisturizing;
  final List<String> soothing;

  const _EfficacyCard({
    required this.moisturizing,
    required this.soothing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFBF4),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF34C77B).withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.eco_outlined, size: 18, color: Color(0xFF34C77B)),
              SizedBox(width: 6),
              Text(
                '도움이 되는 성분',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          if (moisturizing.isNotEmpty) ...[
            const SizedBox(height: 10),
            _EfficacyGroup(
              label: '보습',
              icon: Icons.water_drop_outlined,
              items: moisturizing,
              color: const Color(0xFF2B8AC9),
            ),
          ],
          if (soothing.isNotEmpty) ...[
            const SizedBox(height: 10),
            _EfficacyGroup(
              label: '진정',
              icon: Icons.spa_outlined,
              items: soothing,
              color: const Color(0xFF34C77B),
            ),
          ],
        ],
      ),
    );
  }
}

class _EfficacyGroup extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> items;
  final Color color;

  const _EfficacyGroup({
    required this.label,
    required this.icon,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items
                .map((e) => Text(
                      e,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12.5,
                        color: AppColors.textMain,
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSub,
            ),
          ),
        ],
      ],
    );
  }
}

class _IngredientFlagWrap extends StatelessWidget {
  final List<IngredientItem> matched;
  final List<String> unmatched;

  const _IngredientFlagWrap({
    required this.matched,
    required this.unmatched,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...matched.map((i) => _FlaggedChip(item: i)),
        ...unmatched.map(
          (name) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              name,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSub,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlaggedChip extends StatelessWidget {
  final IngredientItem item;

  const _FlaggedChip({required this.item});

  @override
  Widget build(BuildContext context) {
    // 우선순위: warning > benefit > neutral.
    final warning = item.hasWarning;
    final benefit = item.hasBenefit;
    final color = warning
        ? const Color(0xFFFF9F40)
        : benefit
            ? const Color(0xFF34C77B)
            : AppColors.primaryDark;
    final bg = warning
        ? const Color(0xFFFF9F40).withValues(alpha: 0.12)
        : benefit
            ? const Color(0xFF34C77B).withValues(alpha: 0.12)
            : AppColors.primaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.allergy || item.irritant)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child:
                  Icon(Icons.warning_amber_rounded, size: 12, color: color),
            )
          else if (item.acneCaution)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.error_outline, size: 12, color: color),
            )
          else if (item.moisturizing)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.water_drop_outlined, size: 12, color: color),
            )
          else if (item.soothing)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.spa_outlined, size: 12, color: color),
            ),
          Text(
            item.name,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleIngredientChip extends StatelessWidget {
  final String text;
  const _SimpleIngredientChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final Color? accentColor;

  const _BulletSection({
    required this.title,
    required this.icon,
    required this.items,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13.5,
                        height: 1.5,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RawTextTile extends StatelessWidget {
  final String text;
  const _RawTextTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Text(
            '원본 OCR 텍스트',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          children: [
            SelectableText(
              text,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
