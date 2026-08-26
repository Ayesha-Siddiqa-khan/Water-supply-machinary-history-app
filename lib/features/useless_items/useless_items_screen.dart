import 'package:flutter/material.dart';
import 'package:city_water_works_app/l10n/app_localizations.dart';

import '../schemes/schemes_list_screen.dart';

class UselessItemsScreen extends StatelessWidget {
  final int? schemeId;
  final String? schemeName;
  final int? setId;
  final String? setLabel;

  const UselessItemsScreen({
    super.key,
    this.schemeId,
    this.schemeName,
    this.setId,
    this.setLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SchemesListScreen(
      title: setLabel != null
          ? 'Useless Items — $setLabel'
          : schemeName == null
          ? l10n.navUselessItems
          : 'Useless Items — $schemeName',
      schemeCategory: 'useless_item',
      emptyStateTitle: l10n.uselessEmptyTitle,
      emptyStateSubtitle: l10n.uselessEmptySubtitle,
      addButtonLabel: l10n.uselessAddButton,
      parentSchemeId: schemeId,
      parentSetId: setId,
    );
  }
}
