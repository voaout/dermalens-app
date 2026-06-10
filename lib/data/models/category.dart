import '../services/parsing.dart';

/// Product category (matches the backend Category table:
/// category_id / category_name / parent_id / depth).
class Category {
  final int id;
  final String name;
  final int? parentId;
  final int depth;

  const Category({
    required this.id,
    required this.name,
    this.parentId,
    this.depth = 1,
  });

  /// depth 1 = top-level parent, depth 2 = selectable sub-category.
  bool get isParent => depth == 1;
  bool get isLeaf => depth >= 2;

  factory Category.fromJson(Map<String, dynamic> m) {
    return Category(
      id: (m['category_id'] ?? m['id'] ?? 0) as int,
      name: '${m['category_name'] ?? m['name'] ?? ''}',
      parentId: (m['parent_id'] ?? m['parent']) as int?,
      depth: (m['depth'] as num?)?.toInt() ?? 1,
    );
  }

  /// Handles both the nested API shape
  /// (`{category_id, category_name, subcategories: [...]}`) and a flat
  /// `{category_id, parent_id, depth}` shape.
  static List<Category> listFrom(dynamic data) {
    final result = <Category>[];
    for (final m in listOf(data)) {
      final subs = m['subcategories'];
      if (subs is List) {
        final parentId = (m['category_id'] ?? m['id']) as int?;
        result.add(Category(
          id: parentId ?? 0,
          name: '${m['category_name'] ?? m['name'] ?? ''}',
          depth: 1,
        ));
        for (final s in subs) {
          if (s is Map) {
            final sm = s.cast<String, dynamic>();
            result.add(Category(
              id: (sm['category_id'] ?? sm['id'] ?? 0) as int,
              name: '${sm['category_name'] ?? sm['name'] ?? ''}',
              parentId: parentId,
              depth: 2,
            ));
          }
        }
      } else {
        result.add(Category.fromJson(m));
      }
    }
    return result;
  }
}
