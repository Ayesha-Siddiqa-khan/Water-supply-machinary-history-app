import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class WhatsappShareButton extends StatelessWidget {
  final String filePath;
  final String? message;

  const WhatsappShareButton({
    super.key,
    required this.filePath,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _shareViaWhatsApp(context),
      icon: const Icon(Icons.share, size: 18),
      label: const Text('Share via WhatsApp'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    try {
      final file = XFile(filePath);
      await Share.shareXFiles(
        [file],
        text: message ?? 'City Water Works — Billing Report',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }
}
