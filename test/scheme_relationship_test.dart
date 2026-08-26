import 'package:city_water_works_app/core/models/scheme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Scheme preserves its parent scheme relationship in database maps', () {
    final scheme = Scheme(
      schemeId: 7,
      schemeName: 'Old Pump Record',
      category: 'useless_item',
      parentSchemeId: 2,
      parentSchemeName: 'Scheme No. 2',
      parentSetId: 12,
      parentSetLabel: 'Set No. 3',
      createdAt: '26-08-2026 10:00',
      updatedAt: '26-08-2026 10:00',
    );

    expect(scheme.toMap()['parent_scheme_id'], 2);
    expect(scheme.toMap()['parent_set_id'], 12);

    final restored = Scheme.fromMap({
      ...scheme.toMap(),
      'parent_scheme_name': 'Scheme No. 2',
      'parent_set_label': 'Set No. 3',
    });
    expect(restored.parentSchemeId, 2);
    expect(restored.parentSchemeName, 'Scheme No. 2');
    expect(restored.parentSetId, 12);
    expect(restored.parentSetLabel, 'Set No. 3');
  });
}
