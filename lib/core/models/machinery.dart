import 'dart:convert';

class Machinery {
  final int? machineryId;
  final int setId;
  final String machineryType;
  final String? brand;
  final Map<String, String> specs;
  final String displayLabel;
  final int sortOrder;

  // Computed
  final int entryCount;
  final double totalAmount;

  Machinery({
    this.machineryId,
    required this.setId,
    required this.machineryType,
    this.brand,
    this.specs = const {},
    required this.displayLabel,
    this.sortOrder = 0,
    this.entryCount = 0,
    this.totalAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (machineryId != null) 'machinery_id': machineryId,
      'set_id': setId,
      'machinery_type': machineryType,
      'brand': brand,
      'specs': jsonEncode(specs),
      'display_label': displayLabel,
      'sort_order': sortOrder,
    };
  }

  factory Machinery.fromMap(Map<String, dynamic> map) {
    Map<String, String> specsMap = {};
    if (map['specs'] != null && map['specs'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['specs'] as String);
        if (decoded is Map) {
          specsMap = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }

    return Machinery(
      machineryId: map['machinery_id'] as int?,
      setId: map['set_id'] as int,
      machineryType: map['machinery_type'] as String,
      brand: map['brand'] as String?,
      specs: specsMap,
      displayLabel: map['display_label'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      entryCount: map['entry_count'] as int? ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Machinery copyWith({
    int? machineryId,
    int? setId,
    String? machineryType,
    String? brand,
    Map<String, String>? specs,
    String? displayLabel,
    int? sortOrder,
    int? entryCount,
    double? totalAmount,
  }) {
    return Machinery(
      machineryId: machineryId ?? this.machineryId,
      setId: setId ?? this.setId,
      machineryType: machineryType ?? this.machineryType,
      brand: brand ?? this.brand,
      specs: specs ?? this.specs,
      displayLabel: displayLabel ?? this.displayLabel,
      sortOrder: sortOrder ?? this.sortOrder,
      entryCount: entryCount ?? this.entryCount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
