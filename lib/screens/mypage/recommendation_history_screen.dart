import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/activity_store.dart';
import '../../data/services/parsing.dart';
import '../../data/services/user_service.dart';

class RecommendationHistoryScreen extends StatefulWidget {
  const RecommendationHistoryScreen({super.key});

  @override
  State<RecommendationHistoryScreen> createState() =>
      _RecommendationHistoryScreenState();
}

class _RecommendationHistoryScreenState
    extends State<RecommendationHistoryScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await UserService.recommendations();
      if (!mounted) return;
      RecommendationHistoryStore.items
        ..clear()
        ..addAll(listOf(data).map((m) {
          // The API returns one product per recommendation row.
          final product = str(m, ['product_name']);
          return RecommendationRecord(
            id: '${m['recommendation_id'] ?? m['id'] ?? ''}',
            reason: str(m, ['reason', 'title', 'summary']),
            productNames: product.isEmpty ? const [] : [product],
            createdAt:
                DateTime.tryParse(str(m, ['created_at', 'date'])) ??
                    DateTime.now(),
          );
        }));
    } on ApiException {
      // keep local cache
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}.${two(d.month)}.${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final items = RecommendationHistoryStore.items;

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
                      '추천 기록',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length}건',
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
                            return _RecommendationCard(
                              record: r,
                              dateText: _formatDate(r.createdAt),
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

class _RecommendationCard extends StatelessWidget {
  final RecommendationRecord record;
  final String dateText;

  const _RecommendationCard({
    required this.record,
    required this.dateText,
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
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.reason,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '추천 받은 제품 · ${record.productNames.length}',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSub,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < record.productNames.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        top: i == 0 ? 0 : 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4, right: 8),
                          child: Icon(Icons.circle,
                              size: 5, color: AppColors.textSub),
                        ),
                        Expanded(
                          child: Text(
                            record.productNames[i],
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
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
              child: const Icon(Icons.lightbulb_outline,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 추천 기록이 없어요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '설문이나 스캔으로 맞춤 추천을 받아 보세요.',
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
