class SetModel {
  final int? setId;
  final int schemeId;
  final int setNumber;
  final String setLabel;

  // Computed fields
  final int machineryCount;
  final int entryCount;
  final double totalAmount;

  SetModel({
    this.setId,
    required this.schemeId,
    required this.setNumber,
    required this.setLabel,
    this.machineryCount = 0,
    this.entryCount = 0,
    this.totalAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (setId != null) 'set_id': setId,
      'scheme_id': schemeId,
      'set_number': setNumber,
      'set_label': setLabel,
    };
  }

  factory SetModel.fromMap(Map<String, dynamic> map) {
    return SetModel(
      setId: map['set_id'] as int?,
      schemeId: map['scheme_id'] as int,
      setNumber: map['set_number'] as int,
      setLabel: map['set_label'] as String,
      machineryCount: map['machinery_count'] as int? ?? 0,
      entryCount: map['entry_count'] as int? ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  SetModel copyWith({
    int? setId,
    int? schemeId,
    int? setNumber,
    String? setLabel,
    int? machineryCount,
    int? entryCount,
    double? totalAmount,
  }) {
    return SetModel(
      setId: setId ?? this.setId,
      schemeId: schemeId ?? this.schemeId,
      setNumber: setNumber ?? this.setNumber,
      setLabel: setLabel ?? this.setLabel,
      machineryCount: machineryCount ?? this.machineryCount,
      entryCount: entryCount ?? this.entryCount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
