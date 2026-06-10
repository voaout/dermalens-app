import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/activity_store.dart';
import '../../data/services/parsing.dart';
import '../../data/services/product_service.dart';
import '../../data/services/review_service.dart';
import '../../data/services/user_service.dart';
import '../../widgets/common/primary_button.dart';
import '../product/product_detail_screen.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await UserService.reviews();
      if (!mounted) return;
      MyReviewsStore.items
        ..clear()
        ..addAll(listOf(data).map((m) => Review(
              id: '${m['id'] ?? m['review_id'] ?? ''}',
              productId: '${m['product_id'] ?? ''}',
              productName: str(m, ['product_name', 'product', 'name']),
              brand: str(m, ['brand', 'brand_name']),
              rating: (m['rating'] as num?)?.toInt() ?? 0,
              content: str(m, ['review_text', 'content', 'text']),
              createdAt: DateTime.tryParse(str(m, ['created_at', 'date'])) ??
                  DateTime.now(),
            )));
    } on ApiException {
      // keep local cache
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 리뷰 → 해당 제품 상세 화면으로 이동.
  /// product 상세 응답을 normalizeProduct로 정리해 ProductDetailScreen에 전달.
  Future<void> _openProduct(Review review) async {
    if (review.productId.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('상품 정보를 불러올 수 없어요.'),
          duration: Duration(milliseconds: 1200),
        ));
      return;
    }
    try {
      final data = await ProductService.detail(review.productId);
      if (!mounted) return;
      final raw = mapOf(data);
      final productMap = raw['product'] is Map
          ? (raw['product'] as Map).cast<String, dynamic>()
          : raw;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: normalizeProduct(productMap),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _edit(Review review) async {
    final result = await showModalBottomSheet<({int rating, String content})>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ReviewEditorSheet(
        productName: review.productName,
        initialRating: review.rating,
        initialContent: review.content,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await ReviewService.update(
        review.id,
        rating: result.rating,
        content: result.content,
      );
      if (!mounted) return;
      setState(() {
        MyReviewsStore.update(
          review.id,
          rating: result.rating,
          content: result.content,
        );
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('리뷰가 수정되었어요.'),
          duration: Duration(milliseconds: 1200),
        ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Review review) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '리뷰를 삭제할까요?',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '"${review.productName}"에 작성한 리뷰가 삭제됩니다.',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.textSub,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                color: AppColors.textSub,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '삭제',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w800,
                color: Color(0xFFE15252),
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ReviewService.delete(review.id);
      if (!mounted) return;
      setState(() => MyReviewsStore.remove(review.id));
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('리뷰가 삭제되었어요.'),
          duration: Duration(milliseconds: 1200),
        ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = MyReviewsStore.items;

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
                  const Expanded(
                    child: Text(
                      '작성한 리뷰',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length}개',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final r = items[i];
                            return _ReviewCard(
                              review: r,
                              onEdit: () => _edit(r),
                              onDelete: () => _delete(r),
                              onOpenProduct: () => _openProduct(r),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenProduct;

  const _ReviewCard({
    required this.review,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.brand,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        color: AppColors.textSub,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      review.productName,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ],
                ),
              ),
              _StarRow(rating: review.rating),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.content,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13.5,
              height: 1.55,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _formatDate(review.createdAt),
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  color: AppColors.textSub,
                ),
              ),
              const Spacer(),
              if (review.productId.isNotEmpty)
                _SmallAction(
                  label: '상품 보기',
                  onTap: onOpenProduct,
                  color: AppColors.textMain,
                ),
              const SizedBox(width: 4),
              _SmallAction(label: '수정', onTap: onEdit),
              const SizedBox(width: 4),
              _SmallAction(
                label: '삭제',
                onTap: onDelete,
                color: const Color(0xFFE15252),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}.${two(d.month)}.${two(d.day)}';
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 18,
          color: const Color(0xFFFFC93C),
        );
      }),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SmallAction({
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _ReviewEditorSheet extends StatefulWidget {
  final String productName;
  final int initialRating;
  final String initialContent;

  const _ReviewEditorSheet({
    required this.productName,
    required this.initialRating,
    required this.initialContent,
  });

  @override
  State<_ReviewEditorSheet> createState() => _ReviewEditorSheetState();
}

class _ReviewEditorSheetState extends State<_ReviewEditorSheet> {
  late int _rating;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('리뷰 내용을 입력해 주세요.'),
          duration: Duration(milliseconds: 1200),
        ));
      return;
    }
    Navigator.pop(context, (rating: _rating, content: text));
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                '리뷰 수정',
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
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  color: AppColors.textSub,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 34,
                        color: const Color(0xFFFFC93C),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 5,
                  minLines: 4,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '제품 사용 경험을 자유롭게 적어주세요.',
                    isCollapsed: true,
                    counterText: '',
                  ),
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(text: '저장', onTap: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rate_review_outlined,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              '작성한 리뷰가 없어요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '사용한 제품을 평가해 다른 사용자와 경험을 나눠 보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
