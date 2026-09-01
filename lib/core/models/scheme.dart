class Scheme {
  final int? schemeId;
  final String schemeName;
  final String category;
  final int? parentSchemeId;
  final int? parentSetId;
  final String? description;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  // Computed fields (not stored in DB)
  final int setCount;
  final double totalAmount;
  final String? parentSchemeName;
  final String? parentSetLabel;

  Scheme({
    this.schemeId,
    required this.schemeName,
    this.category = 'scheme',
    this.parentSchemeId,
    this.parentSetId,
    this.description,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.setCount = 0,
    this.totalAmount = 0.0,
    this.parentSchemeName,
    this.parentSetLabel,
  });

  Map<String, dynamic> toMap() {
    return {
      if (schemeId != null) 'scheme_id': schemeId,
      'scheme_name': schemeName,
      'category': category,
      'parent_scheme_id': parentSchemeId,
      'parent_set_id': parentSetId,
      'description': description,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Scheme.fromMap(Map<String, dynamic> map) {
    return Scheme(
      schemeId: map['scheme_id'] as int?,
      schemeName: map['scheme_name'] as String,
      category: (map['category'] as String?) ?? 'scheme',
      parentSchemeId: map['parent_scheme_id'] as int?,
      parentSetId: map['parent_set_id'] as int?,
      description: map['description'] as String?,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
      setCount: map['set_count'] as int? ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      parentSchemeName: map['parent_scheme_name'] as String?,
      parentSetLabel: map['parent_set_label'] as String?,
    );
  }

  Scheme copyWith({
    int? schemeId,
    String? schemeName,
    String? category,
    int? parentSchemeId,
    int? parentSetId,
    String? description,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
    int? setCount,
    double? totalAmount,
    String? parentSchemeName,
    String? parentSetLabel,
  }) {
    return Scheme(
      schemeId: schemeId ?? this.schemeId,
      schemeName: schemeName ?? this.schemeName,
      category: category ?? this.category,
      parentSchemeId: parentSchemeId ?? this.parentSchemeId,
      parentSetId: parentSetId ?? this.parentSetId,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      setCount: setCount ?? this.setCount,
      totalAmount: totalAmount ?? this.totalAmount,
      parentSchemeName: parentSchemeName ?? this.parentSchemeName,
      parentSetLabel: parentSetLabel ?? this.parentSetLabel,
    );
  }
}
