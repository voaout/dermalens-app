import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/beta_rewards_store.dart';

/// 🎯 베타 안내 광고 팝업.
///
/// 홈 화면 진입 시 [dismissedToday]가 아니면 자동 노출.
/// - "오늘 그만보기" → [BetaRewardsStore.I.dismissForToday]
/// - "닫기" → 그냥 dismiss (다음 진입에 다시 노출)
/// - "지금 등록하러 가기" → 성분 등록 화면으로 이동
///
/// 결과:
///   - `true`  → 지금 등록하러 가기
///   - `false` → 그냥 닫기
///   - `null`  → 오늘 그만보기 (또는 외부 dismiss)
Future<bool?> showBetaAnnouncementPopup(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _BetaPopup(),
  );
}

class _BetaPopup extends StatelessWidget {
  const _BetaPopup();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      // 작은 폰에서도 액션 버튼이 잘리지 않도록 vertical inset을 줄임.
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더 그라데이션 배너 (고정)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, Color(0xFF7C5CF0)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'BETA',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '성분 등록하고\n포인트 받아가세요',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'OCR로 제품 성분표를 찍어 DB를 함께 채워 주세요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12.5,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // 본문 — 혜택 / 주의점 (스크롤 가능: 작은 화면에서 넘쳐도
            // 아래 액션 버튼은 항상 보이게)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SectionTitle(text: '혜택'),
                  SizedBox(height: 8),
                  _BulletRow(
                    icon: Icons.workspace_premium,
                    color: Color(0xFFFFB02E),
                    title: '최초 등록자 5p',
                    desc: '제품별 최초 1명에게 보너스 포인트',
                  ),
                  _BulletRow(
                    icon: Icons.verified_outlined,
                    color: AppColors.primary,
                    title: '검증자 1p × 9명',
                    desc: '같은 제품 2~10번째 등록자도 적립',
                  ),
                  _BulletRow(
                    icon: Icons.local_offer_outlined,
                    color: Color(0xFF34C77B),
                    title: '쇼핑몰 연동 시 할인',
                    desc: '누적 포인트를 추후 쇼핑 할인에 사용',
                  ),
                  SizedBox(height: 14),
                  _SectionTitle(text: '주의'),
                  SizedBox(height: 8),
                  _BulletRow(
                    icon: Icons.group_outlined,
                    color: AppColors.textSub,
                    title: '제품당 선착순 10명',
                    desc: '10명을 초과하면 등록이 마감돼요',
                  ),
                  _BulletRow(
                    icon: Icons.repeat_rounded,
                    color: AppColors.textSub,
                    title: '한 사람당 같은 제품 1회',
                    desc: '이미 등록한 제품은 재시도가 안 돼요',
                  ),
                  _BulletRow(
                    icon: Icons.error_outline,
                    color: AppColors.danger,
                    title: 'OCR 실패 시 0p',
                    desc: '단, 실패는 시도 횟수에서 차감되지 않아요',
                  ),
                ],
                ),
              ),
            ),

            // 액션 (하단 고정 — 화면이 좁아도 항상 노출)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '지금 등록하러 가기',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            BetaRewardsStore.I.dismissForToday();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            '오늘 그만보기',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSub,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            '닫기',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        color: AppColors.textMain,
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;

  const _BulletRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppColors.textSub,
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
