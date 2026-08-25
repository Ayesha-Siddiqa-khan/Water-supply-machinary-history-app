import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:city_water_works_app/core/models/billing_entry.dart';
import 'package:city_water_works_app/core/models/equipment_specs.dart';
import 'package:city_water_works_app/core/models/machinery.dart';
import 'package:city_water_works_app/core/models/set_model.dart';
import 'package:city_water_works_app/features/machinery/specs_editor_dialog.dart';

void main() {
  group('mergeSpecValues', () {
    test('preserves non-template keys (specs from machinery form)', () {
      final existing = {'Horsepower': '50HP', 'Brand': 'Siemens'};
      final merged = mergeSpecValues(existing, specFieldsFor('Motor'), {
        'Rated RPM': '1480',
      });
      expect(merged['Horsepower'], '50HP');
      expect(merged['Brand'], 'Siemens');
      expect(merged['Rated RPM'], '1480');
    });

    test('removes cleared template fields and overwrites edits', () {
      final existing = {'Rated RPM': '1480', 'VFD Installed (Yes/No)': 'Yes', 'Horsepower': '50HP'};
      final merged = mergeSpecValues(existing, specFieldsFor('Motor'), {
        'Rated RPM': '2960',
        'VFD Installed (Yes/No)': 'No',
      });
      expect(merged['Rated RPM'], '2960');
      expect(merged['VFD Installed (Yes/No)'], 'No');
      expect(merged['Horsepower'], '50HP');
    });

    test('every equipment type has a template with an Other field', () {
      for (final type in ['Motor', 'Pump', 'Transformer', 'Turbine', 'Electrical Items', 'Anything']) {
        final fields = specFieldsFor(type);
        expect(fields, isNotEmpty, reason: type);
        expect(fields.any((f) => f.startsWith('Other')), true, reason: type);
      }
    });
  });

  group('buildCopyTemplates', () {
    final all = [
      Machinery(machineryId: 1, setId: 1, machineryType: 'Motor', displayLabel: 'Motor 50HP Siemens',
          specs: {'Rated RPM': '1480', 'Horsepower': '50HP'}),
      Machinery(machineryId: 2, setId: 2, machineryType: 'motor', displayLabel: 'Motor 20HP',
          specs: {'Rated RPM': '2960'}),
      Machinery(machineryId: 3, setId: 1, machineryType: 'Pump', displayLabel: 'Pump 4x5',
          specs: {'Rated Discharge': '2 cusec'}),
      Machinery(machineryId: 4, setId: 1, machineryType: 'Motor', displayLabel: 'Motor empty specs',
          specs: {}),
      Machinery(machineryId: 5, setId: 1, machineryType: 'Motor', displayLabel: 'Motor 50HP Siemens',
          specs: {'Rated RPM': '960'}),
    ];

    test('same type only, excludes self and empty specs', () {
      final templates = buildCopyTemplates('Motor', all, excludeId: 1);
      expect(templates.keys, ['Motor 20HP', 'Motor 50HP Siemens']);
      expect(templates['Motor 20HP'], {'Rated RPM': '2960'});
    });

    test('duplicate labels get a unique suffix', () {
      final templates = buildCopyTemplates('Motor', all, excludeId: 4);
      expect(templates.keys, ['Motor 50HP Siemens', 'Motor 20HP', 'Motor 50HP Siemens (#5)']);
    });

    test('excluded machinery is not offered', () {
      expect(buildCopyTemplates('Motor', all, excludeId: 2).containsKey('Motor 20HP'), false);
    });

    test('matches type case-insensitively', () {
      expect(buildCopyTemplates('  motor ', all, excludeId: 1).length, 2);
    });
  });

  group('BillingEntry.workOrderNo', () {
    test('round-trips through toMap/fromMap', () {
      final entry = BillingEntry(
        machineryId: 1,
        serialNo: 1,
        entryDate: '20-03-2025',
        workOrderNo: 'WO-123',
        voucherNo: 1804,
        amount: 141925,
      );
      final restored = BillingEntry.fromMap(entry.toMap());
      expect(restored.workOrderNo, 'WO-123');
      expect(restored.voucherNo, 1804);
    });

    test('null work order stays null', () {
      final entry = BillingEntry(machineryId: 1, serialNo: 1, entryDate: '20-03-2025', amount: 1);
      expect(BillingEntry.fromMap(entry.toMap()).workOrderNo, isNull);
      expect(BillingEntry.fromMap(<String, dynamic>{
        'machinery_id': 1,
        'serial_no': 1,
        'entry_date': '20-03-2025',
        'amount': 1,
      }).workOrderNo, isNull);
    });
  });

  group('SpecClipboard', () {
    test('copy, type-guarded paste, clear', () {
      SpecClipboard.clear();
      expect(SpecClipboard.matchesType('Motor'), false);

      SpecClipboard.copy('Motor', {'Rated RPM': '2950', 'Other Motor Specifications': ''});
      expect(SpecClipboard.matchesType('  motor '), true);
      expect(SpecClipboard.matchesType('Pump'), false);
      expect(SpecClipboard.matchesType(null), false);
      expect(SpecClipboard.paste(), {'Rated RPM': '2950'});

      // Paste returns a copy — editing it must not touch the clipboard.
      final values = SpecClipboard.paste();
      values['Rated RPM'] = '9999';
      expect(SpecClipboard.paste()['Rated RPM'], '2950');

      SpecClipboard.clear();
      expect(SpecClipboard.matchesType('Motor'), false);
    });
  });

  group('SetModel.details', () {
    test('round-trips through toMap/fromMap', () {
      final set = SetModel(schemeId: 1, setNumber: 1, setLabel: 'Set No. 1', details: {
        'Location / GPS Coordinates': '24.86, 67.00',
        'Electricity Bill Reference No.': '12345',
      });
      final restored = SetModel.fromMap({
        ...set.toMap(),
        'machinery_count': 0,
        'entry_count': 0,
        'total_amount': 0,
      });
      expect(restored.details, set.details);
    });

    test('handles null/corrupt details column without throwing', () {
      final set = SetModel.fromMap({
        'set_id': 1,
        'scheme_id': 1,
        'set_number': 1,
        'set_label': 'Set No. 1',
        'details': null,
      });
      expect(set.details, isEmpty);

      final corrupt = SetModel.fromMap({
        'set_id': 1,
        'scheme_id': 1,
        'set_number': 1,
        'set_label': 'Set No. 1',
        'details': '{not json',
      });
      expect(corrupt.details, isEmpty);
    });

    test('details encode as valid JSON string in toMap', () {
      final map = SetModel(schemeId: 1, setNumber: 1, setLabel: 'S', details: {'A': 'B'}).toMap();
      expect(jsonDecode(map['details'] as String), {'A': 'B'});
    });
  });
}
