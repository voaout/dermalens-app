/// Skin type master (matches the backend SkinType table).
class SkinType {
  final int id;
  final String code;

  /// Backend `name_kr` — used for matching the stored value.
  final String nameKr;
  final String nameEn;
  final String description;

  const SkinType({
    required this.id,
    required this.code,
    required this.nameKr,
    required this.nameEn,
    required this.description,
  });

  /// Display name: the original name (short form before any parenthesis)
  /// with "형" appended only when it's missing. e.g. "건강 건성" → "건강 건성형",
  /// "민지형(민감 지성)" → "민지형".
  String get displayName {
    final base = nameKr.contains('(')
        ? nameKr.substring(0, nameKr.indexOf('(')).trim()
        : nameKr;
    return base.endsWith('형') ? base : '$base형';
  }

  /// Display label, e.g. "건강 건성형(DN+)".
  String get label => '$displayName($code)';

  static const List<SkinType> all = [
    SkinType(
      id: 1,
      code: 'OS+',
      nameKr: '민지형(민감 지성)',
      nameEn: 'Oily, Sensitive, Hydrated',
      description: '유분은 많고 민감도도 높으며 수분은 비교적 유지되는 피부예요.',
    ),
    SkinType(
      id: 2,
      code: 'OS-',
      nameKr: '수부민지형(수분 부족형 민감 지성)',
      nameEn: 'Oily, Sensitive, Dehydrated',
      description: '유분은 많지만 수분이 부족하고 민감도가 높은 피부예요.',
    ),
    SkinType(
      id: 3,
      code: 'ON+',
      nameKr: '건지형(건강 지성)',
      nameEn: 'Oily, Non-Sensitive, Hydrated',
      description: '지성이지만 비교적 건강하고 수분이 유지되는 피부예요.',
    ),
    SkinType(
      id: 4,
      code: 'ON-',
      nameKr: '수부지형(수분 부족형 지성)',
      nameEn: 'Oily, Non-Sensitive, Dehydrated',
      description: '지성이면서 수분이 부족한 피부예요.',
    ),
    SkinType(
      id: 5,
      code: 'DS+',
      nameKr: '민건형(민감 건성)',
      nameEn: 'Dry, Sensitive, Hydrated',
      description: '건성이며 민감도가 높은 피부예요.',
    ),
    SkinType(
      id: 6,
      code: 'DS-',
      nameKr: '극건민감형(수분 부족형 민감 건성)',
      nameEn: 'Dry, Sensitive, Dehydrated',
      description: '매우 건조하고 민감한 피부예요.',
    ),
    SkinType(
      id: 7,
      code: 'DN+',
      nameKr: '건강 건성',
      nameEn: 'Dry, Non-Sensitive, Hydrated',
      description: '건성이지만 피부 장벽이 비교적 건강한 피부예요.',
    ),
    SkinType(
      id: 8,
      code: 'DN-',
      nameKr: '수분 부족형 건성',
      nameEn: 'Dry, Non-Sensitive, Dehydrated',
      description: '건성이며 수분 부족이 두드러지는 피부예요.',
    ),
  ];

  static SkinType? byCode(String code) {
    if (code.isEmpty) return null;
    for (final s in all) {
      if (s.code == code) return s;
    }
    return null;
  }

  // Normalizes a name for fuzzy matching: drops parentheses, spaces and a
  // trailing "형" so "건강건성형" and "건강 건성" compare equal.
  static String _key(String s) {
    var t = s.replaceAll(RegExp(r'\(.*?\)'), '');
    t = t.replaceAll(RegExp(r'\s'), '');
    if (t.endsWith('형')) t = t.substring(0, t.length - 1);
    return t;
  }

  /// Resolves a stored value (code or name_kr, with spacing/형 variations).
  static SkinType? resolve(String value) {
    if (value.isEmpty) return null;
    final byCodeHit = byCode(value);
    if (byCodeHit != null) return byCodeHit;

    final k = _key(value);
    if (k.isEmpty) return null;
    for (final s in all) {
      if (_key(s.nameKr) == k) return s;
    }
    for (final s in all) {
      final sk = _key(s.nameKr);
      if (sk.isNotEmpty && (k.contains(sk) || sk.contains(k))) return s;
    }
    return null;
  }
}
