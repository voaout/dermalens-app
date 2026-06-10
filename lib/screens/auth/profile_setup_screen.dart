import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/models/skin_type.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/user_service.dart';
import '../../data/user_profile.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/primary_button.dart';
import '../main/main_tab_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String name;
  final String email;
  final String password;

  const ProfileSetupScreen({
    super.key,
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  /// 선택된 피부 타입 코드 (예: "OS+"). null이면 미선택.
  String? _selectedSkinCode;

  /// 사용자가 고른 알레르기 성분 (전체 [UserProfile.allergyOptions]에서 부분 집합).
  final Set<String> _selectedAllergies = {};

  bool _loading = false;

  /// 프로필 설정 화면에 미리 노출하는 인기 알레르기 8개.
  /// 더 많은 항목을 보고 싶으면 "자세히 보기"로 전체 목록을 연다.
  static const _previewAllergies = [
    '향료',
    '알코올',
    '파라벤',
    '페녹시에탄올',
    '에센셜오일',
    '라놀린',
    '인공향료',
    '메틸이소티아졸리논(MIT)',
  ];

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggleAllergy(String item) {
    setState(() {
      if (!_selectedAllergies.add(item)) {
        _selectedAllergies.remove(item);
      }
    });
  }

  Future<void> _openAllergySheet() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AllergyPickerSheet(
        initialSelected: Set<String>.from(_selectedAllergies),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedAllergies
          ..clear()
          ..addAll(result);
      });
    }
  }

  /// 회원가입 + (선택 시) 피부 프로필 저장.
  Future<void> _complete({required bool withProfile}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthService.signup(
        email: widget.email,
        password: widget.password,
        nickname: widget.name,
      );

      UserProfile.nickname = widget.name;
      UserProfile.email = widget.email;

      if (withProfile && _selectedSkinCode != null) {
        final st = SkinType.byCode(_selectedSkinCode!);
        UserProfile.skinTypeCode = _selectedSkinCode!;
        UserProfile.skinType = st?.nameKr ?? _selectedSkinCode!;
        UserProfile.allergies
          ..clear()
          ..addAll(_selectedAllergies);
        await UserService.updateSkinProfile({
          'skin_type': _selectedSkinCode,
          'skin_type_name': st?.nameKr,
          'allergies': _selectedAllergies.toList(),
        });
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainTabScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 52),
              const AppLogo(fontSize: 36, goHomeOnTap: false),
              const SizedBox(height: 42),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 피부 타입 ──────────────────────────────
                      const Text(
                        '피부 타입',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '잘 모르겠다면 가입 후 마이페이지의 피부 진단으로 확인할 수 있어요.',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: AppColors.textSub,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SkinType.all.map((st) {
                          final isSelected = _selectedSkinCode == st.code;
                          return _SkinTypeChip(
                            label: st.displayName,
                            sub: st.code,
                            selected: isSelected,
                            onTap: () => setState(
                              () => _selectedSkinCode = st.code,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // ── 알레르기 / 기피 성분 ──────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '알레르기 / 기피 성분',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedAllergies.isEmpty
                                      ? '인기 성분을 선택하거나, 자세히 보기로 전체 목록을 확인하세요.'
                                      : '선택 ${_selectedAllergies.length}개',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 12,
                                    color: AppColors.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _openAllergySheet,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    '자세히 보기 (${UserProfile.allergyOptions.length})',
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _previewAllergies.map((item) {
                          final isSelected =
                              _selectedAllergies.contains(item);
                          return GestureDetector(
                            onTap: () => _toggleAllergy(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textMain,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // 자세히 보기로 고른 인기 외 항목들 — 추가 선택을 카드 아래에 별도 표시.
                      if (_selectedAllergies
                          .any((a) => !_previewAllergies.contains(a))) ...[
                        const SizedBox(height: 14),
                        const Text(
                          '추가 선택',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSub,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedAllergies
                              .where((a) => !_previewAllergies.contains(a))
                              .map((a) => _SelectedChip(
                                    label: a,
                                    onRemove: () => _toggleAllergy(a),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    _loading ? null : () => _complete(withProfile: false),
                child: const Text(
                  '다음에 할게요',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _loading
                  ? Container(
                      width: double.infinity,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    )
                  : PrimaryButton(
                      text: '완료',
                      onTap: () => _complete(withProfile: true),
                    ),
              const SizedBox(height: 34),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== 피부타입 칩 ===================

class _SkinTypeChip extends StatelessWidget {
  final String label; // 예: "민지형"
  final String sub;   // 예: "OS+"
  final bool selected;
  final VoidCallback onTap;

  const _SkinTypeChip({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textMain,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              sub,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== 추가 선택 칩 (× 제거) ===================

class _SelectedChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _SelectedChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
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
              label,
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
    );
  }
}

// =================== 알레르기 전체 선택 시트 ===================

/// 가입 전 단계에서 띄우는 알레르기 선택 시트.
///
/// 이미 가입한 사용자가 쓰는 [AllergyEditScreen]은 백엔드에 즉시 저장하지만,
/// 이 시트는 가입 전이라 저장하지 않고 선택 결과만 Set으로 돌려준다.
class _AllergyPickerSheet extends StatefulWidget {
  final Set<String> initialSelected;
  const _AllergyPickerSheet({required this.initialSelected});

  @override
  State<_AllergyPickerSheet> createState() => _AllergyPickerSheetState();
}

class _AllergyPickerSheetState extends State<_AllergyPickerSheet> {
  late Set<String> _selected;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_query.isEmpty) return UserProfile.allergyOptions;
    final q = _query.toLowerCase();
    return UserProfile.allergyOptions
        .where((item) => item.toLowerCase().contains(q))
        .toList();
  }

  void _toggle(String item) {
    setState(() {
      if (!_selected.add(item)) _selected.remove(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '알레르기 / 기피 성분',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                  Text(
                    '${_selected.length}개 선택',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search,
                        size: 20, color: AppColors.textSub),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '성분 검색 (예: 향료, 파라벤)',
                          isCollapsed: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 13),
                        ),
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.clear();
                            _query = '';
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close,
                              size: 18, color: AppColors.textSub),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          '검색 결과가 없어요.',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            color: AppColors.textSub,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.border,
                        indent: 20,
                        endIndent: 20,
                      ),
                      itemBuilder: (_, i) {
                        final item = _filtered[i];
                        final isSel = _selected.contains(item);
                        return InkWell(
                          onTap: () => _toggle(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 14.5,
                                      fontWeight: isSel
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSel
                                          ? AppColors.primary
                                          : AppColors.textMain,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSel
                                        ? AppColors.primary
                                        : AppColors.primaryLight,
                                  ),
                                  child: Icon(
                                    isSel ? Icons.check : Icons.add,
                                    size: 16,
                                    color: isSel
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: PrimaryButton(
                text: '완료',
                onTap: () => Navigator.pop(context, _selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
