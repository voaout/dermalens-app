import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';
import '../../data/models/skin_type.dart';
import '../../data/services/parsing.dart';
import '../../data/services/product_service.dart';
import '../../data/services/routine_service.dart';
import '../../data/user_profile.dart';
import '../../data/vanity_store.dart';
import '../../widgets/common/product_image.dart';
import '../product/product_detail_screen.dart';

class MyVanityScreen extends StatefulWidget {
  const MyVanityScreen({super.key});

  @override
  State<MyVanityScreen> createState() => _MyVanityScreenState();
}

class _MyVanityScreenState extends State<MyVanityScreen> {
  final _titleController = TextEditingController();

  // Editor state — the routine currently being built/edited.
  // 각 step은 백엔드 저장에 필요한 product_id를 같이 들고 있음.
  final List<RoutineStep> _steps = [];
  Object? _editingId; // null = creating a new routine.

  // Loaded data.
  List<Routine> _myRoutines = [];
  List<PopularRoutine> _popular = [];

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String? get _skinTypeCode {
    if (UserProfile.skinTypeCode.isNotEmpty) return UserProfile.skinTypeCode;
    return SkinType.resolve(UserProfile.skinType)?.code;
  }

  String get _skinTypeLabel {
    final code = _skinTypeCode;
    if (code != null && code.isNotEmpty) return code;
    return UserProfile.skinType.isEmpty ? '내' : UserProfile.skinType;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([_loadMyRoutines(), _loadPopular()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMyRoutines() async {
    if (!AuthSession.isLoggedIn) return;
    try {
      final data = await RoutineService.myRoutines();
      if (!mounted) return;
      setState(() {
        _myRoutines = listOf(data).map(Routine.fromJson).toList();
      });
    } on ApiException {
      // optional — ignore failures.
    }
  }

  Future<void> _loadPopular() async {
    final code = _skinTypeCode;
    if (code == null || code.isEmpty) return;
    try {
      final data = await RoutineService.popular(code);
      if (!mounted) return;
      setState(() {
        _popular = listOf(data).map(PopularRoutine.fromJson).toList();
      });
    } on ApiException {
      // optional — ignore failures.
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 루틴 스텝(자기 루틴이든 인기 루틴이든)에서 상품 칩 탭 시 호출.
  /// product_id로 상세를 받아 ProductDetailScreen으로 이동.
  Future<void> _openProduct(Object productId) async {
    try {
      final data = await ProductService.detail(productId);
      if (!mounted) return;
      final raw = mapOf(data);
      final productMap = raw['product'] is Map
          ? (raw['product'] as Map).cast<String, dynamic>()
          : raw;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: normalizeProduct(productMap),
          ),
        ),
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }

  Future<void> _addStep() async {
    // 백엔드가 product_id를 요구하므로 텍스트 자유입력 대신 제품 검색에서
    // 한 개를 골라 step으로 추가합니다.
    final picked = await showModalBottomSheet<RoutineStep>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked != null) {
      setState(() => _steps.add(picked));
    }
  }

  void _removeStep(int index) => setState(() => _steps.removeAt(index));

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, item);
    });
  }

  void _resetEditor() {
    setState(() {
      _editingId = null;
      _titleController.clear();
      _steps.clear();
    });
  }

  void _editRoutine(Routine r) {
    setState(() {
      _editingId = r.id;
      _titleController.text = r.title;
      _steps
        ..clear()
        ..addAll(r.steps);
    });
    _showSnack('루틴을 편집 중이에요. 수정 후 저장해 주세요.');
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!AuthSession.isLoggedIn) {
      _showSnack('로그인이 필요해요.');
      return;
    }
    if (_steps.isEmpty) {
      _showSnack('단계를 한 개 이상 추가해 주세요.');
      return;
    }
    final title = _titleController.text.trim().isEmpty
        ? '내 루틴'
        : _titleController.text.trim();

    setState(() => _saving = true);
    try {
      if (_editingId == null) {
        await RoutineService.create(title: title, steps: List.of(_steps));
      } else {
        await RoutineService.update(_editingId!,
            title: title, steps: List.of(_steps));
      }
      _resetEditor();
      await _loadMyRoutines();
      _showSnack('루틴을 저장했어요.');
    } on ApiException catch (e) {
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRoutine(Routine r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('루틴 삭제'),
        content: Text('“${r.title}” 루틴을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || r.id == null) return;
    try {
      await RoutineService.delete(r.id!);
      if (_editingId == r.id) _resetEditor();
      await _loadMyRoutines();
      _showSnack('루틴을 삭제했어요.');
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
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
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      '나의 화장대',
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                      children: [
                        const Text(
                          '내가 쓰는 화장품을 사용 순서대로 기록하고,\n같은 피부 타입 유저들의 인기 루틴을 확인해 보세요.',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13.5,
                            height: 1.5,
                            color: AppColors.textSub,
                          ),
                        ),
                        const SizedBox(height: 22),

                        _buildEditor(),

                        if (_myRoutines.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _buildSavedRoutines(),
                        ],

                        const SizedBox(height: 28),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 22),

                        _buildPopular(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 루틴 편집기 ---
  Widget _buildEditor() {
    final isEditing = _editingId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isEditing ? '루틴 수정' : '새 루틴',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${_steps.length}단계',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSub,
              ),
            ),
            const Spacer(),
            if (isEditing)
              GestureDetector(
                onTap: _resetEditor,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    '새로 만들기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSub,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 루틴 제목
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '루틴 이름 (예: 아침 루틴)',
              isCollapsed: true,
              contentPadding: EdgeInsets.symmetric(vertical: 15),
              hintStyle: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14.5,
                color: AppColors.textSub,
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_steps.isEmpty)
          _EmptyRoutine(onAdd: _addStep)
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _steps.length,
            onReorder: _onReorder,
            itemBuilder: (context, i) {
              return _StepCard(
                key: ValueKey('step-$i-${_steps[i].productId ?? _steps[i].name}'),
                index: i,
                step: _steps[i],
                onRemove: () => _removeStep(i),
              );
            },
          ),

        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _addStep,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        '단계 추가',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _saving ? null : _save,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          isEditing ? '수정 저장' : '루틴 저장',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 저장한 루틴 목록 ---
  Widget _buildSavedRoutines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '저장한 루틴 ${_myRoutines.length}개',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 14),
        ..._myRoutines.map(
          (r) => _SavedRoutineCard(
            routine: r,
            onEdit: () => _editRoutine(r),
            onDelete: () => _deleteRoutine(r),
            onProductTap: _openProduct,
          ),
        ),
      ],
    );
  }

  // --- 인기 루틴 ---
  Widget _buildPopular() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_skinTypeLabel 피부 타입 인기 루틴',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '나와 같은 피부 타입 유저들이 많이 쓰는 순서예요.',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12.5,
            color: AppColors.textSub,
          ),
        ),
        const SizedBox(height: 14),
        if (_skinTypeCode == null || _skinTypeCode!.isEmpty)
          const Text(
            '피부 타입을 설정하면 인기 루틴을 볼 수 있어요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: AppColors.textSub,
            ),
          )
        else if (_popular.isEmpty)
          const Text(
            '아직 집계된 인기 루틴이 없어요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: AppColors.textSub,
            ),
          )
        else
          ..._popular.map((r) => _PopularRoutineCard(
                routine: r,
                skinTypeLabel: _skinTypeLabel,
                onProductTap: _openProduct,
              )),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final RoutineStep step;
  final VoidCallback onRemove;

  const _StepCard({
    super.key,
    required this.index,
    required this.step,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 18, color: AppColors.textSub),
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(left: 2, right: 4),
              child: Icon(Icons.drag_handle, size: 20, color: AppColors.textSub),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedRoutineCard extends StatelessWidget {
  final Routine routine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  /// 칩 탭 시 호출 — productId가 있을 때만 chip이 탭 가능.
  final void Function(Object productId)? onProductTap;

  const _SavedRoutineCard({
    required this.routine,
    required this.onEdit,
    required this.onDelete,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  routine.title,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.textSub),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < routine.steps.length; i++) ...[
                if (i > 0)
                  const Icon(Icons.chevron_right,
                      size: 16, color: AppColors.textSub),
                _ProductStepChip(
                  step: routine.steps[i],
                  onTap: onProductTap,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 루틴 스텝 칩. productId가 있으면 탭 가능(상품 상세로 이동).
class _ProductStepChip extends StatelessWidget {
  final RoutineStep step;
  final void Function(Object productId)? onTap;

  const _ProductStepChip({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pid = step.productId;
    final tappable = pid != null && onTap != null;
    // 부모(Wrap)의 폭을 초과하지 않도록 최대 폭을 제한 — 긴 상품명에서 overflow 방지.
    final chip = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: tappable
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.25))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                step.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            if (tappable) ...[
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right,
                  size: 14, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
    if (!tappable) return chip;
    return GestureDetector(
      onTap: () => onTap!(pid),
      behavior: HitTestBehavior.opaque,
      child: chip,
    );
  }
}

class _EmptyRoutine extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyRoutine({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_circle_outline, size: 28, color: AppColors.primary),
            SizedBox(height: 8),
            Text(
              '사용하는 제품을 순서대로 추가해 보세요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularRoutineCard extends StatelessWidget {
  final PopularRoutine routine;
  final String skinTypeLabel;
  /// 칩 탭 시 호출 — productId가 있을 때만 chip이 탭 가능.
  final void Function(Object productId)? onProductTap;

  const _PopularRoutineCard({
    required this.routine,
    required this.skinTypeLabel,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13.5,
                color: AppColors.textMain,
              ),
              children: [
                TextSpan(
                  text: '$skinTypeLabel 피부 유저 ',
                  style: const TextStyle(color: AppColors.textSub),
                ),
                TextSpan(
                  text: '${routine.percent}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const TextSpan(
                  text: '가 이 순서로 사용해요',
                  style: TextStyle(color: AppColors.textSub),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < routine.steps.length; i++) ...[
                if (i > 0)
                  const Icon(Icons.chevron_right,
                      size: 16, color: AppColors.textSub),
                _ProductStepChip(
                  step: routine.steps[i],
                  onTap: onProductTap,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 제품 검색 → 한 개 선택 → step으로 반환하는 모달 시트.
/// 백엔드 routine API가 `product_id`를 요구하므로 자유 입력 대신 DB에서 고름.
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final data = await ProductService.search(q);
      if (!mounted) return;
      setState(() {
        _results = listOf(data).map(normalizeProduct).toList();
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _pick(Map<String, dynamic> product) {
    final id = product['id'];
    if (id == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('이 제품은 id가 없어 선택할 수 없어요.')),
        );
      return;
    }
    Navigator.pop(
      context,
      RoutineStep(productId: id, name: '${product['name'] ?? ''}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '제품 선택',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search,
                          size: 20, color: AppColors.textSub),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: _onQueryChanged,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _search,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 14),
                            hintText: '제품명, 브랜드 검색',
                            hintStyle: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              color: AppColors.textSub,
                            ),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _searching
                      ? const Center(child: CircularProgressIndicator())
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.trim().isEmpty
                                    ? '단계에 추가할 제품을 검색해 주세요.'
                                    : '검색 결과가 없어요.',
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  color: AppColors.textSub,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final p = _results[i];
                                return GestureDetector(
                                  onTap: () => _pick(p),
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(
                                    children: [
                                      ProductImage(
                                        url: p['imageUrl'],
                                        width: 48,
                                        height: 48,
                                        borderRadius: 10,
                                        iconSize: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${p['brand'] ?? ''}',
                                              style: const TextStyle(
                                                fontFamily: 'Pretendard',
                                                fontSize: 11.5,
                                                color: AppColors.textSub,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${p['name'] ?? ''}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: 'Pretendard',
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textMain,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.add_circle_outline,
                                          color: AppColors.primary),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
