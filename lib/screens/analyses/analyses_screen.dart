import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';
import '../../data/activity_store.dart';
import '../../data/analysis_jobs_store.dart';
import '../../data/services/analysis_service.dart';
import '../../data/services/ocr_job_runner.dart';
import '../../data/services/parsing.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/product_image.dart';
import '../scan/ocr_loading_screen.dart';
import '../scan/ocr_result_screen.dart';

/// 진행 중인 OCR job과 완료된 분석 결과를 보여줍니다.
///
/// 두 진입점에서 같은 화면을 씁니다:
///   - 하단 4번째 탭에서 직접 노출(뒤로 가기 없음)
///   - 마이페이지 "분석 기록" 메뉴에서 push (뒤로 가기 표시)
class AnalysesScreen extends StatefulWidget {
  /// true면 헤더 좌측에 뒤로 가기 화살표를 노출.
  /// 마이페이지에서 push로 진입할 때 사용.
  final bool showBack;

  const AnalysesScreen({super.key, this.showBack = false});

  @override
  State<AnalysesScreen> createState() => _AnalysesScreenState();
}

class _AnalysesScreenState extends State<AnalysesScreen> {
  bool _loadingHistory = true;
  int _lastCompletedSeen = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // 새 OCR job이 완료되면 서버에도 새 history 레코드가 생겼을 테니
    // 자동으로 history를 다시 받아옵니다.
    AnalysisJobsStore.I.addListener(_onJobsChanged);
  }

  @override
  void dispose() {
    AnalysisJobsStore.I.removeListener(_onJobsChanged);
    super.dispose();
  }

  void _onJobsChanged() {
    final n = AnalysisJobsStore.I.completed.length;
    if (n > _lastCompletedSeen) {
      _lastCompletedSeen = n;
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    final currentUid = AuthSession.userId;

    // 2차 방어: 캐시가 다른 사용자 소유면 즉시 비워서 이전 데이터가 노출되지
    // 않게 합니다. (정상 흐름이면 로그인 시 이미 리셋됐지만, 혹시 모를 누수
    // 대비.)
    if (AnalysisHistoryStore.ownerUserId != currentUid) {
      AnalysisHistoryStore.items.clear();
      AnalysisHistoryStore.ownerUserId = currentUid;
      if (mounted) setState(() {});
    }

    if (!AuthSession.isLoggedIn) {
      if (mounted) setState(() => _loadingHistory = false);
      return;
    }

    try {
      final data = await AnalysisService.history();
      if (!mounted) return;
      // 비동기 응답 도착 사이에 사용자가 바뀌었으면 결과를 버립니다.
      if (AuthSession.userId != currentUid) return;
      AnalysisHistoryStore.items
        ..clear()
        ..addAll(listOf(data).map((m) => AnalysisRecord(
              id: '${m['analysis_id'] ?? m['id'] ?? ''}',
              productName: str(m, ['product_name', 'product', 'name']),
              // 진짜 브랜드만 — analysis_type 같은 기술 태그는 노출 안 함.
              brand: str(m, ['brand', 'brand_name']),
              ingredients: _extractIngredients(m),
              imageUrl: str(m, ['image_url', 'imageUrl', 'thumbnail']),
              oilScore: 0,
              dehydratedScore: 0,
              sensitiveScore: 0,
              riskLevel: _levelFrom(m),
              analyzedAt: DateTime.tryParse(
                      str(m, ['created_at', 'analyzed_at', 'date'])) ??
                  DateTime.now(),
            )));
      AnalysisHistoryStore.ownerUserId = currentUid;
    } on ApiException {
      // keep local cache
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  /// 성분 리스트 추출 — top-level + 중첩 모두 탐색. 객체 배열이면 이름만 뽑음.
  List<String> _extractIngredients(Map<String, dynamic> m) {
    List<String>? pull(dynamic v) {
      if (v is! List) return null;
      final out = v
          .map((e) {
            if (e is Map) {
              return '${e['ingredient_name_kr'] ?? e['name_kr'] ?? e['name'] ?? e['detected_text'] ?? e['ingredient'] ?? ''}';
            }
            return '$e';
          })
          .where((s) => s.trim().isNotEmpty)
          .toList();
      return out.isEmpty ? null : out;
    }

    for (final k in ['ingredients', 'matched_ingredients']) {
      final found = pull(m[k]);
      if (found != null) return found;
    }
    for (final container in ['result', 'body', 'analysis', 'data']) {
      final nested = m[container];
      if (nested is Map) {
        for (final k in ['ingredients', 'matched_ingredients']) {
          final found = pull(nested[k]);
          if (found != null) return found;
        }
      }
    }
    return const [];
  }

  /// 카드 타이틀용 — 3개까지 콤마, 그 이상은 "외 N개" 꼬리.
  static String shortIngredients(List<String> ings) {
    if (ings.length <= 3) return ings.join(', ');
    return '${ings.take(3).join(', ')} 외 ${ings.length - 3}개';
  }

  int _levelFrom(Map<String, dynamic> m) {
    final tl = '${m['traffic_light'] ?? ''}'.toUpperCase();
    if (tl == 'GREEN') return 1;
    if (tl == 'YELLOW') return 2;
    if (tl == 'ORANGE') return 3;
    if (tl == 'RED') return 4;
    final score = (m['risk_score'] as num?)?.toDouble() ?? 0;
    return score.round().clamp(0, 4);
  }

  static const _levelColors = [
    Color(0xFF34C77B),
    Color(0xFF9BD24F),
    Color(0xFFFFD13B),
    Color(0xFFFF9F40),
    Color(0xFFFF5C5C),
  ];

  static const _levelLabels = ['매우 추천', '추천', '보통', '비추천', '강력 비추천'];

  String _formatDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}.${two(d.month)}.${two(d.day)}';
  }

  String _formatRelative(DateTime started) {
    final diff = DateTime.now().difference(started);
    if (diff.inSeconds < 60) return '방금 시작';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전 시작';
    return '${diff.inHours}시간 전 시작';
  }

  void _openLoading(OcrJob job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OcrLoadingScreen(job: job)),
    );
  }

  void _openJobResult(OcrJob job) {
    final result = job.result;
    if (result == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _resultScreenFromJob(job, result)),
    );
  }

  OcrResultScreen _resultScreenFromJob(OcrJob job, OcrJobResult result) {
    return buildResultScreen(result.data,
        imageBytes: job.primaryImageBytes);
  }

  Future<void> _openHistoryResult(AnalysisRecord r) async {
    if (r.id.isEmpty) return;
    try {
      final data = await AnalysisService.detail(r.id);
      if (!mounted) return;
      // Reuse the runner's nested extraction (result.backend_response.body
      // merged with sent_payload) so history opens with the same rich shape.
      final extracted = OcrJobRunner.extractResult(mapOf(data)) ?? mapOf(data);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => buildResultScreen(extracted),
        ),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedBuilder(
            animation: AnalysisJobsStore.I,
            builder: (context, _) {
              final running = AnalysisJobsStore.I.running;
              final history = AnalysisHistoryStore.items;
              return RefreshIndicator(
                onRefresh: _loadHistory,
                child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 24, bottom: 36),
                children: [
                  // 탭 진입(showBack=false) → 다른 탭과 동일한 DLens 헤더.
                  // 마이페이지에서 push(showBack=true) → 뒤로가기 + 제목.
                  if (!widget.showBack)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const AppLogo(fontSize: 22),
                        GestureDetector(
                          onTap: _loadHistory,
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.refresh,
                                size: 22, color: AppColors.textSub),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.only(
                                right: 10, top: 4, bottom: 4),
                            child: Icon(Icons.arrow_back_ios_new, size: 22),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            '분석',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _loadHistory,
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.refresh,
                                size: 22, color: AppColors.textSub),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  // 섹션 제목 — 탭 진입일 때만(push 헤더엔 이미 "분석" 제목이 있음)
                  if (!widget.showBack) ...[
                    const Text(
                      '분석',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  const Text(
                    '진행 중인 분석을 확인하고, 완료된 결과를 다시 볼 수 있어요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (running.isNotEmpty) ...[
                    _SectionTitle(text: '진행 중 ${running.length}건'),
                    const SizedBox(height: 10),
                    ...running.map((j) => _RunningJobCard(
                          job: j,
                          relativeText: _formatRelative(j.startedAt),
                          onTap: () => _openLoading(j),
                        )),
                    const SizedBox(height: 22),
                  ],

                  _SectionTitle(text: '분석 결과 ${history.length}건'),
                  const SizedBox(height: 10),
                  if (_loadingHistory)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (history.isEmpty &&
                      AnalysisJobsStore.I.completed.isEmpty)
                    const _EmptyState()
                  else ...[
                    // 이 세션에서 막 끝난 job — 빠르게 노출.
                    ...AnalysisJobsStore.I.completed.map((j) => _CompletedJobCard(
                          job: j,
                          dateText: _formatDate(j.startedAt),
                          onTap: () => _openJobResult(j),
                        )),
                    ...history.map((r) => _HistoryCard(
                          record: r,
                          color: _levelColors[r.riskLevel],
                          label: _levelLabels[r.riskLevel],
                          dateText: _formatDate(r.analyzedAt),
                          onTap: () => _openHistoryResult(r),
                        )),
                  ],
                ],
              ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textMain,
      ),
    );
  }
}

class _RunningJobCard extends StatelessWidget {
  final OcrJob job;
  final String relativeText;
  final VoidCallback onTap;

  const _RunningJobCard({
    required this.job,
    required this.relativeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                job.primaryImageBytes,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '분석 중',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relativeText,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12.5,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '눌러서 진행 화면 보기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedJobCard extends StatelessWidget {
  final OcrJob job;
  final String dateText;
  final VoidCallback onTap;

  const _CompletedJobCard({
    required this.job,
    required this.dateText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final productName = str(
      job.result?.data ?? {},
      ['product_name', 'name'],
      fallback: '분석 결과',
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                job.primaryImageBytes,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C77B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '완료',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF34C77B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textSub),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AnalysisRecord record;
  final Color color;
  final String label;
  final String dateText;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.record,
    required this.color,
    required this.label,
    required this.dateText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            if (record.imageUrl.isNotEmpty)
              ProductImage(
                url: record.imageUrl,
                width: 56,
                height: 56,
                borderRadius: 12,
                iconSize: 22,
              )
            else
              Container(
                width: 8,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (record.brand.isNotEmpty) ...[
                    Text(
                      record.brand,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        color: AppColors.textSub,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    // 우선순위: 성분 이름들 > 상품명 > 폴백.
                    record.ingredients.isNotEmpty
                        ? _AnalysesScreenState.shortIngredients(
                            record.ingredients)
                        : (record.productName.isEmpty
                            ? '분석 결과'
                            : record.productName),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textSub),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text(
            '아직 분석 결과가 없어요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '카메라로 성분표를 찍으면 결과가 여기 쌓여요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.5,
              color: AppColors.textSub,
            ),
          ),
        ],
      ),
    );
  }
}
