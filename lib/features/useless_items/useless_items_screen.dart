import 'package:flutter/material.dart';
import 'package:city_water_works_app/l10n/app_localizations.dart';

import '../schemes/schemes_list_screen.dart';

class UselessItemsScreen extends StatelessWidget {
  const UselessItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SchemesListScreen(
      title: l10n.navUselessItems,
      schemeCategory: 'useless_item',
      emptyStateTitle: l10n.uselessEmptyTitle,
      emptyStateSubtitle: l10n.uselessEmptySubtitle,
      addButtonLabel: l10n.uselessAddButton,
    );
  }
}
