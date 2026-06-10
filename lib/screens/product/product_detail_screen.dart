import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';
import '../../data/activity_store.dart';
import '../../data/services/parsing.dart';
import '../../data/services/recommendation_service.dart';
import '../../data/services/review_service.dart';
import '../../widgets/common/product_image.dart';
import '../review/product_reviews_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late bool _isLiked;

  // List endpoints don't include avg_rating / review_count / 대표 리뷰. 상세
  // 화면 진입 시 리뷰 API를 한 번 호출해 채웁니다.
  double? _avgRating;
  int? _reviewCount;
  Map<String, dynamic>? _topReview;

  @override
  void initState() {
    super.initState();
    _isLiked = LikedProductsStore.contains(widget.product);

    // Log the product view (best-effort; only when logged in, never blocks).
    final id = widget.product['id'];
    if (id != null && AuthSession.isLoggedIn) {
      ReviewService.logProductView(id).catchError((_) => null);
    }

    if (id != null) _loadReviews(id);
  }

  Future<void> _loadReviews(Object productId) async {
    try {
      final data = await ReviewService.byProduct(productId);
      if (!mounted) return;
      final m = mapOf(data);
      final reviews = listOf(data);
      setState(() {
        _avgRating = (m['avg_rating'] as num?)?.toDouble();
        _reviewCount = (m['count'] as num?)?.toInt() ?? reviews.length;
        // 대표 리뷰: 가장 평점 높은 리뷰 → 같은 평점이면 최신순.
        if (reviews.isNotEmpty) {
          reviews.sort((a, b) {
            final ra = (a['rating'] as num?)?.toInt() ?? 0;
            final rb = (b['rating'] as num?)?.toInt() ?? 0;
            if (ra != rb) return rb.compareTo(ra);
            return '${b['created_at'] ?? ''}'
                .compareTo('${a['created_at'] ?? ''}');
          });
          _topReview = reviews.first;
        }
      });
    } on ApiException {
      // 조용히 폴백 — 카드는 그대로 비어있음.
    }
  }

  void _openAllReviews() {
    final productId = widget.product['id'];
    if (productId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductReviewsScreen(
          productId: productId,
          productName: '${widget.product['name'] ?? ''}',
          brand: '${widget.product['brand'] ?? ''}',
        ),
      ),
    );
  }

  Future<void> _openReviewSheet() async {
    if (!AuthSession.isLoggedIn) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('로그인 후 리뷰를 작성할 수 있어요.')),
        );
      return;
    }
    final productId = widget.product['id'];
    if (productId == null) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ReviewWriteSheet(
        productId: productId,
        productName: '${widget.product['name'] ?? ''}',
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('리뷰가 등록됐어요.')),
        );
      // 새로 등록된 리뷰가 대표 리뷰 자리와 카운트에 반영되도록 재로딩.
      _loadReviews(productId);
    }
  }

  void _toggleLike() {
    setState(() {
      LikedProductsStore.toggle(widget.product);
      _isLiked = LikedProductsStore.contains(widget.product);
    });

    // Sync with the server (best-effort; local state already updated).
    final id = widget.product['id'];
    if (id != null && AuthSession.isLoggedIn) {
      RecommendationService.toggleLike(id).catchError((_) => null);
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(_isLiked ? '좋아요 목록에 추가했어요.' : '좋아요를 해제했어요.'),
          duration: const Duration(milliseconds: 1000),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final ingredients =
        (product['ingredients'] as List?)?.map((e) => '$e').toList() ??
            <String>[];

    return Scaffold(
      backgroundColor: AppColors.card,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _openReviewSheet,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(
                '리뷰쓰기',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            children: [
              const SizedBox(height: 18),

              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggleLike,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 26,
                        color: _isLiked
                            ? const Color(0xFFFF5C5C)
                            : AppColors.textMain,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              ProductImage(
                url: product['imageUrl'],
                width: double.infinity,
                height: 220,
                borderRadius: 28,
                iconSize: 90,
              ),

              const SizedBox(height: 28),

              Text(
                product['brand'],
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: AppColors.textSub,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                product['name'],
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                product['price'],
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 14),

              Builder(builder: (_) {
                // 우선순위: 서버에서 받은 _avgRating/_reviewCount → 리스트 응답의
                // rating/reviewCount → '0'.
                final ratingText = _avgRating != null
                    ? _avgRating!.toStringAsFixed(1)
                    : '${product['rating'] ?? '0'}';
                final countText = _reviewCount != null
                    ? '$_reviewCount'
                    : '${product['reviewCount'] ?? '0'}';
                return Row(
                  children: [
                    const Icon(Icons.star,
                        color: Color(0xFFFFCC00), size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '$ratingText · 리뷰 $countText개',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                );
              }),

              const SizedBox(height: 28),

              const _SectionTitle('주요 성분'),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ingredients.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              const _SectionTitle('대표 리뷰'),
              const SizedBox(height: 12),

              Builder(builder: (_) {
                final topText = (_topReview != null
                        ? '${_topReview!['review_text'] ?? _topReview!['content'] ?? ''}'
                        : '')
                    .trim();
                final fallback = '${product['review'] ?? ''}'.trim();
                final body = topText.isNotEmpty
                    ? topText
                    : (fallback.isNotEmpty
                        ? fallback
                        : '아직 등록된 리뷰가 없어요.');
                final nickname = _topReview != null
                    ? '${_topReview!['nickname'] ?? _topReview!['user_nickname'] ?? '익명'}'
                    : '';
                final rating =
                    (_topReview?['rating'] as num?)?.toInt() ?? 0;
                final hasReview = _topReview != null;
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasReview) ...[
                        Row(
                          children: [
                            ...List.generate(5, (i) {
                              return Icon(
                                i < rating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 16,
                                color: const Color(0xFFFFC93C),
                              );
                            }),
                            const SizedBox(width: 8),
                            Text(
                              nickname,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSub,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        body,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          height: 1.5,
                          color: hasReview
                              ? AppColors.textMain
                              : AppColors.textSub,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _openAllReviews,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '리뷰 ${_reviewCount ?? product['reviewCount'] ?? '0'}개 모두 보기',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// 별점 + 내용 + 등록 버튼을 가진 모달 시트. 등록 성공 시 `true`를 반환.
class _ReviewWriteSheet extends StatefulWidget {
  final Object productId;
  final String productName;

  const _ReviewWriteSheet({
    required this.productId,
    required this.productName,
  });

  @override
  State<_ReviewWriteSheet> createState() => _ReviewWriteSheetState();
}

class _ReviewWriteSheetState extends State<_ReviewWriteSheet> {
  int _rating = 0;
  final _contentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_rating == 0) {
      _showSnack('별점을 선택해 주세요.');
      return;
    }
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showSnack('리뷰 내용을 입력해 주세요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ReviewService.create(
        productId: widget.productId,
        rating: _rating,
        content: content,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '리뷰 쓰기',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: AppColors.textSub,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final n = i + 1;
                final on = n <= _rating;
                return GestureDetector(
                  onTap: () => setState(() => _rating = n),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      on
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: on
                          ? const Color(0xFFFFCC00)
                          : AppColors.border,
                      size: 38,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '사용 후기를 적어주세요.',
              filled: true,
              fillColor: const Color(0xFFF7FAFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
              hintStyle: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                color: AppColors.textSub,
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      '등록',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textMain,
      ),
    );
  }
}
