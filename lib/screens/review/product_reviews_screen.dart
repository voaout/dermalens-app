import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/services/parsing.dart';
import '../../data/services/review_service.dart';

/// 올리브영 스타일 리뷰 페이지.
///
/// 진입: 상품 상세에서 "리뷰 더보기" 탭 → product_id 전달.
/// 데이터: `GET /api/review/product/{product_id}/?sort=latest|rating`.
class ProductReviewsScreen extends StatefulWidget {
  final Object productId;
  final String productName;
  final String brand;

  const ProductReviewsScreen({
    super.key,
    required this.productId,
    this.productName = '',
    this.brand = '',
  });

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

enum _SortMode { useful, latest, ratingHigh, ratingLow }

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  bool _loading = true;
  String? _error;

  double _avgRating = 0;
  int _totalCount = 0;
  List<Map<String, dynamic>> _reviews = [];
  _SortMode _sort = _SortMode.useful;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ReviewService.byProduct(widget.productId);
      if (!mounted) return;
      final m = mapOf(data);
      _avgRating =
          (m['avg_rating'] as num?)?.toDouble() ?? _computeAvg(_reviews);
      _totalCount = (m['count'] as num?)?.toInt() ?? listOf(data).length;
      _reviews = listOf(data);
      _applySort();
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  double _computeAvg(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return 0;
    final sum = list.fold<num>(0, (a, r) => a + ((r['rating'] as num?) ?? 0));
    return sum / list.length;
  }

  void _applySort() {
    switch (_sort) {
      case _SortMode.latest:
        _reviews.sort((a, b) =>
            '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));
        break;
      case _SortMode.ratingHigh:
        _reviews.sort((a, b) =>
            ((b['rating'] as num?) ?? 0).compareTo((a['rating'] as num?) ?? 0));
        break;
      case _SortMode.ratingLow:
        _reviews.sort((a, b) =>
            ((a['rating'] as num?) ?? 0).compareTo((b['rating'] as num?) ?? 0));
        break;
      case _SortMode.useful:
        // 백엔드에 useful_count가 없어서 일단 최신순으로 폴백.
        _reviews.sort((a, b) =>
            '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));
        break;
    }
  }

  void _setSort(_SortMode mode) {
    setState(() {
      _sort = mode;
      _applySort();
    });
  }

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    '리뷰',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              color: AppColors.textSub,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                            children: [
                              _SummaryHeader(
                                avg: _avgRating,
                                count: _totalCount,
                              ),
                              const SizedBox(height: 22),
                              _SortBar(
                                current: _sort,
                                onChange: _setSort,
                              ),
                              const SizedBox(height: 14),
                              if (_reviews.isEmpty)
                                const _EmptyReviews()
                              else
                                ..._reviews.map(
                                  (r) => _ReviewItem(
                                    raw: r,
                                    formatDate: _formatDate,
                                  ),
                                ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final double avg;
  final int count;

  const _SummaryHeader({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFF5C5C), size: 28),
                  const SizedBox(width: 6),
                  Text(
                    avg.toStringAsFixed(1),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '총 ${_formatCount(count)}건',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  color: AppColors.textSub,
                ),
              ),
            ],
          ),
          const SizedBox(width: 22),
          // 우측 통계 영역은 백엔드에 분해 데이터가 없어 비워둡니다 — 데이터
          // 들어오면 여기에 % 막대들을 그리면 끝.
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _SortBar extends StatelessWidget {
  final _SortMode current;
  final ValueChanged<_SortMode> onChange;

  const _SortBar({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    const items = <(_SortMode, String)>[
      (_SortMode.useful, '유용한 순'),
      (_SortMode.latest, '최신순'),
      (_SortMode.ratingHigh, '평점 높은순'),
      (_SortMode.ratingLow, '평점 낮은순'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '|',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: AppColors.border,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => onChange(items[i].$1),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  items[i].$2,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    fontWeight: current == items[i].$1
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: current == items[i].$1
                        ? AppColors.textMain
                        : AppColors.textSub,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final Map<String, dynamic> raw;
  final String Function(String) formatDate;

  const _ReviewItem({required this.raw, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final nickname = str(raw, ['nickname', 'user_nickname'], fallback: '익명');
    final rating = (raw['rating'] as num?)?.toInt() ?? 0;
    final text = str(raw, ['review_text', 'content', 'text']);
    final createdRaw = str(raw, ['created_at', 'date']);
    final skinType =
        str(raw, ['skin_type', 'reviewer_skin_type', 'user_skin_type']);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const Border(
        bottom: BorderSide(color: AppColors.border, width: 0.6),
      ).toBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  nickname.isNotEmpty ? nickname.characters.first : '?',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                    if (skinType.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          skinType,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11.5,
                            color: AppColors.textSub,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                formatDate(createdRaw),
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  color: AppColors.textSub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13.5,
              height: 1.55,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: const [
          Icon(Icons.rate_review_outlined,
              size: 36, color: AppColors.textSub),
          SizedBox(height: 10),
          Text(
            '아직 작성된 리뷰가 없어요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13.5,
              color: AppColors.textSub,
            ),
          ),
        ],
      ),
    );
  }
}

// Tiny extension so we can pass a Border as a BoxDecoration.
extension on Border {
  BoxDecoration toBoxDecoration() => BoxDecoration(border: this);
}
