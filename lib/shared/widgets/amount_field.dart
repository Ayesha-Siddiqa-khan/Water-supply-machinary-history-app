import 'package:flutter/material.dart';

class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String currencySymbol;
  final String? Function(String?)? validator;
  final String? hint;

  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Amount',
    this.currencySymbol = 'PKR',
    this.validator,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: '$currencySymbol ',
        prefixIcon: const Icon(Icons.payments_outlined),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) return 'Amount is required';
        final amount = double.tryParse(value.replaceAll(',', ''));
        if (amount == null || amount < 0) return 'Enter a valid amount';
        return null;
      },
    );
  }
}
