// In-memory stores for "내 활동" data. Persists for the current session only.
// Each store seeds with a couple of sample entries so the UI is non-empty on
// first run. Replace with real repositories when the backend is connected.

class LikedProductsStore {
  static final List<Map<String, dynamic>> items = [];

  static bool contains(Map<String, dynamic> product) {
    final name = product['name'];
    return items.any((p) => p['name'] == name);
  }

  static void add(Map<String, dynamic> product) {
    if (!contains(product)) items.add(product);
  }

  static void remove(Map<String, dynamic> product) {
    final name = product['name'];
    items.removeWhere((p) => p['name'] == name);
  }

  static void toggle(Map<String, dynamic> product) {
    if (contains(product)) {
      remove(product);
    } else {
      add(product);
    }
  }

  static void clear() => items.clear();
}

class Review {
  final String id;
  final String productId;
  final String productName;
  final String brand;
  int rating;
  String content;
  final DateTime createdAt;

  Review({
    required this.id,
    this.productId = '',
    required this.productName,
    required this.brand,
    required this.rating,
    required this.content,
    required this.createdAt,
  });
}

class MyReviewsStore {
  static int _idCounter = 100;
  static String _nextId() => 'r${_idCounter++}';

  // TODO(backend): load the user's reviews from the API.
  static final List<Review> items = [];

  static void add({
    required String productName,
    required String brand,
    required int rating,
    required String content,
  }) {
    items.insert(
      0,
      Review(
        id: _nextId(),
        productName: productName,
        brand: brand,
        rating: rating,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
  }

  static void update(String id, {required int rating, required String content}) {
    final r = items.firstWhere((x) => x.id == id);
    r.rating = rating;
    r.content = content;
  }

  static void remove(String id) {
    items.removeWhere((x) => x.id == id);
  }

  static void clear() => items.clear();
}

class AnalysisRecord {
  final String id;
  final String productName;
  final String brand;
  final String imageUrl;
  final List<String> ingredients;
  final int oilScore;
  final int dehydratedScore;
  final int sensitiveScore;
  final int riskLevel; // 0~4, used by gauge
  final DateTime analyzedAt;

  const AnalysisRecord({
    required this.id,
    required this.productName,
    required this.brand,
    this.imageUrl = '',
    this.ingredients = const [],
    required this.oilScore,
    required this.dehydratedScore,
    required this.sensitiveScore,
    required this.riskLevel,
    required this.analyzedAt,
  });
}

class AnalysisHistoryStore {
  static final List<AnalysisRecord> items = [];
  /// 캐시된 items가 어떤 user_id 소유인지 — 화면이 로드 전 일치 여부 검증용.
  static Object? ownerUserId;

  static void clear() {
    items.clear();
    ownerUserId = null;
  }
}

class RecommendationRecord {
  final String id;
  final String reason;
  final List<String> productNames;
  final DateTime createdAt;

  const RecommendationRecord({
    required this.id,
    required this.reason,
    required this.productNames,
    required this.createdAt,
  });
}

class RecommendationHistoryStore {
  static final List<RecommendationRecord> items = [];

  static void clear() => items.clear();
}
