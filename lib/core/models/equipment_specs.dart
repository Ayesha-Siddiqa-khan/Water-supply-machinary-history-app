import 'machinery.dart';

/// Field templates for detailed specification sheets, per machinery type.
/// Fields containing "(Yes/No)" render as a Yes/No dropdown and fields
/// starting with "Other" render multiline in the specs editor.
const Map<String, List<String>> _specTemplates = {
  'motor': [
    'Make & Model',
    'Rated Power (HP/kW)',
    'Rated RPM',
    'Power Factor',
    'Efficiency (%)',
    'Rated Voltage (V)',
    'Rated Current (A)',
    'VFD Installed (Yes/No)',
    'Other Motor Specifications',
  ],
  'pump': [
    'Pump Number',
    'Make & Model',
    'Pump Size',
    'Rated Discharge',
    'Total Head (Feet)',
    'Number of Stages',
    'Other Pump Specifications',
  ],
  'transformer': [
    'Transformer Number',
    'Make & Model',
    'Capacity (kVA)',
    'Primary Voltage (HV)',
    'Secondary Voltage (LV)',
    'Phase',
    'Other Transformer Specifications',
  ],
  'turbine': [
    'Turbine Number',
    'Make & Model',
    'Serial Number',
    'Rated Discharge',
    'Total Design Head (Feet)',
    'Rated Speed (RPM)',
    'Suction Pipe Size (Inches)',
    'Delivery Pipe Size (Inches)',
    'Pump Depth (Feet)',
    'Other Turbine Specifications',
  ],
};

/// Fields stored on the set itself (sets.details JSON column).
const List<String> setDetailFields = [
  'Location / GPS Coordinates',
  'Electricity Bill Reference No.',
  'Electricity Distribution Company',
  'Consumer No. / Meter No.',
  'Other Set Information',
];

/// Spec sheet fields for a machinery type; generic fallback for unknown types
/// (Electrical Items, Miscellaneous, custom types).
List<String> specFieldsFor(String machineryType) {
  final template = _specTemplates[machineryType.trim().toLowerCase()];
  if (template != null) return template;
  return const [
    'Item Number',
    'Make & Model',
    'Rating / Specification',
    'Serial Number',
    'Other Specifications',
  ];
}

/// Merge edited spec values back into existing ones: template fields are
/// replaced wholesale (cleared fields removed), all other keys (e.g. specs
/// captured by the machinery form like Horsepower) are preserved.
Map<String, String> mergeSpecValues(
  Map<String, String> existing,
  List<String> templateFields,
  Map<String, String> edited,
) {
  final merged = Map<String, String>.from(existing);
  for (final f in templateFields) {
    merged.remove(f);
  }
  merged.addAll(edited);
  return merged;
}

/// Same-type machinery (excluding self) that have non-empty specs, keyed by a
/// unique display label — the sources offered by "Copy Specifications".
Map<String, Map<String, String>> buildCopyTemplates(
  String machineryType,
  Iterable<Machinery> all, {
  int? excludeId,
}) {
  final key = machineryType.trim().toLowerCase();
  final sources = <String, Map<String, String>>{};
  for (final m in all) {
    if (m.machineryId == null || m.machineryId == excludeId) continue;
    if (m.machineryType.trim().toLowerCase() != key) continue;
    final specs = Map<String, String>.from(m.specs)
      ..removeWhere((_, v) => v.trim().isEmpty);
    if (specs.isEmpty) continue;
    var label = m.displayLabel;
    while (sources.containsKey(label)) {
      label = '$label (#${m.machineryId})';
    }
    sources[label] = specs;
  }
  return sources;
}
