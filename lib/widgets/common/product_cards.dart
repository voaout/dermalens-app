import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'product_image.dart';

BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

/// Compact product row: image + brand + name + price. Tappable → detail.
class ProductListCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const ProductListCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Row(
          children: [
            ProductImage(
              url: product['imageUrl'],
              width: 58,
              height: 58,
              borderRadius: 14,
              iconSize: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${product['brand'] ?? ''}',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product['name'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${product['price'] ?? ''}',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textSub),
          ],
        ),
      ),
    );
  }
}

/// Rich review summary card: photo + brand/name + rating + review snippet +
/// view count + "자세히 보기". Tappable → review detail.
class ReviewListCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const ReviewListCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rating = (product['reviewRating'] as num?)?.toDouble() ??
        double.tryParse('${product['rating']}') ??
        0;
    final review = '${product['review'] ?? ''}';
    final reviewer = '${product['reviewer'] ?? ''}';
    final viewCount = '${product['viewCount'] ?? ''}';
    final reviewCount = '${product['reviewCount'] ?? ''}';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User-uploaded / product photo
                ProductImage(
                  url: product['imageUrl'],
                  width: 52,
                  height: 52,
                  borderRadius: 12,
                  iconSize: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reviewer.isNotEmpty
                            ? reviewer
                            : '${product['brand'] ?? ''}',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: AppColors.textSub,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product['name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Stars(rating: rating),
              ],
            ),
            if (review.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppColors.textMain,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    size: 15, color: AppColors.textSub),
                const SizedBox(width: 4),
                Text(
                  '열람 ${viewCount.isEmpty ? '0' : viewCount}',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: AppColors.textSub,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.reviews_outlined,
                    size: 15, color: AppColors.textSub),
                const SizedBox(width: 4),
                Text(
                  '리뷰 ${reviewCount.isEmpty ? '0' : reviewCount}',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: AppColors.textSub,
                  ),
                ),
                const Spacer(),
                const Text(
                  '자세히 보기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 16, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC93C)),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
      ],
    );
  }
}
