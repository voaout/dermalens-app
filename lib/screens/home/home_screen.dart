import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';
import '../../data/beta_rewards_store.dart';
import '../../data/services/product_service.dart';
import '../../data/services/parsing.dart';
import '../../data/services/recommendation_service.dart';
import '../../data/user_profile.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/mirror_icon.dart';
import '../../widgets/common/product_image.dart';
import '../../widgets/glass/glass_card.dart';

import '../beta/beta_announcement_popup.dart';
import '../beta/ingredient_register_screen.dart';
import '../search/search_screen.dart';
import '../category/category_screen.dart';
import '../product/product_detail_screen.dart';
import '../product/recommended_products_screen.dart';
import '../review/review_detail_screen.dart';
import '../vanity/my_vanity_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTabIndex = 0;

  List<Map<String, dynamic>> products = [];        // 인기/리뷰 탭용
  List<Map<String, dynamic>> recommendations = []; // 홈 탭 "맞춤 추천"용
  bool _loading = true;
  bool _loadingRecs = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRecommendations();
    // 첫 프레임 직후 베타 안내 팝업을 띄움 — "오늘 그만보기"로 닫혔으면 skip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowBetaPopup();
    });
  }

  Future<void> _maybeShowBetaPopup() async {
    if (!mounted) return;
    if (BetaRewardsStore.I.dismissedToday) return;
    final result = await showBetaAnnouncementPopup(context);
    if (result == true && mounted) _openIngredientRegister();
  }

  void _openIngredientRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IngredientRegisterScreen()),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ProductService.popular();
      if (!mounted) return;
      setState(() {
        products = listOf(data).map(normalizeProduct).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// 2단계 추천 로딩:
  ///   1) GET /api/recommendation/user/{uid}/ 로 저장된 추천 조회
  ///   2) 비어 있으면 POST /api/recommendation/generate/ 호출 후 다시 조회
  /// 비로그인 상태나 오류는 조용히 빈 상태로 둡니다 — 홈은 인기 상품으로 채워져요.
  Future<void> _loadRecommendations() async {
    if (!AuthSession.isLoggedIn) {
      if (mounted) setState(() => _loadingRecs = false);
      return;
    }
    setState(() => _loadingRecs = true);
    try {
      var data = await RecommendationService.forUser();
      var list = listOf(data).map(normalizeProduct).toList();
      if (list.isEmpty) {
        // 첫 사용자거나 추천이 아직 생성 안 됨 → 생성 후 재조회.
        try {
          await RecommendationService.generate();
          if (!mounted) return;
          data = await RecommendationService.forUser();
          list = listOf(data).map(normalizeProduct).toList();
        } on ApiException {
          // generate 실패해도 빈 상태로 진행 (홈은 인기 상품으로 폴백).
        }
      }
      if (!mounted) return;
      setState(() {
        recommendations = list;
        _loadingRecs = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingRecs = false);
    }
  }

  void _moveToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SearchScreen(),
      ),
    );
  }

  void _moveToCategory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CategoryScreen(),
      ),
    );
  }

  void _moveToProductDetail(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  void _moveToReviewDetail(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewDetailScreen(product: product),
      ),
    );
  }

  void _moveToRecommendedProducts() {
    // 추천이 있으면 추천을, 없으면 인기 상품으로 폴백.
    final list = recommendations.isNotEmpty ? recommendations : products;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecommendedProductsScreen(products: list),
      ),
    );
  }

  void _moveToVanity() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyVanityScreen()),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppLogo(fontSize: 22),
                  Row(
                    children: [
                      // 🎯 베타 — 성분 등록 진입 (돋보기 왼쪽)
                      GestureDetector(
                        onTap: _openIngredientRegister,
                        child: const Icon(
                          Icons.star_rounded,
                          size: 28,
                          color: Color(0xFFFFB02E),
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: _moveToSearch,
                        child: const Icon(Icons.search, size: 26),
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: _moveToCategory,
                        child: const Icon(Icons.menu, size: 28),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  _TopTab(
                    text: '홈',
                    selected: selectedTabIndex == 0,
                    onTap: () => setState(() => selectedTabIndex = 0),
                  ),
                  const SizedBox(width: 18),
                  _TopTab(
                    text: '인기상품',
                    selected: selectedTabIndex == 1,
                    onTap: () => setState(() => selectedTabIndex = 1),
                  ),
                  const SizedBox(width: 18),
                  _TopTab(
                    text: '리뷰',
                    selected: selectedTabIndex == 2,
                    onTap: () => setState(() => selectedTabIndex = 2),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: _error != null
                    ? _ErrorRetry(message: _error!, onRetry: _load)
                    : IndexedStack(
                        index: selectedTabIndex,
                        children: [
                          _HomeTab(
                            // 맞춤 추천이 있으면 우선, 없으면 인기로 폴백.
                            products: recommendations.isNotEmpty
                                ? recommendations
                                : products,
                            loading: recommendations.isNotEmpty
                                ? false
                                : (_loadingRecs && _loading),
                            onProductTap: _moveToProductDetail,
                            onMoreTap: _moveToRecommendedProducts,
                            onVanityTap: _moveToVanity,
                          ),
                          _PopularProductTab(
                            products: products,
                            loading: _loading,
                            onProductTap: _moveToProductDetail,
                          ),
                          _ReviewTab(
                            products: products,
                            loading: _loading,
                            onReviewTap: _moveToReviewDetail,
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

class _HomeTab extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onProductTap;
  final VoidCallback onMoreTap;
  final VoidCallback onVanityTap;

  const _HomeTab({
    required this.products,
    required this.loading,
    required this.onProductTap,
    required this.onMoreTap,
    required this.onVanityTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          '나의 피부를 위한\n맞춤 성분 분석',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 14),
        Text(
          '화장품 성분표를 촬영하고\n내 피부에 맞는지 확인해보세요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _VanityCard(onTap: onVanityTap),
        const SizedBox(height: 28),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                UserProfile.nickname.isEmpty
                    ? '맞춤 추천 제품'
                    : '${UserProfile.nickname}님을 위한 추천 제품',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '피부 타입과 알레르기 정보를 기반으로\n비슷한 사용자가 많이 선택한 제품이에요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onMoreTap,
                  child: const Text(
                    '더보기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 210,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
                  ? const _EmptyHint('표시할 추천 제품이 없어요.')
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        return _HorizontalProductCard(
                          product: products[index],
                          onTap: () => onProductTap(products[index]),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _VanityCard extends StatelessWidget {
  final VoidCallback onTap;
  const _VanityCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const MirrorIcon(size: 26, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '나의 화장대',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '내 루틴을 기록하고 같은 피부 타입 인기 순서를 확인해요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSub),
          ],
        ),
      ),
    );
  }
}

class _PopularProductTab extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onProductTap;

  const _PopularProductTab({
    required this.products,
    required this.loading,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (products.isEmpty) return const _EmptyHint('인기 제품이 아직 없어요.');
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _RankingProductCard(
          rank: index + 1,
          product: products[index],
          onTap: () => onProductTap(products[index]),
        );
      },
    );
  }
}

class _ReviewTab extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onReviewTap;

  const _ReviewTab({
    required this.products,
    required this.loading,
    required this.onReviewTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (products.isEmpty) return const _EmptyHint('아직 리뷰가 없어요.');
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _ReviewCard(
          product: products[index],
          onTap: () => onReviewTap(products[index]),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _ReviewCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ingredients = (product['ingredients'] as List).cast<String>();
    final reviewer = product['reviewer'] ?? '익명';
    final skinType = product['reviewerSkinType'] ?? '-';
    final date = product['reviewDate'] ?? '';
    final rating = (product['reviewRating'] as num?)?.toDouble() ??
        double.tryParse('${product['rating']}') ??
        0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reviewer row
            Row(
              children: [
                _ReviewerAvatar(name: '$reviewer'),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$reviewer',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$skinType 피부 · $date',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11.5,
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                _MiniStars(rating: rating),
              ],
            ),
            const SizedBox(height: 14),

            // Brand · product name
            Text(
              product['brand'] ?? '',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11.5,
                color: AppColors.textSub,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              product['name'] ?? '',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 10),
            Text(
              product['review'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textMain,
              ),
            ),

            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ingredients.map((item) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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

            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    size: 15, color: AppColors.textSub),
                const SizedBox(width: 4),
                Text(
                  '열람 ${product['viewCount'] ?? 0}',
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
                  '리뷰 ${product['reviewCount'] ?? 0}',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: AppColors.textSub,
                  ),
                ),
                const Spacer(),
                const Text(
                  '자세히',
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

class _ReviewerAvatar extends StatelessWidget {
  final String name;
  const _ReviewerAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isNotEmpty ? name.trim().substring(0, 1) : '?';
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _MiniStars extends StatelessWidget {
  final double rating;
  const _MiniStars({required this.rating});

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

class _TopTab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _TopTab({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: selected ? AppColors.primary : AppColors.textSub,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _HorizontalProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _HorizontalProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImage(
              url: product['imageUrl'],
              width: double.infinity,
              height: 82,
              borderRadius: 18,
              iconSize: 36,
            ),
            const SizedBox(height: 12),
            Text(
              product['brand'],
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11,
                color: AppColors.textSub,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product['name'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.star, size: 14, color: Color(0xFFFFCC00)),
                const SizedBox(width: 3),
                Text(
                  product['rating'],
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
    );
  }
}

class _RankingProductCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _RankingProductCard({
    required this.rank,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Text(
              '$rank',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            ProductImage(
              url: product['imageUrl'],
              width: 62,
              height: 62,
              borderRadius: 16,
              iconSize: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['brand'],
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product['name'],
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${product['price']} · ⭐ ${product['rating']}',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: AppColors.textSub,
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

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13.5,
          color: AppColors.textSub,
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36, color: AppColors.textSub),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13.5,
              color: AppColors.textSub,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}