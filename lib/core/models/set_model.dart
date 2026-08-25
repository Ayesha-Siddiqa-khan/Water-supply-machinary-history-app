import 'dart:convert';

class SetModel {
  final int? setId;
  final int schemeId;
  final int setNumber;
  final String setLabel;
  final Map<String, String> details;

  // Computed fields
  final int machineryCount;
  final int entryCount;
  final double totalAmount;

  SetModel({
    this.setId,
    required this.schemeId,
    required this.setNumber,
    required this.setLabel,
    this.details = const {},
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
      'details': jsonEncode(details),
    };
  }

  factory SetModel.fromMap(Map<String, dynamic> map) {
    Map<String, String> detailsMap = {};
    if (map['details'] != null && map['details'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['details'] as String);
        if (decoded is Map) {
          detailsMap = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }

    return SetModel(
      setId: map['set_id'] as int?,
      schemeId: map['scheme_id'] as int,
      setNumber: map['set_number'] as int,
      setLabel: map['set_label'] as String,
      details: detailsMap,
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
    Map<String, String>? details,
    int? machineryCount,
    int? entryCount,
    double? totalAmount,
  }) {
    return SetModel(
      setId: setId ?? this.setId,
      schemeId: schemeId ?? this.schemeId,
      setNumber: setNumber ?? this.setNumber,
      setLabel: setLabel ?? this.setLabel,
      details: details ?? this.details,
      machineryCount: machineryCount ?? this.machineryCount,
      entryCount: entryCount ?? this.entryCount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
