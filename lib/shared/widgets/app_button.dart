import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isOutlined;
  final bool isLoading;
  final Color? color;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isOutlined = false,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink()),
        label: Text(label),
      );
    }

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink()),
      label: Text(label),
      style: color != null
          ? ElevatedButton.styleFrom(backgroundColor: color)
          : null,
    );
  }
}
