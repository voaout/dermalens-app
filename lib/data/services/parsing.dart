// Defensive parsing helpers for backend responses.
//
// Django REST list endpoints return either a plain list or a paginated
// {count, next, previous, results: [...]} envelope — listOf handles both.
// Field names below are best-effort; adjust the key fallbacks once the exact
// response schema is confirmed.

// Known list-bearing keys used across the DermaLens API envelopes.
const _listKeys = [
  'products',
  'reviews',
  'liked_products',
  'recommendations',
  'history',
  'categories',
  'subcategories',
  'ingredients',
  'results',
  'feedbacks',
  'search_history',
  'recently_viewed',
  'recent_products',
  'trending',
  'trending_keywords',
  'keywords',
  'routines',
  'popular_routines',
  'notifications',
  'sessions',
  'messages',
  'data',
  'items',
];

List<Map<String, dynamic>> listOf(dynamic data) {
  List<Map<String, dynamic>> cast(List list) =>
      list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  if (data is List) return cast(data);
  if (data is Map) {
    // Try known envelope keys first.
    for (final k in _listKeys) {
      if (data[k] is List) return cast(data[k] as List);
    }
    // Fallback: first List value found in the map.
    for (final v in data.values) {
      if (v is List) return cast(v);
    }
  }
  return const [];
}

Map<String, dynamic> mapOf(dynamic data) {
  if (data is Map) return data.cast<String, dynamic>();
  return const {};
}

T? pick<T>(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is T) return v;
  }
  return null;
}

String str(Map<String, dynamic> m, List<String> keys, {String fallback = ''}) {
  for (final k in keys) {
    final v = m[k];
    if (v != null) return '$v';
  }
  return fallback;
}

List<String> strList(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is List) {
      return v.map((e) {
        if (e is Map) {
          return '${e['name'] ?? e['ingredient'] ?? e}';
        }
        return '$e';
      }).toList();
    }
  }
  return const [];
}

/// Normalizes a backend product object into the Map shape the UI widgets use
/// (name / brand / price / rating / reviewCount / review / ingredients ...).
Map<String, dynamic> normalizeProduct(Map<String, dynamic> p) {
  return {
    'id': p['product_id'] ?? p['id'],
    'name': str(p, ['product_name', 'name', 'title']),
    'brand': str(p, ['brand_name', 'brand', 'maker']),
    'category': str(p, ['category_name', 'category']),
    'imageUrl': str(p, ['image_url', 'imageUrl', 'thumbnail']),
    'price': _formatPrice(p['price'] ?? p['cost']),
    // 'score'는 추천 응답의 recommendation score라 별점이 아님 — 제외.
    'rating': str(p, ['avg_rating', 'rating'], fallback: '0'),
    'reviewCount': str(p, ['review_count', 'reviewCount'], fallback: '0'),
    'likeCount': str(p, ['like_count', 'likeCount'], fallback: '0'),
    'review': str(p, ['review', 'top_review', 'representative_review']),
    'ingredients':
        strList(p, ['ingredients', 'ingredient_list', 'main_ingredients']),
    'description': str(p, ['description', 'official_ingredient_text']),
    // review-card extras (present on review feeds)
    'reviewer': str(p, ['reviewer', 'user_nickname', 'nickname', 'author']),
    'reviewerSkinType': str(p, ['reviewer_skin_type', 'skin_type']),
    'reviewRating': (p['review_rating'] ?? p['avg_rating'] ?? p['rating'] ?? 0),
    // recommendation extras (있을 때만 의미 있음)
    'recommendScore': p['score'] ?? p['recommendation_score'],
    'recommendReason': str(p, ['reason', 'recommendation_reason']),
    'viewCount': str(p, ['view_count', 'views'], fallback: '0'),
    'reviewDate': str(p, ['review_date', 'created_at', 'date']),
  };
}

String _formatPrice(dynamic price) {
  if (price == null) return '';
  if (price is String) return price;
  if (price is num) {
    final s = price.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$buf원';
  }
  return '$price';
}
