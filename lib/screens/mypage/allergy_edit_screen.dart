import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/services/user_service.dart';
import '../../data/user_profile.dart';
import '../../widgets/common/primary_button.dart';

class AllergyEditScreen extends StatefulWidget {
  const AllergyEditScreen({super.key});

  @override
  State<AllergyEditScreen> createState() => _AllergyEditScreenState();
}

class _AllergyEditScreenState extends State<AllergyEditScreen> {
  late Set<String> _selected;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(UserProfile.allergies);
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

  bool get _hasChanges {
    return _selected.length != UserProfile.allergies.length ||
        !_selected.containsAll(UserProfile.allergies);
  }

  void _toggle(String item) {
    setState(() {
      if (!_selected.add(item)) _selected.remove(item);
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _query = '';
    });
    FocusScope.of(context).unfocus();
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await UserService.updateSkinProfile({'allergies': _selected.toList()});
      UserProfile.allergies
        ..clear()
        ..addAll(_selected);
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

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

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
                      '알레르기 / 기피 성분',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '검색해서 기피 성분을 추가하거나 제거할 수 있어요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SearchField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    onClear: _clearSearch,
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '등록한 성분 · ${_selected.length}',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSub,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selected.map((item) {
                        return _SelectedChip(
                          label: item,
                          onRemove: () => _toggle(item),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: results.isEmpty
                  ? const _EmptyResult()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.border,
                        indent: 24,
                        endIndent: 24,
                      ),
                      itemBuilder: (_, i) {
                        final item = results[i];
                        final isSel = _selected.contains(item);
                        return _AllergyRow(
                          label: item,
                          isSelected: isSel,
                          onTap: () => _toggle(item),
                        );
                      },
                    ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              child: PrimaryButton(
                text: _hasChanges ? '저장' : '변경사항 없음',
                onTap: _save,
                backgroundColor:
                    _hasChanges ? AppColors.primary : AppColors.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: AppColors.textSub),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '성분 검색 (예: 향료, 파라벤)',
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                color: AppColors.textMain,
              ),
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 18, color: AppColors.textSub),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _SelectedChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 8, top: 7, bottom: 7),
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

class _AllergyRow extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AllergyRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textMain,
                ),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : AppColors.primaryLight,
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.add,
                size: 16,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 36, color: AppColors.textSub),
            SizedBox(height: 10),
            Text(
              '검색 결과가 없어요.',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                color: AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
