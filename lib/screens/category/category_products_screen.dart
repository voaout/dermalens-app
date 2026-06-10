import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/models/skin_type.dart';
import '../../data/services/parsing.dart';
import '../../data/services/product_service.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/product_cards.dart';
import '../../widgets/glass/glass_chip.dart';
import '../product/product_detail_screen.dart';
import '../review/review_detail_screen.dart';

/// Holds the active product filters (UI-side; backend applies them later).
class ProductFilters {
  final Set<String> skinTypeCodes;
  final Set<String> periods;
  final double? minRating;
  final double priceMin;
  final double priceMax;
  final double priceCap;

  const ProductFilters({
    this.skinTypeCodes = const {},
    this.periods = const {},
    this.minRating,
    required this.priceMin,
    required this.priceMax,
    required this.priceCap,
  });

  factory ProductFilters.initial(double cap) =>
      ProductFilters(priceMin: 0, priceMax: cap, priceCap: cap);

  bool get priceTouched => priceMin > 0 || priceMax < priceCap;

  int get activeCount =>
      skinTypeCodes.length +
      periods.length +
      (minRating != null ? 1 : 0) +
      (priceTouched ? 1 : 0);
}

/// Products of a single category — reached from the category selector.
class CategoryProductsScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  String selectedView = '랭킹';
  ProductFilters? _filters;

  List<Map<String, dynamic>> products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ProductService.categoryProducts(widget.categoryId);
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

  void _openProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  void _openReview(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReviewDetailScreen(product: product)),
    );
  }

  int get _activeFilterCount => _filters?.activeCount ?? 0;

  /// Applies price/rating filters client-side. (Skin type & review period
  /// aren't in the product payload, so those need backend filtering.)
  List<Map<String, dynamic>> get _visibleProducts {
    final f = _filters;
    if (f == null) return products;
    return products.where((p) {
      if (f.priceTouched) {
        final price = _parsePrice('${p['price']}');
        if (price != null) {
          if (price < f.priceMin) return false;
          if (f.priceMax < f.priceCap && price > f.priceMax) return false;
        }
      }
      if (f.minRating != null) {
        final r = (p['reviewRating'] as num?)?.toDouble() ??
            double.tryParse('${p['rating']}') ??
            0;
        if (r < f.minRating!) return false;
      }
      return true;
    }).toList();
  }

  double? _parsePrice(String s) {
    final digits = RegExp(r'\d').allMatches(s).map((m) => m.group(0)).join();
    return digits.isEmpty ? null : double.tryParse(digits);
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13.5,
            color: AppColors.textSub,
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return const Center(
        child: Text(
          '해당 카테고리에 제품이 없어요.',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13.5,
            color: AppColors.textSub,
          ),
        ),
      );
    }

    final list = _visibleProducts;
    if (list.isEmpty) {
      return const Center(
        child: Text(
          '조건에 맞는 제품이 없어요.',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13.5,
            color: AppColors.textSub,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final p = list[index];
        return selectedView == '랭킹'
            ? ProductListCard(product: p, onTap: () => _openProduct(p))
            : ReviewListCard(product: p, onTap: () => _openReview(p));
      },
    );
  }

  /// Slider cap = highest product price (rounded up), fallback 100,000원.
  double _priceCap() {
    double maxP = 0;
    for (final p in products) {
      final digits =
          RegExp(r'\d').allMatches('${p['price']}').map((m) => m.group(0)).join();
      final v = double.tryParse(digits) ?? 0;
      if (v > maxP) maxP = v;
    }
    if (maxP <= 0) return 100000;
    return (maxP / 1000).ceil() * 1000;
  }

  Future<void> openFilterSheet() async {
    final cap = _priceCap();
    final result = await showModalBottomSheet<ProductFilters>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _FilterSheet(
        initial: _filters ?? ProductFilters.initial(cap),
        priceCap: cap,
      ),
    );
    if (result != null) {
      setState(() => _filters = result);
    }
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
              const SizedBox(height: 24),
              // Fixed top logo — same position as every other screen.
              const Align(
                alignment: Alignment.centerLeft,
                child: AppLogo(fontSize: 22),
              ),
              const SizedBox(height: 18),
              // Back arrow + category title moved below the logo.
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.categoryName,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ViewTab(
                    text: '랭킹',
                    selected: selectedView == '랭킹',
                    onTap: () => setState(() => selectedView = '랭킹'),
                  ),
                  const SizedBox(width: 18),
                  _ViewTab(
                    text: '리뷰',
                    selected: selectedView == '리뷰',
                    onTap: () => setState(() => selectedView = '리뷰'),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: openFilterSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            _activeFilterCount > 0
                                ? '필터 · $_activeFilterCount'
                                : '필터',
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
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _ViewTab({
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
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: selected ? AppColors.primary : AppColors.textSub,
        ),
      ),
    );
  }
}

const _periodOptions = ['1개월', '3개월', '6개월', '1년'];

// label → minimum rating value
const _ratingOptions = <String, double>{
  '4.5★ 이상': 4.5,
  '4.0★ 이상': 4.0,
  '3.0★ 이상': 3.0,
};

String _formatWon(double v) {
  final s = v.toInt().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$buf원';
}

class _FilterSheet extends StatefulWidget {
  final ProductFilters initial;
  final double priceCap;

  const _FilterSheet({required this.initial, required this.priceCap});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _skinCodes;
  late Set<String> _periods;
  double? _minRating;
  late RangeValues _price;

  @override
  void initState() {
    super.initState();
    _skinCodes = {...widget.initial.skinTypeCodes};
    _periods = {...widget.initial.periods};
    _minRating = widget.initial.minRating;
    _price = RangeValues(
      widget.initial.priceMin.clamp(0, widget.priceCap),
      widget.initial.priceMax.clamp(0, widget.priceCap),
    );
  }

  void _reset() {
    setState(() {
      _skinCodes.clear();
      _periods.clear();
      _minRating = null;
      _price = RangeValues(0, widget.priceCap);
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      ProductFilters(
        skinTypeCodes: _skinCodes,
        periods: _periods,
        minRating: _minRating,
        priceMin: _price.start,
        priceMax: _price.end,
        priceCap: widget.priceCap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    final cap = widget.priceCap;
    final upperLabel = _price.end >= cap
        ? '${_formatWon(cap)} 이상'
        : _formatWon(_price.end);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '필터',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 피부 타입 (DB 8종)
                    const _GroupTitle('피부 타입'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SkinType.all.map((s) {
                        return GlassChip(
                          label: s.displayName,
                          selected: _skinCodes.contains(s.code),
                          onTap: () => setState(() {
                            if (!_skinCodes.add(s.code)) {
                              _skinCodes.remove(s.code);
                            }
                          }),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 22),
                    const _GroupTitle('리뷰 작성 기간'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _periodOptions.map((p) {
                        return GlassChip(
                          label: p,
                          selected: _periods.contains(p),
                          onTap: () => setState(() {
                            if (!_periods.add(p)) _periods.remove(p);
                          }),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 22),
                    const _GroupTitle('리뷰 별점'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _ratingOptions.entries.map((e) {
                        return GlassChip(
                          label: e.key,
                          selected: _minRating == e.value,
                          onTap: () => setState(() {
                            _minRating =
                                _minRating == e.value ? null : e.value;
                          }),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),
                    const _GroupTitle('가격'),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '${_formatWon(_price.start)} ~ $upperLabel',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                    RangeSlider(
                      values: _price,
                      min: 0,
                      max: cap,
                      divisions: (cap / 1000).round().clamp(1, 1000),
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.primaryLight,
                      labels: RangeLabels(
                        _formatWon(_price.start),
                        upperLabel,
                      ),
                      onChanged: (v) => setState(() => _price = v),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _reset,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 18, color: AppColors.textSub),
                          SizedBox(width: 6),
                          Text(
                            '초기화',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: PrimaryButton(text: '적용', onTap: _apply)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String text;
  const _GroupTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textMain,
      ),
    );
  }
}
