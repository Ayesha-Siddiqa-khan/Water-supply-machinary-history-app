import 'package:flutter/material.dart';
import '../../../core/models/billing_entry.dart';
import '../../../shared/utils/currency_utils.dart';
import '../../../shared/theme/app_colors.dart';

class RecentEntriesList extends StatelessWidget {
  final List<BillingEntry> entries;

  const RecentEntriesList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                entry.serialNo.toString(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            title: Text(
              entry.machineryLabel ?? 'Unknown Machinery',
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.schemeName != null || entry.setLabel != null)
                  Text(
                    '${entry.schemeName ?? ''} · ${entry.setLabel ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                Row(
                  children: [
                    Text(entry.entryDate, style: Theme.of(context).textTheme.bodySmall),
                    if (entry.voucherNo != null) ...[
                      const SizedBox(width: 8),
                      Text('V# ${entry.voucherNo}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (entry.regPageNo != null && entry.regPageNo!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('Pg ${entry.regPageNo}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Text(
              CurrencyUtils.formatAmount(entry.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 14,
              ),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
