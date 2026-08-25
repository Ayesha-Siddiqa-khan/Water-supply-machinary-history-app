import 'package:flutter/material.dart';
import '../../core/database/daos/billing_entries_dao.dart';
import '../../core/models/billing_entry.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/dd_mm_yyyy_date_picker.dart';

class UselessEntryForm extends StatefulWidget {
  final int machineryId;
  final BillingEntry? entry;

  const UselessEntryForm({super.key, required this.machineryId, this.entry});

  @override
  State<UselessEntryForm> createState() => _UselessEntryFormState();
}

class _UselessEntryFormState extends State<UselessEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _dao = BillingEntriesDao();

  late TextEditingController _serialNoCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _regPageCtrl;
  late TextEditingController _submittedToStoreDateCtrl;
  late TextEditingController _transferDateCtrl;
  late TextEditingController _transferredToSchemeCtrl;
  late TextEditingController _remarksCtrl;

  bool _isDisabled = true;
  bool _isSaving = false;
  bool get _isEdit => widget.entry != null;

  String? _optionalDateValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final v = value.trim();
    final parts = v.split('-');
    if (parts.length != 3) return 'Invalid date format';

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return 'Invalid date format';

    final parsed = DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
    );
    if (parsed == null || parsed.day != day || parsed.month != month || parsed.year != year) {
      return 'Invalid date format';
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _serialNoCtrl = TextEditingController();
    _dateCtrl = TextEditingController();
    _regPageCtrl = TextEditingController();
    _submittedToStoreDateCtrl = TextEditingController();
    _transferDateCtrl = TextEditingController();
    _transferredToSchemeCtrl = TextEditingController();
    _remarksCtrl = TextEditingController();

    if (_isEdit) {
      final e = widget.entry!;
      _serialNoCtrl.text = e.serialNo.toString();
      _dateCtrl.text = e.entryDate;
      _regPageCtrl.text = e.regPageNo ?? '';
      _isDisabled = e.isDisabled;
      _submittedToStoreDateCtrl.text = e.submittedToStoreDate ?? '';
      _transferDateCtrl.text = e.transferDate ?? '';
      _transferredToSchemeCtrl.text = e.transferredToScheme ?? '';
      _remarksCtrl.text = e.remarks ?? e.notes ?? '';
    } else {
      _loadDefaults();
    }
  }

  String _todayDDMMYYYY() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  }

  Future<void> _loadDefaults() async {
    final nextSn = await _dao.getNextSerialNo(widget.machineryId);
    _serialNoCtrl.text = nextSn.toString();
    _dateCtrl.text = _todayDDMMYYYY();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _serialNoCtrl.dispose();
    _dateCtrl.dispose();
    _regPageCtrl.dispose();
    _submittedToStoreDateCtrl.dispose();
    _transferDateCtrl.dispose();
    _transferredToSchemeCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final serialNo = int.tryParse(_serialNoCtrl.text.trim()) ?? 1;
      final entryDate = _dateCtrl.text.trim().isEmpty ? _todayDDMMYYYY() : _dateCtrl.text.trim();

      if (_isEdit) {
        await _dao.updateEntry(BillingEntry(
          entryId: widget.entry!.entryId,
          machineryId: widget.entry!.machineryId,
          serialNo: serialNo,
          entryDate: entryDate,
          voucherNo: null,
          amount: 0,
          regPageNo: _regPageCtrl.text.trim().isEmpty ? null : _regPageCtrl.text.trim(),
          isDisabled: _isDisabled,
          submittedToStoreDate:
              _submittedToStoreDateCtrl.text.trim().isEmpty ? null : _submittedToStoreDateCtrl.text.trim(),
          transferDate: _transferDateCtrl.text.trim().isEmpty ? null : _transferDateCtrl.text.trim(),
          transferredToScheme:
              _transferredToSchemeCtrl.text.trim().isEmpty ? null : _transferredToSchemeCtrl.text.trim(),
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
          notes: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
          createdAt: widget.entry!.createdAt,
          updatedAt: widget.entry!.updatedAt,
        ));
      } else {
        await _dao.insertEntry(BillingEntry(
          machineryId: widget.machineryId,
          serialNo: serialNo,
          entryDate: entryDate,
          voucherNo: null,
          amount: 0,
          regPageNo: _regPageCtrl.text.trim().isEmpty ? null : _regPageCtrl.text.trim(),
          isDisabled: _isDisabled,
          submittedToStoreDate:
              _submittedToStoreDateCtrl.text.trim().isEmpty ? null : _submittedToStoreDateCtrl.text.trim(),
          transferDate: _transferDateCtrl.text.trim().isEmpty ? null : _transferDateCtrl.text.trim(),
          transferredToScheme:
              _transferredToSchemeCtrl.text.trim().isEmpty ? null : _transferredToSchemeCtrl.text.trim(),
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
          notes: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        ));
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit Useless Entry' : 'Add Entry',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: AppTextField(
                      controller: _serialNoCtrl,
                      label: 'Sr. No.',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DDMMYYYYDatePicker(
                      controller: _dateCtrl,
                      label: 'Date (DD/MM/YYYY)',
                      validator: _optionalDateValidator,
                      pickerLocale: const Locale('en', 'GB'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                value: _isDisabled,
                onChanged: (value) => setState(() => _isDisabled = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Item Disabled / Scheme Closed'),
                subtitle: const Text('Mark this entry as disabled/closed movement record'),
              ),
              const SizedBox(height: 8),

              AppTextField(
                controller: _regPageCtrl,
                label: 'Register Page No.',
              ),
              const SizedBox(height: 12),

              DDMMYYYYDatePicker(
                controller: _submittedToStoreDateCtrl,
                label: 'Submitted To Store Date (DD/MM/YYYY)',
                validator: _optionalDateValidator,
                showClearButton: true,
                pickerLocale: const Locale('en', 'GB'),
              ),
              const SizedBox(height: 12),

              DDMMYYYYDatePicker(
                controller: _transferDateCtrl,
                label: 'Transfer Date (DD/MM/YYYY)',
                validator: _optionalDateValidator,
                showClearButton: true,
                pickerLocale: const Locale('en', 'GB'),
              ),
              const SizedBox(height: 12),

              AppTextField(
                controller: _transferredToSchemeCtrl,
                label: 'Transferred To Scheme Name',
              ),
              const SizedBox(height: 12),

              AppTextField(
                controller: _remarksCtrl,
                label: 'Remarks (optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEdit ? 'Update Entry' : 'Add Entry'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
