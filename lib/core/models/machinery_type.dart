import 'dart:convert';

class MachineryType {
  final int? typeId;
  final String typeName;
  final List<MachineryAttribute> attributes;
  final String createdAt;

  MachineryType({
    this.typeId,
    required this.typeName,
    this.attributes = const [],
    this.createdAt = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (typeId != null) 'type_id': typeId,
      'type_name': typeName,
      'attributes': jsonEncode(attributes.map((a) => a.toMap()).toList()),
      'created_at': createdAt,
    };
  }

  factory MachineryType.fromMap(Map<String, dynamic> map) {
    List<MachineryAttribute> attrs = [];
    if (map['attributes'] != null && map['attributes'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['attributes'] as String);
        if (decoded is List) {
          attrs = decoded.map((a) => MachineryAttribute.fromMap(a)).toList();
        }
      } catch (_) {}
    }
    return MachineryType(
      typeId: map['type_id'] as int?,
      typeName: map['type_name'] as String,
      attributes: attrs,
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}

class MachineryAttribute {
  final String name;
  final String inputType; // text, number, dropdown
  final List<String> options; // for dropdown
  final bool required;

  MachineryAttribute({
    required this.name,
    this.inputType = 'text',
    this.options = const [],
    this.required = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'input_type': inputType,
      'options': options,
      'required': required,
    };
  }

  factory MachineryAttribute.fromMap(Map<String, dynamic> map) {
    return MachineryAttribute(
      name: map['name'] as String,
      inputType: map['input_type'] as String? ?? 'text',
      options: (map['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      required: map['required'] as bool? ?? false,
    );
  }
}
