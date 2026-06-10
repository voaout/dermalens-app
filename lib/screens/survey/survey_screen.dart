import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';
import '../../data/services/parsing.dart';
import '../../data/services/user_service.dart';
import '../../data/user_profile.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/glass/glass_chip.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

// -------- data models --------

class _ScoredOption {
  final String label;
  final int oil;
  final int dehydrated;
  final int sensitive;

  const _ScoredOption(
    this.label, {
    this.oil = 0,
    this.dehydrated = 0,
    this.sensitive = 0,
  });
}

class _ScoredQuestion {
  final String key;
  final String prompt;
  final List<_ScoredOption> options;

  const _ScoredQuestion({
    required this.key,
    required this.prompt,
    required this.options,
  });
}

class _IdOption {
  final int id;
  final String label;
  const _IdOption(this.id, this.label);
}

class _PlainQuestion {
  final String prompt;
  final List<String> options;
  const _PlainQuestion(this.prompt, this.options);
}

// -------- survey data --------

const List<_ScoredQuestion> _skinTypeQuestions = [
  _ScoredQuestion(
    key: 'cleanse',
    prompt: '세안 후 피부 상태는 어떤가요?',
    options: [
      _ScoredOption('매우 당김', dehydrated: 2),
      _ScoredOption('약간 당김', dehydrated: 1),
      _ScoredOption('적당', oil: 1),
      _ScoredOption('약간 번들', oil: 2),
      _ScoredOption('매우 번들', oil: 3),
    ],
  ),
  _ScoredQuestion(
    key: 'afternoon',
    prompt: '오후가 되면 피부 상태는 어떤가요?',
    options: [
      _ScoredOption('건조함', dehydrated: 2),
      _ScoredOption('보통', oil: 1),
      _ScoredOption('번들거림', oil: 2),
    ],
  ),
  _ScoredQuestion(
    key: 'irritation',
    prompt: '피부가 쉽게 자극을 받나요?',
    options: [
      _ScoredOption('매우 그렇다', sensitive: 3),
      _ScoredOption('그렇다', sensitive: 2),
      _ScoredOption('보통', sensitive: 1),
      _ScoredOption('아니다'),
    ],
  ),
  _ScoredQuestion(
    key: 'trouble',
    prompt: '화장품 사용 후 트러블이 자주 생기나요?',
    options: [
      _ScoredOption('자주', sensitive: 2),
      _ScoredOption('가끔', sensitive: 1),
      _ScoredOption('거의 없음'),
    ],
  ),
  _ScoredQuestion(
    key: 'oil_amount',
    prompt: '하루 중 피부 유분량은?',
    options: [
      _ScoredOption('거의 없음'),
      _ScoredOption('적당', oil: 1),
      _ScoredOption('많음', oil: 3),
    ],
  ),
  _ScoredQuestion(
    key: 'inner_tight',
    prompt: '피부 속당김을 자주 느끼나요?',
    options: [
      _ScoredOption('자주 느낀다', dehydrated: 3),
      _ScoredOption('가끔 느낀다', dehydrated: 1),
      _ScoredOption('거의 없다'),
    ],
  ),
  _ScoredQuestion(
    key: 'redness',
    prompt: '피부가 붉어지거나 따가운 편인가요?',
    options: [
      _ScoredOption('자주 그렇다', sensitive: 3),
      _ScoredOption('가끔 그렇다', sensitive: 1),
      _ScoredOption('거의 없다'),
    ],
  ),
  _ScoredQuestion(
    key: 'flakes',
    prompt: '각질이 자주 올라오나요?',
    options: [
      _ScoredOption('자주', dehydrated: 2),
      _ScoredOption('가끔', dehydrated: 1),
      _ScoredOption('거의 없음'),
    ],
  ),
];

const List<_IdOption> _concernsMaster = [
  _IdOption(1, '여드름'),
  _IdOption(2, '홍조'),
  _IdOption(3, '건조'),
  _IdOption(4, '민감성'),
  _IdOption(5, '미백'),
  _IdOption(6, '탄력'),
  _IdOption(7, '모공'),
  _IdOption(8, '주름'),
  _IdOption(9, '피지과다'),
  _IdOption(10, '피부장벽'),
];

const List<_IdOption> _sensitivityLevels = [
  _IdOption(5, '매우 민감'),
  _IdOption(4, '민감'),
  _IdOption(3, '보통'),
  _IdOption(2, '둔감'),
  _IdOption(1, '매우 둔감'),
];

const List<_IdOption> _allergiesMaster = [
  _IdOption(1, '향료'),
  _IdOption(2, '알코올'),
  _IdOption(3, '에센셜오일'),
  _IdOption(4, '파라벤'),
  _IdOption(5, '색소'),
  _IdOption(6, '설페이트'),
  _IdOption(7, '실리콘'),
  _IdOption(8, '산성분(AHA/BHA)'),
  _IdOption(9, '레티놀'),
  _IdOption(10, '특정 추출물'),
];

const List<_IdOption> _texturesMaster = [
  _IdOption(1, '워터'),
  _IdOption(2, '젤'),
  _IdOption(3, '로션'),
  _IdOption(4, '에멀전'),
  _IdOption(5, '크림'),
  _IdOption(6, '밤'),
  _IdOption(7, '오일'),
  _IdOption(8, '패드'),
  _IdOption(9, '미스트'),
  _IdOption(10, '스틱'),
];

const _toneQuestion = _PlainQuestion(
  '피부톤 고민이 있나요?',
  ['없음', '칙칙함', '색소침착'],
);
const _poreQuestion = _PlainQuestion(
  '모공 상태는 어떤가요?',
  ['거의 없음', '보통', '넓음'],
);
const _elasticityQuestion = _PlainQuestion(
  '피부 탄력은 어떤가요?',
  ['좋음', '보통', '떨어짐'],
);

// -------- screen --------

class _SurveyScreenState extends State<SurveyScreen> {
  final Map<String, int> _skinTypeAnswers = {};
  final Set<int> _concernIds = {};
  int? _sensitivityLevel;
  bool? _acneProne;
  final Set<int> _allergyIds = {};
  int? _textureId;
  int? _toneIdx;
  int? _poreIdx;
  int? _elasticityIdx;

  int get _totalRequired => _skinTypeQuestions.length + 5;
  int get _answeredRequired {
    var n = _skinTypeAnswers.length;
    if (_sensitivityLevel != null) n++;
    if (_acneProne != null) n++;
    if (_toneIdx != null) n++;
    if (_poreIdx != null) n++;
    if (_elasticityIdx != null) n++;
    return n;
  }

  double get _progress =>
      _totalRequired == 0 ? 0 : _answeredRequired / _totalRequired;

  bool get _canSubmit => _answeredRequired == _totalRequired;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) {
      _showSnack('아직 답하지 않은 필수 문항이 있어요.');
      return;
    }

    var oil = 0;
    var dehydrated = 0;
    var sensitive = 0;
    for (final q in _skinTypeQuestions) {
      final opt = q.options[_skinTypeAnswers[q.key]!];
      oil += opt.oil;
      dehydrated += opt.dehydrated;
      sensitive += opt.sensitive;
    }

    var estimated = _estimateSkinType(
      oil: oil,
      dehydrated: dehydrated,
      sensitive: sensitive,
    );

    // Submit to the backend; it returns the authoritative skin-type
    // classification ("설문 응답 저장 → 피부타입 자동 분류").
    if (AuthSession.isLoggedIn) {
      try {
        final res = await UserService.submitSurvey(_buildSurveyPayload());
        final result = mapOf(mapOf(res)['result']);
        final serverType = result['skin_type_name'] ?? mapOf(res)['skin_type'];
        if (serverType is String && serverType.isNotEmpty) {
          estimated = serverType;
        }
        // The code (e.g. "DN+") is the most reliable key for the master table.
        final code = result['skin_type_code'];
        if (code is String && code.isNotEmpty) {
          UserProfile.skinTypeCode = code;
        }
      } on ApiException catch (e) {
        if (!mounted) return;
        _showSnack(e.message);
        return;
      }
    }

    // Save the resulting skin type so other screens reflect it.
    UserProfile.skinType = estimated;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _SurveyResultDialog(
        estimatedType: estimated,
        oilScore: oil,
        dehydratedScore: dehydrated,
        sensitiveScore: sensitive,
        sensitivityLevel: _sensitivityLevel!,
        acneProne: _acneProne!,
        concernCount: _concernIds.length,
        allergyCount: _allergyIds.length,
      ),
    );

    if (!mounted) return;
    // If the survey was pushed on top of another screen (e.g. the skin type
    // edit screen), close it so the caller can refresh. As a standalone tab
    // there's nothing to pop and we just stay on the screen.
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // The survey API expects `{ user_id, selected_option_ids: [...] }`.
  // Option IDs are assigned sequentially in question-definition order:
  // Q1 options → 1..5, Q2 → 6..8, ... then 피부톤 / 모공 / 탄력.
  // TODO(backend): replace with the real SurveyOption id map if the order
  // differs from the backend's master table.
  Map<String, dynamic> _buildSurveyPayload() {
    final ids = <int>[];
    var base = 0;

    for (final q in _skinTypeQuestions) {
      final sel = _skinTypeAnswers[q.key];
      if (sel != null) ids.add(base + sel + 1);
      base += q.options.length;
    }

    void addPlain(_PlainQuestion q, int? idx) {
      if (idx != null) ids.add(base + idx + 1);
      base += q.options.length;
    }

    addPlain(_toneQuestion, _toneIdx);
    addPlain(_poreQuestion, _poreIdx);
    addPlain(_elasticityQuestion, _elasticityIdx);

    return {'selected_option_ids': ids};
  }

  String _estimateSkinType({
    required int oil,
    required int dehydrated,
    required int sensitive,
  }) {
    if (sensitive >= 6) return '민감성';
    if (oil >= 5 && dehydrated >= 4) return '복합성';
    if (oil >= 5) return '지성';
    if (dehydrated >= 5) return '건성';
    return '중성';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AppLogo(fontSize: 22),
                ),
                const SizedBox(height: 18),
                const Text(
                  '피부 설문조사',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '문항에 답해주시면 피부 타입을 진단하고\n맞춤 제품을 추천해 드려요.',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13.5,
                    height: 1.5,
                    color: AppColors.textSub,
                  ),
                ),
                const SizedBox(height: 16),
                _ProgressBar(
                  progress: _progress,
                  answered: _answeredRequired,
                  total: _totalRequired,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              children: [
                _SectionHeader(
                  index: 1,
                  title: '피부 타입 판단',
                  hint: '각 문항에 가장 가까운 답을 선택해 주세요.',
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < _skinTypeQuestions.length; i++) ...[
                  _ScoredQuestionTile(
                    number: i + 1,
                    question: _skinTypeQuestions[i],
                    selectedIndex: _skinTypeAnswers[_skinTypeQuestions[i].key],
                    onChanged: (idx) => setState(() {
                      _skinTypeAnswers[_skinTypeQuestions[i].key] = idx;
                    }),
                  ),
                  const SizedBox(height: 18),
                ],

                const SizedBox(height: 8),
                _SectionHeader(
                  index: 2,
                  title: '피부 고민',
                  hint: '복수 선택 가능 · 선택하지 않아도 돼요.',
                ),
                const SizedBox(height: 14),
                _MultiSelectChips(
                  options: _concernsMaster,
                  selected: _concernIds,
                  onToggle: (id) => setState(() {
                    if (!_concernIds.add(id)) _concernIds.remove(id);
                  }),
                ),

                const SizedBox(height: 28),
                _SectionHeader(
                  index: 3,
                  title: '민감도 / 피부 상태',
                  hint: '필수 항목입니다.',
                ),
                const SizedBox(height: 14),
                _QuestionLabel(text: '피부 자극에 대한 반응은?'),
                const SizedBox(height: 10),
                _SingleSelectChips<int>(
                  options: _sensitivityLevels
                      .map((e) => _ChipChoice(value: e.id, label: e.label))
                      .toList(),
                  selected: _sensitivityLevel,
                  onChanged: (v) => setState(() => _sensitivityLevel = v),
                ),
                const SizedBox(height: 18),
                _QuestionLabel(text: '여드름이 자주 발생하나요?'),
                const SizedBox(height: 10),
                _SingleSelectChips<bool>(
                  options: const [
                    _ChipChoice(value: true, label: '예'),
                    _ChipChoice(value: false, label: '아니오'),
                  ],
                  selected: _acneProne,
                  onChanged: (v) => setState(() => _acneProne = v),
                ),

                const SizedBox(height: 28),
                _SectionHeader(
                  index: 4,
                  title: '기피 성분',
                  hint: '복수 선택 가능 · 없으면 비워두세요.',
                ),
                const SizedBox(height: 14),
                _MultiSelectChips(
                  options: _allergiesMaster,
                  selected: _allergyIds,
                  onToggle: (id) => setState(() {
                    if (!_allergyIds.add(id)) _allergyIds.remove(id);
                  }),
                ),

                const SizedBox(height: 28),
                _SectionHeader(
                  index: 5,
                  title: '선호 제형',
                  hint: '가장 좋아하는 한 가지를 선택해 주세요.',
                ),
                const SizedBox(height: 14),
                _SingleSelectChips<int>(
                  options: _texturesMaster
                      .map((e) => _ChipChoice(value: e.id, label: e.label))
                      .toList(),
                  selected: _textureId,
                  onChanged: (v) => setState(() => _textureId = v),
                ),

                const SizedBox(height: 28),
                _SectionHeader(
                  index: 6,
                  title: '추가 피부 특성',
                  hint: '필수 항목입니다.',
                ),
                const SizedBox(height: 14),
                _PlainQuestionTile(
                  question: _toneQuestion,
                  selectedIndex: _toneIdx,
                  onChanged: (v) => setState(() => _toneIdx = v),
                ),
                const SizedBox(height: 18),
                _PlainQuestionTile(
                  question: _poreQuestion,
                  selectedIndex: _poreIdx,
                  onChanged: (v) => setState(() => _poreIdx = v),
                ),
                const SizedBox(height: 18),
                _PlainQuestionTile(
                  question: _elasticityQuestion,
                  selectedIndex: _elasticityIdx,
                  onChanged: (v) => setState(() => _elasticityIdx = v),
                ),

                const SizedBox(height: 32),
                PrimaryButton(
                  text: _canSubmit ? '제출' : '제출 ($_answeredRequired/$_totalRequired)',
                  onTap: _handleSubmit,
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

// -------- shared widgets --------

class _ProgressBar extends StatelessWidget {
  final double progress;
  final int answered;
  final int total;

  const _ProgressBar({
    required this.progress,
    required this.answered,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '진행 상황',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSub,
              ),
            ),
            Text(
              '$answered / $total',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.primaryLight,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int index;
  final String title;
  final String hint;

  const _SectionHeader({
    required this.index,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            hint,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.5,
              color: AppColors.textSub,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionLabel extends StatelessWidget {
  final String text;
  const _QuestionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textMain,
      ),
    );
  }
}

class _ScoredQuestionTile extends StatelessWidget {
  final int number;
  final _ScoredQuestion question;
  final int? selectedIndex;
  final ValueChanged<int> onChanged;

  const _ScoredQuestionTile({
    required this.number,
    required this.question,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Q$number. ${question.prompt}',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < question.options.length; i++)
              _ChoiceChip(
                label: question.options[i].label,
                isSelected: selectedIndex == i,
                onTap: () => onChanged(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _PlainQuestionTile extends StatelessWidget {
  final _PlainQuestion question;
  final int? selectedIndex;
  final ValueChanged<int> onChanged;

  const _PlainQuestionTile({
    required this.question,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuestionLabel(text: question.prompt),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < question.options.length; i++)
              _ChoiceChip(
                label: question.options[i],
                isSelected: selectedIndex == i,
                onTap: () => onChanged(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChipChoice<T> {
  final T value;
  final String label;
  const _ChipChoice({required this.value, required this.label});
}

class _SingleSelectChips<T> extends StatelessWidget {
  final List<_ChipChoice<T>> options;
  final T? selected;
  final ValueChanged<T> onChanged;

  const _SingleSelectChips({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opt in options)
          _ChoiceChip(
            label: opt.label,
            isSelected: selected == opt.value,
            onTap: () => onChanged(opt.value),
          ),
      ],
    );
  }
}

class _MultiSelectChips extends StatelessWidget {
  final List<_IdOption> options;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  const _MultiSelectChips({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opt in options)
          _ChoiceChip(
            label: opt.label,
            isSelected: selected.contains(opt.id),
            onTap: () => onToggle(opt.id),
          ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassChip(
      label: label,
      selected: isSelected,
      onTap: onTap,
    );
  }
}

class _SurveyResultDialog extends StatelessWidget {
  final String estimatedType;
  final int oilScore;
  final int dehydratedScore;
  final int sensitiveScore;
  final int sensitivityLevel;
  final bool acneProne;
  final int concernCount;
  final int allergyCount;

  const _SurveyResultDialog({
    required this.estimatedType,
    required this.oilScore,
    required this.dehydratedScore,
    required this.sensitiveScore,
    required this.sensitivityLevel,
    required this.acneProne,
    required this.concernCount,
    required this.allergyCount,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        '설문 결과',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '추정 피부 타입 · $estimatedType',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ResultRow(label: '유분 점수', value: '$oilScore'),
          _ResultRow(label: '수분 부족 점수', value: '$dehydratedScore'),
          _ResultRow(label: '민감 점수', value: '$sensitiveScore'),
          const SizedBox(height: 6),
          _ResultRow(label: '민감도(1~5)', value: '$sensitivityLevel'),
          _ResultRow(label: '여드름 경향', value: acneProne ? '예' : '아니오'),
          _ResultRow(label: '선택한 고민', value: '$concernCount개'),
          _ResultRow(label: '기피 성분', value: '$allergyCount개'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '확인',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13.5,
              color: AppColors.textSub,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}
