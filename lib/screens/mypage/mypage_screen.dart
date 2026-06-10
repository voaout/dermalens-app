import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/beta_rewards_store.dart';
import '../../data/models/skin_type.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/parsing.dart';
import '../../data/services/user_service.dart';
import '../../data/user_profile.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/mirror_icon.dart';
import '../auth/splash_screen.dart';
import 'account_edit_screen.dart';
import 'allergy_edit_screen.dart';
import '../analyses/analyses_screen.dart';
import 'inquiry_screen.dart';
import 'liked_products_screen.dart';
import 'my_reviews_screen.dart';
import 'product_request_screen.dart';
import 'recommendation_history_screen.dart';
import 'satisfaction_screen.dart';
import 'side_effect_report_screen.dart';
import 'skin_type_edit_screen.dart';
import '../vanity/my_vanity_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPoints();
  }

  /// Hydrate the profile card from the mypage API (nickname / email / skin type).
  Future<void> _loadProfile() async {
    try {
      final data = await UserService.mypage();
      if (!mounted) return;
      final user = mapOf(mapOf(data)['user']);
      final skin = mapOf(mapOf(data)['skin_profile']);
      final nickname = '${user['nickname'] ?? ''}';
      final email = '${user['email'] ?? ''}';
      final skinType = '${skin['skin_type'] ?? ''}';
      if (nickname.isNotEmpty) UserProfile.nickname = nickname;
      if (email.isNotEmpty) UserProfile.email = email;
      if (skinType.isNotEmpty) {
        UserProfile.skinType = skinType;
        final st = SkinType.resolve(skinType);
        UserProfile.skinTypeCode = st?.code ?? '';
      }
      // 🎯 Beta — 마이페이지 user 객체에 points 필드가 함께 옴.
      final pts = user['points'];
      if (pts is num) {
        BetaRewardsStore.I.setTotalPoints(pts.toInt());
      }
      setState(() {});
    } on ApiException {
      // keep whatever is already in UserProfile
    }
  }

  /// 🎯 Beta — 누적 포인트 전용 엔드포인트. 마이페이지 응답의 points보다
  /// 더 정확한 최신 값이라 별도로 갱신.
  Future<void> _loadPoints() async {
    try {
      final data = await UserService.points();
      if (!mounted) return;
      final m = mapOf(data);
      final total = m['total_points'];
      if (total is num) {
        BetaRewardsStore.I.setTotalPoints(total.toInt());
        setState(() {});
      }
    } on ApiException {
      // 엔드포인트 미배포 등 — 무시.
    }
  }

  Future<void> _pushAndRefresh(
    Widget screen, {
    String? successMessage,
  }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    if (saved == true) {
      setState(() {});
      if (successMessage != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(successMessage),
            duration: const Duration(milliseconds: 1200),
          ));
      }
    }
  }

  Future<void> _openAccountEdit() =>
      _pushAndRefresh(const AccountEditScreen(), successMessage: '개인 정보가 변경되었어요.');

  Future<void> _openSkinTypeEdit() =>
      _pushAndRefresh(const SkinTypeEditScreen(), successMessage: '피부 타입이 변경되었어요.');

  Future<void> _openAllergyEdit() =>
      _pushAndRefresh(const AllergyEditScreen(), successMessage: '알레르기 정보가 변경되었어요.');

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: '로그아웃 하시겠어요?',
        message: '다시 사용하시려면 로그인이 필요해요.',
        confirmLabel: '로그아웃',
      ),
    );
    if (ok != true || !context.mounted) return;

    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmWithdraw(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: '정말 탈퇴할까요?',
        message: '저장된 분석 기록과 좋아요 목록이 모두 삭제됩니다.',
        confirmLabel: '회원탈퇴',
        destructive: true,
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await AuthService.withdraw();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('회원탈퇴가 완료되었어요.'),
        duration: Duration(milliseconds: 1400),
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppLogo(fontSize: 22),
              // 🎯 Beta — 우상단 누적 포인트 배지 (피부타입 옆 자리).
              AnimatedBuilder(
                animation: BetaRewardsStore.I,
                builder: (context, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${BetaRewardsStore.I.totalPoints}p',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 22),

          _ProfileCard(
            name: UserProfile.nickname,
            email: UserProfile.email,
            skinType: UserProfile.skinType,
            onEdit: _openAccountEdit,
          ),

          const SizedBox(height: 24),

          _SettingsGroup(
            title: '내 정보',
            items: [
              _MenuItem(
                icon: Icons.face_outlined,
                label: '피부 타입 수정',
                onTap: _openSkinTypeEdit,
              ),
              _MenuItem(
                icon: Icons.health_and_safety_outlined,
                label: '알레르기 수정',
                onTap: _openAllergyEdit,
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SettingsGroup(
            title: '활동 내역',
            items: [
              _MenuItem(
                icon: Icons.rate_review_outlined,
                label: '작성한 리뷰',
                onTap: () => _pushAndRefresh(const MyReviewsScreen()),
              ),
              _MenuItem(
                icon: Icons.favorite_border,
                label: '좋아요 목록',
                onTap: () => _pushAndRefresh(const LikedProductsScreen()),
              ),
              _MenuItem(
                icon: Icons.receipt_long_outlined,
                label: '분석 기록',
                onTap: () => _pushAndRefresh(
                  const AnalysesScreen(showBack: true),
                ),
              ),
              _MenuItem(
                icon: Icons.lightbulb_outline,
                label: '추천 기록',
                onTap: () =>
                    _pushAndRefresh(const RecommendationHistoryScreen()),
              ),
              _MenuItem(
                leading: const MirrorIcon(size: 22, color: AppColors.textMain),
                label: '나의 화장 순서',
                onTap: () => _pushAndRefresh(const MyVanityScreen()),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SettingsGroup(
            title: '고객센터',
            items: [
              _MenuItem(
                icon: Icons.add_box_outlined,
                label: '상품 등록 요청',
                onTap: () => _pushAndRefresh(const ProductRequestScreen()),
              ),
              _MenuItem(
                icon: Icons.support_agent_outlined,
                label: '문의하기',
                onTap: () => _pushAndRefresh(const InquiryScreen()),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SettingsGroup(
            title: '피드백',
            items: [
              _MenuItem(
                icon: Icons.report_gmailerrorred_outlined,
                label: '부작용 신고',
                onTap: () => _pushAndRefresh(const SideEffectReportScreen()),
              ),
              _MenuItem(
                icon: Icons.star_border_rounded,
                label: '만족도 평가',
                onTap: () => _pushAndRefresh(const SatisfactionScreen()),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SettingsGroup(
            title: '계정',
            items: [
              _MenuItem(
                icon: Icons.logout,
                label: '로그아웃',
                onTap: () => _confirmLogout(context),
                showChevron: false,
              ),
              _MenuItem(
                icon: Icons.person_remove_outlined,
                label: '회원탈퇴',
                onTap: () => _confirmWithdraw(context),
                showChevron: false,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------- profile card --------

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String skinType;
  final VoidCallback onEdit;

  const _ProfileCard({
    required this.name,
    required this.email,
    required this.skinType,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              name.isNotEmpty ? name.substring(0, 1) : '·',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        skinType.isEmpty ? '피부타입 미설정' : '$skinType 피부',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    color: AppColors.textSub,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: const Row(
                children: [
                  Text(
                    '편집',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------- settings group --------

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _SettingsGroup({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSub,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.border,
                    indent: 56,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String label;
  final VoidCallback onTap;
  final bool showChevron;
  final bool destructive;

  const _MenuItem({
    this.icon,
    this.leading,
    required this.label,
    required this.onTap,
    this.showChevron = true,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFE15252) : AppColors.textMain;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Center(
                child: leading ?? Icon(icon, size: 22, color: color),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            if (showChevron)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSub,
              ),
          ],
        ),
      ),
    );
  }
}

// -------- confirm dialog --------

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final confirmColor =
        destructive ? const Color(0xFFE15252) : AppColors.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13.5,
          height: 1.5,
          color: AppColors.textSub,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            '취소',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              color: AppColors.textSub,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w800,
              color: confirmColor,
            ),
          ),
        ),
      ],
    );
  }
}
