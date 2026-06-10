import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/common/product_image.dart';
import '../product/product_detail_screen.dart';

class ReviewDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;

  const ReviewDetailScreen({super.key, required this.product});

  double get _rating =>
      (product['reviewRating'] as num?)?.toDouble() ??
      double.tryParse('${product['rating']}') ??
      0;

  @override
  Widget build(BuildContext context) {
    final ingredients = (product['ingredients'] as List).cast<String>();
    final reviewer = product['reviewer'] ?? '익명';
    final skinType = product['reviewerSkinType'] ?? '-';
    final date = product['reviewDate'] ?? '';
    final viewCount = product['viewCount'] ?? '0';

    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      '리뷰 상세',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                children: [
                  // Reviewer header
                  Row(
                    children: [
                      _Avatar(name: reviewer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reviewer,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$skinType 피부',
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  date,
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 12,
                                    color: AppColors.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  _StarRow(rating: _rating, size: 22, showValue: true),

                  const SizedBox(height: 18),
                  // Product card (tap → product detail)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          ProductImage(
                            url: product['imageUrl'],
                            width: 52,
                            height: 52,
                            borderRadius: 12,
                            iconSize: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['brand'] ?? '',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 12,
                                    color: AppColors.textSub,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  product['name'] ?? '',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  product['price'] ?? '',
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
                          const Icon(Icons.chevron_right,
                              size: 20, color: AppColors.textSub),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),
                  Text(
                    product['review'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      height: 1.7,
                      color: AppColors.textMain,
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    '주요 성분',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ingredients.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _Stat(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFFFC93C),
                          label: '별점',
                          value: _rating.toStringAsFixed(1),
                        ),
                        _StatDivider(),
                        _Stat(
                          icon: Icons.reviews_outlined,
                          iconColor: AppColors.primary,
                          label: '리뷰',
                          value: '${product['reviewCount'] ?? 0}',
                        ),
                        _StatDivider(),
                        _Stat(
                          icon: Icons.visibility_outlined,
                          iconColor: AppColors.textSub,
                          label: '열람',
                          value: '$viewCount',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isNotEmpty ? name.trim().substring(0, 1) : '?';
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  final bool showValue;

  const _StarRow({
    required this.rating,
    this.size = 18,
    this.showValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          IconData icon;
          if (rating >= i + 1) {
            icon = Icons.star_rounded;
          } else if (rating >= i + 0.5) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_border_rounded;
          }
          return Icon(icon, size: size, color: const Color(0xFFFFC93C));
        }),
        if (showValue) ...[
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 11.5,
              color: AppColors.textSub,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      color: AppColors.border,
    );
  }
}
