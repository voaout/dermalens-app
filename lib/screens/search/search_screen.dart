import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';
import '../../data/services/parsing.dart';
import '../../data/services/product_service.dart';
import '../../data/services/review_service.dart';
import '../../widgets/common/product_image.dart';
import '../product/product_detail_screen.dart';
import '../review/review_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();

  String selectedTab = '전체';
  bool searched = false;
  bool _loading = false;
  String? selectedBrand;

  List<Map<String, dynamic>> recentProducts = [];
  List<String> recentKeywords = [];
  List<String> trendingKeywords = [];

  List<Map<String, dynamic>> products = [];

  @override
  void initState() {
    super.initState();
    _loadBeforeData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Loads the pre-search landing data:
  /// 최근 검색어 · 최근 본 제품 (둘 다 로그인 시) · 급상승 검색어 (항상).
  Future<void> _loadBeforeData() async {
    _loadSearchHistory();
    _loadRecentlyViewed();
    _loadTrending();
  }

  Future<void> _loadSearchHistory() async {
    if (!AuthSession.isLoggedIn) return;
    try {
      final data = await ReviewService.searchHistory();
      if (!mounted) return;
      setState(() {
        recentKeywords = listOf(data)
            .map((e) => '${e['keyword'] ?? e['query'] ?? e['term'] ?? ''}')
            .where((s) => s.isNotEmpty)
            .toList();
      });
    } on ApiException {
      // history is optional — ignore failures.
    }
  }

  Future<void> _loadRecentlyViewed() async {
    if (!AuthSession.isLoggedIn) return;
    try {
      final data = await ReviewService.recentlyViewed();
      if (!mounted) return;
      setState(() {
        // Entries may wrap the product (e.g. { product: {...}, viewed_at }).
        recentProducts = listOf(data).map((e) {
          final p = (e['product'] is Map)
              ? (e['product'] as Map).cast<String, dynamic>()
              : e;
          return normalizeProduct(p);
        }).toList();
      });
    } on ApiException {
      // optional — ignore failures.
    }
  }

  Future<void> _loadTrending() async {
    try {
      final data = await ReviewService.trending();
      if (!mounted) return;
      setState(() {
        trendingKeywords = listOf(data)
            .map((e) =>
                '${e['keyword'] ?? e['query'] ?? e['term'] ?? e['word'] ?? ''}')
            .where((s) => s.isNotEmpty)
            .toList();
      });
    } on ApiException {
      // optional — ignore failures.
    }
  }

  Future<void> submitSearch(String value) async {
    final keyword = value.trim();
    if (keyword.isEmpty) return;

    setState(() {
      searched = true;
      selectedTab = '전체';
      selectedBrand = null;
      _loading = true;
    });

    // Log the search term (best-effort; only when logged in, never blocks).
    if (AuthSession.isLoggedIn) {
      ReviewService.logSearch(keyword).catchError((_) => null);
    }

    try {
      final data = await ProductService.search(keyword);
      if (!mounted) return;
      setState(() {
        products = listOf(data).map(normalizeProduct).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        products = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openProduct(Map<String, dynamic> product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
    // Refresh "최근 본 제품" after returning — the view was just logged.
    _loadRecentlyViewed();
  }

  // --- Local removal of pre-search items.
  // The backend doesn't expose delete endpoints for these yet, so removal is
  // local-only and items will reappear on the next reload from the server.
  void _removeRecentProduct(int index) {
    setState(() => recentProducts.removeAt(index));
  }

  void _clearRecentProducts() {
    setState(() => recentProducts.clear());
  }

  void _removeRecentKeyword(String keyword) {
    setState(() => recentKeywords.remove(keyword));
  }

  void _clearRecentKeywords() {
    setState(() => recentKeywords.clear());
  }

  void _openReview(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReviewDetailScreen(product: product)),
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
            children: [
              const SizedBox(height: 18),

              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onSubmitted: submitSearch,
                        onChanged: (_) {
                          if (searched) setState(() {});
                        },
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: const InputDecoration(
                          icon: Icon(Icons.search, size: 22),
                          hintText: '제품명, 성분, 브랜드 검색',
                          hintStyle: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            color: AppColors.textSub,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Expanded(
                child: searched
                    ? _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _SearchResultView(
                            selectedTab: selectedTab,
                            selectedBrand: selectedBrand,
                            products: products,
                            onTabChanged: (tab) {
                              setState(() {
                                selectedTab = tab;
                                if (tab != '제품') selectedBrand = null;
                              });
                            },
                            onProductTap: _openProduct,
                            onReviewTap: _openReview,
                            onBrandTap: (brand) {
                              setState(() {
                                selectedBrand = brand;
                                selectedTab = '제품';
                              });
                            },
                            onClearBrand: () =>
                                setState(() => selectedBrand = null),
                          )
                    : _SearchBeforeView(
                        recentProducts: recentProducts,
                        recentKeywords: recentKeywords,
                        trendingKeywords: trendingKeywords,
                        onProductTap: _openProduct,
                        onRemoveProduct: _removeRecentProduct,
                        onClearProducts: _clearRecentProducts,
                        onRemoveKeyword: _removeRecentKeyword,
                        onClearKeywords: _clearRecentKeywords,
                        onKeywordTap: (keyword) {
                          searchController.text = keyword.replaceAll(RegExp(r'^\d+\.\s*'), '');
                          submitSearch(searchController.text);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBeforeView extends StatelessWidget {
  final List<Map<String, dynamic>> recentProducts;
  final List<String> recentKeywords;
  final List<String> trendingKeywords;
  final ValueChanged<Map<String, dynamic>> onProductTap;
  final ValueChanged<int> onRemoveProduct;
  final VoidCallback onClearProducts;
  final ValueChanged<String> onRemoveKeyword;
  final VoidCallback onClearKeywords;
  final ValueChanged<String> onKeywordTap;

  const _SearchBeforeView({
    required this.recentProducts,
    required this.recentKeywords,
    required this.trendingKeywords,
    required this.onProductTap,
    required this.onRemoveProduct,
    required this.onClearProducts,
    required this.onRemoveKeyword,
    required this.onClearKeywords,
    required this.onKeywordTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _SectionHeader(
          title: '최근 본 제품',
          onClear: recentProducts.isEmpty ? null : onClearProducts,
        ),
        const SizedBox(height: 12),
        if (recentProducts.isEmpty)
          const _EmptyHint(text: '최근 본 제품이 없어요.')
        else
          SizedBox(
            height: 158,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentProducts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = recentProducts[index];
                return _RecentProductCard(
                  product: item,
                  onTap: () => onProductTap(item),
                  onRemove: () => onRemoveProduct(index),
                );
              },
            ),
          ),

        const SizedBox(height: 28),

        _SectionHeader(
          title: '최근 검색어',
          onClear: recentKeywords.isEmpty ? null : onClearKeywords,
        ),
        const SizedBox(height: 12),
        if (recentKeywords.isEmpty)
          const _EmptyHint(text: '최근 검색어가 없어요.')
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: recentKeywords
                .map(
                  (item) => _ChipBox(
                    text: item,
                    onTap: () => onKeywordTap(item),
                    onRemove: () => onRemoveKeyword(item),
                  ),
                )
                .toList(),
          ),

        const SizedBox(height: 28),

        _SectionHeader(title: '급상승 검색어'),
        const SizedBox(height: 12),
        if (trendingKeywords.isEmpty)
          const _EmptyHint(text: '급상승 검색어가 없어요.')
        else
          ...trendingKeywords.asMap().entries.map(
                (entry) => _TrendingTile(
                  rank: entry.key + 1,
                  text: entry.value,
                  onTap: () => onKeywordTap(entry.value),
                ),
              ),
      ],
    );
  }
}

class _RecentProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentProductCard({
    required this.product,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ProductImage(
                  url: product['imageUrl'],
                  width: 100,
                  height: 100,
                  borderRadius: 14,
                  iconSize: 28,
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onRemove,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${product['name'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingTile extends StatelessWidget {
  final int rank;
  final String text;
  final VoidCallback onTap;

  const _TrendingTile({
    required this.rank,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final topRank = rank <= 3;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: topRank ? AppColors.primary : AppColors.textSub,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        color: AppColors.textSub,
      ),
    );
  }
}

class _SearchResultView extends StatelessWidget {
  final String selectedTab;
  final String? selectedBrand;
  final List<Map<String, dynamic>> products;
  final ValueChanged<String> onTabChanged;
  final ValueChanged<Map<String, dynamic>> onProductTap;
  final ValueChanged<Map<String, dynamic>> onReviewTap;
  final ValueChanged<String> onBrandTap;
  final VoidCallback onClearBrand;

  const _SearchResultView({
    required this.selectedTab,
    required this.selectedBrand,
    required this.products,
    required this.onTabChanged,
    required this.onProductTap,
    required this.onReviewTap,
    required this.onBrandTap,
    required this.onClearBrand,
  });

  @override
  Widget build(BuildContext context) {
    const tabs = ['전체', '제품', '리뷰', '브랜드'];

    return Column(
      children: [
        Row(
          children: tabs.map((tab) {
            final selected = selectedTab == tab;
            return GestureDetector(
              onTap: () => onTabChanged(tab),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(right: 18),
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.textSub,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          '검색 결과가 없어요.',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13.5,
            color: AppColors.textSub,
          ),
        ),
      );
    }

    switch (selectedTab) {
      case '브랜드':
        return _buildBrandList();
      case '리뷰':
        return _buildReviewList();
      case '제품':
        return _buildProductList(brandFiltered: true);
      default:
        return _buildProductList(brandFiltered: false);
    }
  }

  Widget _buildProductList({required bool brandFiltered}) {
    final list = (brandFiltered && selectedBrand != null)
        ? products.where((p) => '${p['brand']}' == selectedBrand).toList()
        : products;

    return Column(
      children: [
        if (brandFiltered && selectedBrand != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onClearBrand,
                child: Container(
                  padding:
                      const EdgeInsets.only(left: 12, right: 8, top: 7, bottom: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '브랜드 · $selectedBrand',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.close, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = list[index];
              return _ProductCard(
                product: item,
                onTap: () => onProductTap(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewList() {
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = products[index];
        return _ReviewCard(
          product: item,
          onTap: () => onReviewTap(item),
        );
      },
    );
  }

  Widget _buildBrandList() {
    // Group by brand with counts (same brands together).
    final counts = <String, int>{};
    for (final p in products) {
      final b = '${p['brand']}';
      if (b.isNotEmpty) counts[b] = (counts[b] ?? 0) + 1;
    }
    final brands = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return ListView.separated(
      itemCount: brands.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final brand = brands[index];
        return _BrandCard(
          brand: brand,
          count: counts[brand]!,
          onTap: () => onBrandTap(brand),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
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

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _ReviewCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rating = (product['reviewRating'] as num?)?.toDouble() ??
        double.tryParse('${product['rating']}') ??
        0;
    final review = '${product['review'] ?? ''}';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
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
                        '${product['brand'] ?? ''}',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11.5,
                          color: AppColors.textSub,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product['name'] ?? ''}',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 16, color: Color(0xFFFFC93C)),
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
                ),
              ],
            ),
            if (review.isNotEmpty) ...[
              const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                const Text(
                  '리뷰 보기',
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

class _BrandCard extends StatelessWidget {
  final String brand;
  final int count;
  final VoidCallback onTap;

  const _BrandCard({
    required this.brand,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.storefront_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                brand,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
            ),
            Text(
              '$count개',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSub,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textSub),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClear;

  const _SectionHeader({required this.title, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
        const Spacer(),
        if (onClear != null)
          GestureDetector(
            onTap: onClear,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Text(
                '전체 삭제',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
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

class _ChipBox extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _ChipBox({required this.text, this.onTap, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.only(
          left: 14,
          right: onRemove == null ? 14 : 6,
          top: 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: AppColors.textSub),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
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