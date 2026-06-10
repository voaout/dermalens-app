import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api.dart';
import '../../core/network/api_client.dart';
import '../../data/services/chatbot_service.dart';
import '../../data/services/parsing.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/product_image.dart';
import '../../widgets/glass/glass_card.dart';
import '../beta/ingredient_register_screen.dart';
import '../category/category_screen.dart';
import '../mypage/allergy_edit_screen.dart';
import '../mypage/inquiry_screen.dart';
import '../mypage/my_reviews_screen.dart';
import '../mypage/product_request_screen.dart';
import '../mypage/satisfaction_screen.dart';
import '../product/product_detail_screen.dart';
import '../scan/widgets/image_source_sheet.dart';
import '../survey/survey_screen.dart';
import '../vanity/my_vanity_screen.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

/// 채팅 메시지 — 사용자 발화 or 봇 응답.
/// 봇 응답의 카드/링크는 챗봇 서버가 보낸 components 배열을 그대로 들고 있다.
class _Message {
  final bool isUser;
  final String text;
  final String? intent;
  final num? score;
  final List<Map<String, dynamic>> components;

  const _Message._({
    required this.isUser,
    required this.text,
    this.intent,
    this.score,
    this.components = const [],
  });

  factory _Message.user(String text) =>
      _Message._(isUser: true, text: text);

  factory _Message.bot(
    String text, {
    String? intent,
    num? score,
    List<Map<String, dynamic>> components = const [],
  }) =>
      _Message._(
        isUser: false,
        text: text,
        intent: intent,
        score: score,
        components: components,
      );
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];

  /// 마지막 봇 응답에서 받은 quickReplies — 입력창 위 칩으로 표시.
  List<String> _quickReplies = [];

  /// 사용자가 입력 중일 때 백엔드 성분 DB로 자동완성한 결과.
  /// 입력이 있는 동안에는 quickReplies보다 우선해서 칩 바에 표시.
  List<String> _autocomplete = [];
  Timer? _autocompleteTimer;

  bool _sending = false;
  Object? _sessionId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
    // 최소한의 환영 메시지. 그 외 안내·칩·카드는 모두 챗봇 서버 응답에서 온다.
    _messages.add(_Message.bot(
      '안녕하세요. DermaLens 챗봇입니다.\n무엇을 도와드릴까요?',
    ));
  }

  @override
  void dispose() {
    _controller.removeListener(_onInputChanged);
    _autocompleteTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- 자동완성 ---

  void _onInputChanged() {
    final value = _controller.text.trim();
    _autocompleteTimer?.cancel();
    if (value.isEmpty) {
      if (_autocomplete.isNotEmpty) {
        setState(() => _autocomplete = const []);
      }
      return;
    }
    // 1글자부터 검색 — 한글 IME 합성이 끝난 음절(예: "알")부터 즉시 추천.
    _autocompleteTimer = Timer(const Duration(milliseconds: 220), () async {
      try {
        final data = await ApiClient.I.get(
          AnalysisApi.ingredientsSearch,
          query: {'q': value, 'limit': '8'},
        );
        if (!mounted) return;

        // 응답 형태가 두 가지 모두 가능하도록 방어적으로 파싱:
        //   1) 새 형태(현재): { "ingredients": ["문자열1", "문자열2", ...] }
        //   2) 옛 형태(객체):  [{ "ingredient_name_kr": "...", ... }, ...]
        final names = <String>[];
        final body = mapOf(data);
        final raw = body['ingredients'] ?? body['results'] ?? data;
        if (raw is List) {
          for (final item in raw) {
            if (item is String && item.isNotEmpty) {
              names.add(item);
            } else if (item is Map) {
              final s = str(item.cast<String, dynamic>(),
                  ['ingredient_name_kr', 'name_kr', 'name']);
              if (s.isNotEmpty) names.add(s);
            }
          }
        }

        // 추천 칩은 "{성분명} 알려줘" 형식으로 — 탭하면 그대로 챗봇에 전송됨.
        final chips = names
            .take(8)
            .map((s) => '$s 알려줘')
            .toList();
        setState(() => _autocomplete = chips);
      } catch (_) {
        // 자동완성 실패는 silent — UX 보조 기능.
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // --- 메시지 전송 ---

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_Message.user(text));
      _quickReplies = [];
      _autocomplete = const [];
      _sending = true;
    });
    _autocompleteTimer?.cancel();
    _controller.clear();
    _scrollToBottom();

    try {
      final res = await ChatbotService.chat(text, sessionId: _sessionId);

      final session = res['session_id'] ?? res['id'];
      if (session != null) _sessionId = session;

      final reply = str(
        res,
        ['message', 'reply', 'response', 'answer'],
        fallback: '죄송해요, 답변을 가져오지 못했어요.',
      );
      final intent = str(res, ['intent']);
      final score = (res['score'] ?? res['confidence']) as num?;
      final components = listOf(res['components']);
      final quickReplies = listOf(res['quickReplies'])
          .map((e) => e.toString())
          .toList();
      // listOf가 List<Map>만 반환하므로 원본 List<String>은 직접 추출.
      final rawQuick = res['quickReplies'] ?? res['quick_replies'];
      final quickStrings = rawQuick is List
          ? rawQuick.whereType<String>().toList()
          : quickReplies;

      if (!mounted) return;
      setState(() {
        _messages.add(_Message.bot(
          reply,
          intent: intent.isEmpty ? null : intent,
          score: score,
          components: components,
        ));
        _quickReplies = quickStrings;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Message.bot('지금은 답변을 드리기 어려워요. (${e.message})'));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  // --- 컴포넌트 액션 ---

  void _onComponentAction(Map<String, dynamic> c) {
    final type = str(c, ['type']).toLowerCase();
    if (type == 'link') {
      _openPageLink(c);
      return;
    }
    // 카드: productId가 있으면 상품 상세로, 없으면 성분 상세 다이얼로그.
    final productId = c['productId'] ?? c['product_id'];
    if (productId != null) {
      _openProductFromCard(c);
    } else {
      _openIngredientDetail(c);
    }
  }

  void _openProductFromCard(Map<String, dynamic> c) {
    final product = <String, dynamic>{
      'id': c['productId'] ?? c['product_id'],
      'name': str(c, ['title', 'name']),
      'brand': str(c, ['subtitle', 'brand']),
      'imageUrl': str(c, ['imageUrl', 'image_url']),
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  void _openOcrPicker() {
    pickImageForOcr(context, ImageSource.gallery);
  }

  /// 링크 컴포넌트의 CTA → target에 맞는 화면 push.
  ///
  /// 챗봇 서버가 보내는 target 키는 표기가 다양하므로(영문 enum, 한글, 공백/
  /// 언더스코어 혼용 등), 정규화 후 여러 alias 그룹에 매칭한다.
  void _openPageLink(Map<String, dynamic> pageLink) {
    final raw = str(pageLink, ['target', 'page', 'route', 'name']);
    final target = raw
        .toUpperCase()
        .replaceAll(' ', '_')
        .replaceAll('(', '_')
        .replaceAll(')', '');

    void push(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    // 피부 진단 / 설문
    const skinTest = {
      'SKIN_TYPE_TEST', 'SKIN_TEST', 'SKINTYPE_TEST',
      'SKIN_DIAGNOSIS', 'DIAGNOSIS', 'SURVEY',
      '피부_타입_진단', '피부_진단', '피부진단',
    };
    if (skinTest.contains(target)) {
      push(const SurveyScreen());
      return;
    }

    // OCR / 성분 사진 분석
    const ocr = {
      'OCR_SCAN', 'OCR', 'SCAN',
      '성분_사진_분석_OCR', '성분_사진_분석', '성분사진분석', '사진_분석',
    };
    if (ocr.contains(target)) {
      _openOcrPicker();
      return;
    }

    // 카테고리 / 제품 페이지
    const category = {
      'PRODUCT_PAGE', 'CATEGORY', 'PRODUCT_LIST', 'PRODUCTS',
      '제품_페이지', '제품페이지', '카테고리',
    };
    if (category.contains(target)) {
      push(const CategoryScreen());
      return;
    }

    // 화장대 / 루틴
    const routine = {
      'ROUTINE', 'VANITY', 'MY_VANITY',
      '바르는_루틴', '루틴', '화장대', '나의_화장대',
    };
    if (routine.contains(target)) {
      push(const MyVanityScreen());
      return;
    }

    // 리뷰
    const review = {
      'REVIEW_PAGE', 'REVIEW', 'MY_REVIEWS', 'REVIEWS',
      '리뷰_페이지', '리뷰', '내_리뷰',
    };
    if (review.contains(target)) {
      push(const MyReviewsScreen());
      return;
    }

    // 알레르기 / 기피 성분
    const allergy = {
      'ALLERGY_MANAGEMENT', 'ALLERGY', 'ALLERGIES',
      '알레르기_관리', '알레르기', '기피_성분',
    };
    if (allergy.contains(target)) {
      push(const AllergyEditScreen());
      return;
    }

    // 베타 성분 등록
    const register = {
      'PRODUCT_REGISTER', 'INGREDIENT_REGISTER', 'BETA_REGISTER',
      '제품_등록', '성분_등록', '베타_등록',
    };
    if (register.contains(target)) {
      push(const IngredientRegisterScreen());
      return;
    }

    // 1:1 문의
    const inquiry = {
      'INQUIRY', 'CONTACT', 'SUPPORT',
      '문의하기', '문의', '1:1_문의',
    };
    if (inquiry.contains(target)) {
      push(const InquiryScreen());
      return;
    }

    // 제품 신고 / 등록 요청
    const report = {
      'PRODUCT_REPORT', 'PRODUCT_REQUEST', 'REPORT',
      '제품_신고', '제품_요청', '신고',
    };
    if (report.contains(target)) {
      push(const ProductRequestScreen());
      return;
    }

    // 앱 만족도
    const satisfaction = {
      'SATISFACTION', 'FEEDBACK',
      '앱_만족도_평가', '만족도', '피드백',
    };
    if (satisfaction.contains(target)) {
      push(const SatisfactionScreen());
      return;
    }

    // 매칭 실패 — 콘솔에 찍어서 어떤 target이 왔는지 디버깅 가능하게.
    debugPrint('[Chatbot] Unmatched target: raw="$raw"  normalized="$target"');
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text('아직 연결되지 않은 페이지예요. ($target)')));
  }

  void _openIngredientDetail(Map<String, dynamic> ingredient) {
    final nameKr = str(ingredient,
        ['title', 'name', 'ingredient_name_kr', 'name_kr']);
    final nameEn =
        str(ingredient, ['subtitle', 'name_en', 'ingredient_name_en']);
    final desc = str(
      ingredient,
      ['description', 'desc', 'detail'],
      fallback: '상세 효능 정보는 준비 중이에요. 사용 전 패치 테스트를 권장드려요.',
    );

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          nameKr.isEmpty ? '성분' : nameKr,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nameEn.isNotEmpty) ...[
              Text(
                nameEn,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: AppColors.textSub,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              desc,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textMain,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgGradientTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgGradientTop, AppColors.bgGradientBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const _ChatHeader(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (_sending && i == _messages.length) {
                      return const _TypingBubble();
                    }
                    return _MessageBubble(
                      message: _messages[i],
                      onAction: _onComponentAction,
                    );
                  },
                ),
              ),
              // 입력 중이면 자동완성, 아니면 마지막 봇 응답의 quickReplies.
              Builder(
                builder: (_) {
                  final chips =
                      _autocomplete.isNotEmpty ? _autocomplete : _quickReplies;
                  if (chips.isEmpty) return const SizedBox.shrink();
                  return _ChipBar(chips: chips, onTap: _send);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: AppColors.glassFill,
                          border: Border.all(color: AppColors.glassBorder),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _send,
                          enabled: !_sending,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '질문을 입력해주세요',
                            isCollapsed: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _sending ? null : () => _send(_controller.text),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _sending
                                ? [Colors.grey.shade400, Colors.grey.shade500]
                                : const [
                                    AppColors.primary,
                                    Color(0xFF4D8CDF),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          '전송',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== sub-widgets ===================

class _ChatHeader extends StatelessWidget {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
    // 다른 탭들과 동일한 헤더 위치: horizontal 24, top 24.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppLogo(fontSize: 22, goHomeOnTap: false),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: const Text(
              'AI 챗봇',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '피부·성분 기반 AI',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSub.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipBar extends StatelessWidget {
  final List<String> chips;
  final ValueChanged<String> onTap;

  const _ChipBar({required this.chips, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          return _QuickChip(label: chips[i], onTap: () => onTap(chips[i]));
        },
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              border: Border.all(color: AppColors.glassBorder, width: 0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const _DotsLoader(),
          ),
        ],
      ),
    );
  }
}

class _DotsLoader extends StatefulWidget {
  const _DotsLoader();

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        Widget dot(int i) {
          final phase = (_c.value + i * 0.2) % 1.0;
          final fade = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
          final opacity = 0.3 + fade * 0.7;
          return Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }

        return SizedBox(
          width: 32,
          height: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(0), dot(1), dot(2)],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  final ValueChanged<Map<String, dynamic>> onAction;

  const _MessageBubble({required this.message, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : AppColors.glassFillStrong,
                    border: Border.all(
                      color: isUser
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.glassBorder,
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      height: 1.5,
                      fontWeight:
                          isUser ? FontWeight.w700 : FontWeight.w500,
                      color: isUser ? AppColors.primaryDark : AppColors.textMain,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 챗봇 서버가 보낸 components를 순서대로 카드로 렌더링.
          for (final c in message.components) ...[
            const SizedBox(height: 10),
            _ComponentCard(data: c, onTap: () => onAction(c)),
          ],

          // intent / score 디버그 라인 (응답 신뢰도 확인용)
          if (!isUser && message.intent != null) ...[
            const SizedBox(height: 6),
            Text(
              'intent: ${message.intent}${message.score != null ? ' / score: ${_formatScore(message.score!)}' : ''}',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11,
                color: AppColors.textSub,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatScore(num s) {
    if (s == s.toInt()) return '${s.toInt()}';
    return s.toStringAsFixed(2);
  }
}

/// 챗봇 응답의 components 배열의 한 항목을 카드로 렌더링.
///
/// 지원 타입:
///  - type: "card"  → 제품/성분 카드 (productId가 있으면 상품, 없으면 성분)
///  - type: "link"  → 페이지 이동 카드 (target으로 화면 push)
class _ComponentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ComponentCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = str(data, ['type']).toLowerCase();
    final title = str(data, ['title', 'name']);
    final subtitle = str(data, ['subtitle', 'brand', 'name_en']);
    final description = str(data, ['description', 'desc']);
    final imageUrl = str(data, ['imageUrl', 'image_url']);
    final hasProduct = (data['productId'] ?? data['product_id']) != null;
    final isLink = type == 'link';
    final riskLevel = str(data, ['riskLevel', 'risk_level']).toUpperCase();
    final buttonText = str(
      data,
      ['buttonText', 'cta_label', 'label'],
      fallback: isLink ? '바로 가기' : '자세히 보기',
    );

    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty && hasProduct) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ProductImage(
                    url: imageUrl,
                    width: 56,
                    height: 56,
                    borderRadius: 0,
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isLink
                        ? Icons.link
                        : (hasProduct
                            ? Icons.shopping_bag_outlined
                            : Icons.science_outlined),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11.5,
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (riskLevel.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RiskBadge(level: riskLevel),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                height: 1.5,
                color: AppColors.textMain,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.glassFill,
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  /// "LOW" / "MEDIUM" / "HIGH" 또는 숫자 문자열 — 백엔드 다양성 대응.
  final String level;
  const _RiskBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  static (String, Color) _resolve(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':
      case '1':
      case 'SAFE':
        return ('위험도 낮음', const Color(0xFF34C77B));
      case 'MEDIUM':
      case 'MID':
      case '2':
        return ('위험도 보통', const Color(0xFFFFA340));
      case 'HIGH':
      case '3':
      case 'DANGER':
        return ('위험도 높음', const Color(0xFFFF5C5C));
      default:
        return ('위험도 $level', AppColors.textSub);
    }
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}
