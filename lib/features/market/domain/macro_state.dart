/// Текущее состояние макромира (из aloria-api `/api/v1/macro/state`).
class MacroState {
  final String regime;
  final double keyRate;
  final double inflation;
  final int cycleDay;
  final int cycleLength;
  final String source;
  final DateTime updatedAt;

  const MacroState({
    required this.regime,
    required this.keyRate,
    required this.inflation,
    required this.cycleDay,
    required this.cycleLength,
    required this.source,
    required this.updatedAt,
  });

  factory MacroState.fromJson(Map<String, dynamic> json) => MacroState(
    regime: json['regime'] as String? ?? 'expansion',
    keyRate: (json['keyRate'] as num?)?.toDouble() ?? 0,
    inflation: (json['inflation'] as num?)?.toDouble() ?? 0,
    cycleDay: (json['cycleDay'] as num?)?.toInt() ?? 0,
    cycleLength: (json['cycleLength'] as num?)?.toInt() ?? 0,
    source: json['source'] as String? ?? 'mock',
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
