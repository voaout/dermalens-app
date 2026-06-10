import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/models/skin_type.dart';
import '../../data/services/user_service.dart';
import '../../data/user_profile.dart';
import '../../widgets/common/primary_button.dart';
import '../survey/survey_screen.dart';

class SkinTypeEditScreen extends StatefulWidget {
  const SkinTypeEditScreen({super.key});

  @override
  State<SkinTypeEditScreen> createState() => _SkinTypeEditScreenState();
}

class _SkinTypeEditScreenState extends State<SkinTypeEditScreen> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = UserProfile.skinType;
  }

  bool get _hasChanges => _selected != UserProfile.skinType;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await UserService.updateSkinProfile({'skin_type': _selected});
      UserProfile.skinType = _selected;
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSurvey() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SurveyScreen()),
    );
    if (!mounted) return;
    // The survey writes back to UserProfile.skinType on submit; refresh the
    // local selection so the chips reflect the new value.
    setState(() {
      _selected = UserProfile.skinType;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      '피부 타입 수정',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                children: [
                  const Text(
                    '피부 타입을 직접 선택하거나, 설문으로 정확히 진단할 수 있어요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Builder(
                    builder: (context) {
                      final st = SkinType.byCode(UserProfile.skinTypeCode) ??
                          SkinType.resolve(UserProfile.skinType);
                      final label = st?.label ??
                          (UserProfile.skinType.isEmpty
                              ? '미설정'
                              : UserProfile.skinType);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.face_outlined,
                                    size: 20, color: AppColors.primaryDark),
                                const SizedBox(width: 10),
                                const Text(
                                  '현재 등록된 타입',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const Spacer(),
                                Flexible(
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (st != null) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                st.description,
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: AppColors.textSub,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 26),
                  const Text(
                    '직접 선택',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UserProfile.skinTypeOptions.map((type) {
                      final isSel = _selected == type;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary : AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSel ? Colors.white : AppColors.primaryDark,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 26),
                  PrimaryButton(
                    text: _hasChanges ? '저장' : '변경사항 없음',
                    onTap: _save,
                    backgroundColor:
                        _hasChanges ? AppColors.primary : AppColors.border,
                  ),

                  const SizedBox(height: 30),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '또는',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            color: AppColors.textSub,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  GestureDetector(
                    onTap: _openSurvey,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.primary, width: 1.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.assignment_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '설문으로 정확히 알아보기',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '8가지 문항으로 피부 타입을 진단해 자동 등록해드려요.',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 12,
                                    color: AppColors.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.primary),
                        ],
                      ),
                    ),
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
