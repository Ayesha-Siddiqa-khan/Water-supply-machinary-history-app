import 'package:flutter/material.dart';
import '../../core/database/daos/billing_entries_dao.dart';
import '../../core/models/billing_entry.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/dd_mm_yyyy_date_picker.dart';
import '../../shared/widgets/amount_field.dart';

class BillingEntryForm extends StatefulWidget {
  final int machineryId;
  final BillingEntry? entry; // null for add, non-null for edit

  const BillingEntryForm({super.key, required this.machineryId, this.entry});

  @override
  State<BillingEntryForm> createState() => _BillingEntryFormState();
}

class _BillingEntryFormState extends State<BillingEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _dao = BillingEntriesDao();

  late TextEditingController _serialNoCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _voucherCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _regPageCtrl;
  late TextEditingController _notesCtrl;

  bool _isSaving = false;
  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _serialNoCtrl = TextEditingController();
    _dateCtrl = TextEditingController();
    _voucherCtrl = TextEditingController();
    _amountCtrl = TextEditingController();
    _regPageCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    if (_isEdit) {
      final e = widget.entry!;
      _serialNoCtrl.text = e.serialNo.toString();
      _dateCtrl.text = e.entryDate;
      _voucherCtrl.text = e.voucherNo?.toString() ?? '';
      _amountCtrl.text = e.amount.toStringAsFixed(0);
      _regPageCtrl.text = e.regPageNo ?? '';
      _notesCtrl.text = e.notes ?? '';
    } else {
      _loadDefaults();
    }
  }

  Future<void> _loadDefaults() async {
    final nextSn = await _dao.getNextSerialNo(widget.machineryId);
    _serialNoCtrl.text = nextSn.toString();

    final now = DateTime.now();
    _dateCtrl.text =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

    final lastVoucher = await _dao.getLastVoucherNo(widget.machineryId);
    if (lastVoucher != null) {
      _voucherCtrl.text = (lastVoucher + 1).toString();
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _serialNoCtrl.dispose();
    _dateCtrl.dispose();
    _voucherCtrl.dispose();
    _amountCtrl.dispose();
    _regPageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
      final voucherNo = int.tryParse(_voucherCtrl.text.trim());
      final serialNo = int.tryParse(_serialNoCtrl.text) ?? 1;

      if (_isEdit) {
        await _dao.updateEntry(widget.entry!.copyWith(
          serialNo: serialNo,
          entryDate: _dateCtrl.text.trim(),
          voucherNo: voucherNo,
          amount: amount,
          regPageNo: _regPageCtrl.text.trim().isEmpty ? null : _regPageCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          remarks: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          isDisabled: false,
          submittedToStoreDate: null,
          transferDate: null,
          transferredToScheme: null,
        ));
      } else {
        if (voucherNo != null) {
          final isDup = await _dao.checkDuplicate(
            widget.machineryId,
            _dateCtrl.text.trim(),
            voucherNo,
            amount,
          );
          if (isDup && mounted) {
            final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Possible Duplicate'),
                content: const Text(
                    'An entry with the same date, voucher number and amount already exists. Add anyway?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add Anyway')),
                ],
              ),
            );
            if (proceed != true) {
              setState(() => _isSaving = false);
              return;
            }
          }
        }

        await _dao.insertEntry(BillingEntry(
          machineryId: widget.machineryId,
          serialNo: serialNo,
          entryDate: _dateCtrl.text.trim(),
          voucherNo: voucherNo,
          amount: amount,
          regPageNo: _regPageCtrl.text.trim().isEmpty ? null : _regPageCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          remarks: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          isDisabled: false,
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
                      _isEdit ? 'Edit Entry' : 'Add Entry',
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
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DDMMYYYYDatePicker(
                      controller: _dateCtrl,
                      label: 'Date (DD-MM-YYYY)',
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _voucherCtrl,
                      label: 'Voucher No.',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AmountField(
                      controller: _amountCtrl,
                      label: 'Amount (PKR)',
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final num = double.tryParse(v.replaceAll(',', ''));
                        if (num == null || num < 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              AppTextField(
                controller: _regPageCtrl,
                label: 'Register Page No.',
              ),
              const SizedBox(height: 12),

              AppTextField(
                controller: _notesCtrl,
                label: 'Notes (optional)',
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
