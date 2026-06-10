import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/models/category.dart';
import '../../data/services/product_service.dart';
import 'category_products_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  // Category hierarchy: depth-1 parents (left rail) + depth-2 children (right list).
  List<Category> _allCategories = [];
  int? _selectedParentId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  List<Category> get _parents =>
      _allCategories.where((c) => c.isParent).toList();

  List<Category> _childrenOf(int? parentId) =>
      _allCategories.where((c) => c.isLeaf && c.parentId == parentId).toList();

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ProductService.categories();
      if (!mounted) return;
      _allCategories = Category.listFrom(data);
      final parents = _parents;
      setState(() {
        _selectedParentId = parents.isNotEmpty ? parents.first.id : null;
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

  void _openCategory(Category c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          categoryId: c.id,
          categoryName: c.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    '카테고리',
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
            const Divider(height: 1, color: AppColors.border),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13.5,
                              color: AppColors.textSub,
                            ),
                          ),
                        )
                      : _TwoPane(
                          parents: _parents,
                          selectedParentId: _selectedParentId,
                          children: _childrenOf(_selectedParentId),
                          onSelectParent: (id) =>
                              setState(() => _selectedParentId = id),
                          onSelectChild: _openCategory,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TwoPane extends StatelessWidget {
  final List<Category> parents;
  final int? selectedParentId;
  final List<Category> children;
  final ValueChanged<int> onSelectParent;
  final ValueChanged<Category> onSelectChild;

  const _TwoPane({
    required this.parents,
    required this.selectedParentId,
    required this.children,
    required this.onSelectParent,
    required this.onSelectChild,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left rail — parent categories
        Container(
          width: 128,
          color: const Color(0xFFF5F7FA),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: parents.length,
            itemBuilder: (context, i) {
              final p = parents[i];
              final selected = p.id == selectedParentId;
              return GestureDetector(
                onTap: () => onSelectParent(p.id),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: selected ? AppColors.card : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 18),
                  child: Row(
                    children: [
                      if (selected)
                        Container(
                          width: 3,
                          height: 16,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          p.name,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Right list — sub-categories of the selected parent
        Expanded(
          child: children.isEmpty
              ? const Center(
                  child: Text(
                    '하위 카테고리가 없어요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      color: AppColors.textSub,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.border,
                    indent: 24,
                    endIndent: 24,
                  ),
                  itemBuilder: (context, i) {
                    final c = children[i];
                    return InkWell(
                      onTap: () => onSelectChild(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.name,
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMain,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 20, color: AppColors.textSub),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
