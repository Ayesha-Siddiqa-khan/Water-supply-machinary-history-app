import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/database/daos/miscellaneous_dao.dart';
import '../../shared/theme/app_colors.dart';
import 'category_detail_screen.dart';

// ─── Icon name resolver ──────────────────────────────────────────────

IconData _iconFromName(String name) {
  const map = <String, IconData>{
    'water_drop_outlined': Icons.water_drop_outlined,
    'power_outlined': Icons.power_outlined,
    'electrical_services_outlined': Icons.electrical_services_outlined,
    'settings_outlined': Icons.settings_outlined,
    'bolt_outlined': Icons.bolt_outlined,
    'engineering_outlined': Icons.engineering_outlined,
    'science_outlined': Icons.science_outlined,
    'category_outlined': Icons.category_outlined,
    'build_outlined': Icons.build_outlined,
    'construction_outlined': Icons.construction_outlined,
    'plumbing_outlined': Icons.plumbing_outlined,
    'electric_bolt_outlined': Icons.electric_bolt_outlined,
    'local_fire_department_outlined': Icons.local_fire_department_outlined,
    'health_and_safety_outlined': Icons.health_and_safety_outlined,
    'warning_amber_outlined': Icons.warning_amber_outlined,
    'inventory_2_outlined': Icons.inventory_2_outlined,
    'warehouse_outlined': Icons.warehouse_outlined,
    'handyman_outlined': Icons.handyman_outlined,
    'precision_manufacturing_outlined': Icons.precision_manufacturing_outlined,
    'schema_outlined': Icons.schema_outlined,
    'device_hub_outlined': Icons.device_hub_outlined,
    'router_outlined': Icons.router_outlined,
    'memory_outlined': Icons.memory_outlined,
    'developer_board_outlined': Icons.developer_board_outlined,
    'cable_outlined': Icons.cable_outlined,
    'extension_outlined': Icons.extension_outlined,
    'battery_charging_full_outlined': Icons.battery_charging_full_outlined,
    'solar_power_outlined': Icons.solar_power_outlined,
    'water_outlined': Icons.water_outlined,
    'pipe_outlined': Icons.plumbing_outlined,
    'valve_outlined': Icons.settings_outlined,
    'filter_alt_outlined': Icons.filter_alt_outlined,
    'ac_unit_outlined': Icons.ac_unit_outlined,
    'speed_outlined': Icons.speed_outlined,
    'thermostat_outlined': Icons.thermostat_outlined,
    'sensors_outlined': Icons.sensors_outlined,
    'videocam_outlined': Icons.videocam_outlined,
    'lock_outlined': Icons.lock_outlined,
    'key_outlined': Icons.key_outlined,
    'shield_outlined': Icons.shield_outlined,
    'alarm_outlined': Icons.alarm_outlined,
    'notification_important_outlined': Icons.notification_important_outlined,
    'report_outlined': Icons.report_outlined,
    'analytics_outlined': Icons.analytics_outlined,
    'assessment_outlined': Icons.assessment_outlined,
    'timeline_outlined': Icons.timeline_outlined,
    'date_range_outlined': Icons.date_range_outlined,
    'event_outlined': Icons.event_outlined,
    'schedule_outlined': Icons.schedule_outlined,
    'pending_outlined': Icons.pending_outlined,
    'check_circle_outline': Icons.check_circle_outline,
    'cancel_outlined': Icons.cancel_outlined,
    'info_outline': Icons.info_outline,
    'help_outline': Icons.help_outline,
    'star_outline': Icons.star_outline,
    'favorite_outline': Icons.favorite_outlined,
    'bookmark_outline': Icons.bookmark_outline,
    'flag_outlined': Icons.flag_outlined,
    'label_outlined': Icons.label_outlined,
    'new_releases_outlined': Icons.new_releases_outlined,
    'upcoming_outlined': Icons.upcoming_outlined,
    'tour_outlined': Icons.tour_outlined,
    'explore_outlined': Icons.explore_outlined,
    'map_outlined': Icons.map_outlined,
    'place_outlined': Icons.place_outlined,
    'near_me_outlined': Icons.near_me_outlined,
    'directions_outlined': Icons.directions_outlined,
    'traffic_outlined': Icons.traffic_outlined,
    'trip_origin_outlined': Icons.trip_origin_outlined,
    'flight_outlined': Icons.flight_outlined,
    'flight_takeoff_outlined': Icons.flight_takeoff_outlined,
    'flight_land_outlined': Icons.flight_land_outlined,
    'rocket_outlined': Icons.rocket_outlined,
    'satellite_outlined': Icons.satellite_outlined,
    'dns_outlined': Icons.dns_outlined,
    'cloud_outlined': Icons.cloud_outlined,
    'cloud_queue_outlined': Icons.cloud_queue_outlined,
    'storage_outlined': Icons.storage_outlined,
    'sd_storage_outlined': Icons.sd_storage_outlined,
    'sim_card_outlined': Icons.sim_card_outlined,
    'sim_card_alert_outlined': Icons.sim_card_alert_outlined,
  };
  return map[name] ?? Icons.category_outlined;
}

const _presetIconNames = <String>[
  'water_drop_outlined',
  'power_outlined',
  'electrical_services_outlined',
  'settings_outlined',
  'bolt_outlined',
  'engineering_outlined',
  'science_outlined',
  'category_outlined',
  'build_outlined',
  'construction_outlined',
  'plumbing_outlined',
  'electric_bolt_outlined',
  'local_fire_department_outlined',
  'health_and_safety_outlined',
  'warning_amber_outlined',
  'inventory_2_outlined',
  'warehouse_outlined',
  'handyman_outlined',
  'precision_manufacturing_outlined',
  'schema_outlined',
  'device_hub_outlined',
  'memory_outlined',
  'developer_board_outlined',
  'cable_outlined',
  'battery_charging_full_outlined',
  'solar_power_outlined',
  'water_outlined',
  'filter_alt_outlined',
  'ac_unit_outlined',
  'speed_outlined',
  'thermostat_outlined',
  'sensors_outlined',
  'videocam_outlined',
  'lock_outlined',
  'key_outlined',
  'shield_outlined',
  'alarm_outlined',
  'notification_important_outlined',
  'report_outlined',
  'analytics_outlined',
  'assessment_outlined',
  'timeline_outlined',
  'date_range_outlined',
  'event_outlined',
  'schedule_outlined',
  'check_circle_outline',
  'info_outline',
  'star_outline',
  'flag_outlined',
  'label_outlined',
];

const _presetColors = <int>[
  0xFFE53935,
  0xFF1E88E5,
  0xFFFDD835,
  0xFF43A047,
  0xFF8E24AA,
  0xFFD81B60,
  0xFF00ACC1,
  0xFF6D4C41,
  0xFFFF6F00,
  0xFF1565C0,
  0xFF2E7D32,
  0xFF6A1B9A,
  0xFFC62828,
  0xFF00838F,
  0xFFEF6C00,
  0xFF4527A0,
];

// ─── Screen ──────────────────────────────────────────────────────────

class MiscellaneousScreen extends StatefulWidget {
  const MiscellaneousScreen({super.key});

  @override
  State<MiscellaneousScreen> createState() => _MiscellaneousScreenState();
}

class _MiscellaneousScreenState extends State<MiscellaneousScreen> {
  final _miscDao = MiscellaneousDao();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cats = await _miscDao.getAllCategoryMeta();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  void _openCategory(Map<String, dynamic> cat) async {
    final name = (cat['name'] ?? '').toString();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryDetailScreen(categoryName: name)),
    );
    _loadData();
  }

  Future<void> _showCategoryDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description']?.toString() ?? '');
    String iconName = existing?['icon_name']?.toString() ?? 'category_outlined';
    int colorValue = existing?['color_value'] as int? ?? AppColors.primary.toARGB32();
    List<Map<String, dynamic>> customFields = [];
    if (existing?['custom_fields'] != null) {
      try {
        customFields = List<Map<String, dynamic>>.from(jsonDecode(existing!['custom_fields'].toString()));
      } catch (_) {}
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Category' : 'Add New Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Category Name *',
                    hintText: 'e.g., Generator, Pipeline Repair',
                  ),
                ),
                const SizedBox(height: 16),

                // Icon picker
                Text('Icon', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _presetIconNames.map((name) {
                        final isSelected = name == iconName;
                        return SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _iconFromName(name),
                              color: isSelected ? Color(colorValue) : AppColors.textSecondary,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: isSelected
                                  ? Color(colorValue).withValues(alpha: 0.15)
                                  : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: isSelected
                                    ? BorderSide(color: Color(colorValue), width: 2)
                                    : BorderSide.none,
                              ),
                            ),
                            onPressed: () => setDialogState(() => iconName = name),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Color picker
                Text('Color', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetColors.map((c) {
                    final isSelected = c == colorValue;
                    return GestureDetector(
                      onTap: () => setDialogState(() => colorValue = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: Color(c).withValues(alpha: 0.5), blurRadius: 6)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional description',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Custom fields
                Row(
                  children: [
                    Text('Custom Fields', style: Theme.of(ctx).textTheme.titleSmall),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final field = await _showAddFieldDialog(ctx);
                        if (field != null) setDialogState(() => customFields.add(field));
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                if (customFields.isNotEmpty)
                  ...customFields.asMap().entries.map((e) {
                    final i = e.key;
                    final f = e.value;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
                      title: Text(f['label'] ?? ''),
                      subtitle: Text('${f['type'] ?? 'dropdown'} • ${(f['options'] as List?)?.length ?? 0} options'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => setDialogState(() => customFields.removeAt(i)),
                      ),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, {
                  'name': name,
                  'icon_name': iconName,
                  'color_value': colorValue,
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'custom_fields': customFields.isEmpty ? null : jsonEncode(customFields),
                  'sort_order': existing?['sort_order'] ?? _categories.length,
                });
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();
    if (result == null) return;

    if (isEdit) {
      final catId = existing['category_id'] as int;
      final oldName = (existing['name'] ?? '').toString();
      await _miscDao.updateCategory(catId, result);
      if (result['name'] != oldName) {
        await _miscDao.renameCategoryInRecords(oldName, result['name']);
      }
    } else {
      await _miscDao.insertCategory(result);
    }
    _loadData();
  }

  Future<Map<String, dynamic>?> _showAddFieldDialog(BuildContext context) async {
    final labelCtrl = TextEditingController();
    String type = 'dropdown';
    final optionsCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Field'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Field Label *'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'dropdown', label: Text('Dropdown')),
                  ButtonSegment(value: 'text', label: Text('Text')),
                  ButtonSegment(value: 'number', label: Text('Number')),
                ],
                selected: {type},
                onSelectionChanged: (v) => type = v.first,
              ),
              const SizedBox(height: 12),
              if (type == 'dropdown')
                TextField(
                  controller: optionsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Options (one per line)',
                    hintText: 'Option 1\nOption 2\nOption 3',
                  ),
                  maxLines: 4,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final label = labelCtrl.text.trim();
              if (label.isEmpty) return;
              final options = type == 'dropdown'
                  ? optionsCtrl.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
                  : <String>[];
              Navigator.pop(ctx, {'label': label, 'type': type, 'options': options, 'key': label.toLowerCase().replaceAll(RegExp(r'\s+'), '_')});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(Map<String, dynamic> cat) async {
    final name = (cat['name'] ?? '').toString();
    final count = cat['record_count'] as int? ?? 0;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: count > 0
            ? Text('"$name" has $count record${count == 1 ? '' : 's'}. What would you like to do?')
            : Text('Delete "$name" category?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (count > 0)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'archive'),
              child: const Text('Archive Records'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (action == null) return;

    if (action == 'archive') {
      // Move records to "Other" category, then delete this category
      final otherCat = await _miscDao.getCategoryMetaByName('Other');
      if (otherCat != null) {
        await _miscDao.renameCategoryInRecords(name, 'Other');
      } else {
        // No "Other" category exists, just delete records
        await _miscDao.deleteRecordsByCategory(name);
      }
    }
    if (action == 'delete' && count > 0) {
      await _miscDao.deleteRecordsByCategory(name);
    }
    await _miscDao.deleteCategory(cat['category_id'] as int);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 900 ? 4 : (screenWidth >= 600 ? 3 : 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Miscellaneous'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _categories.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 64, color: AppColors.textHint),
                            const SizedBox(height: 16),
                            const Text('No categories yet.\nTap + to add one.', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _categories.length) {
                          return _AddCategoryCard(onTap: () => _showCategoryDialog());
                        }
                        final cat = _categories[index];
                        return _CategoryCard(
                          category: cat,
                          onTap: () => _openCategory(cat),
                          onEdit: () => _showCategoryDialog(existing: cat),
                          onDelete: () => _deleteCategory(cat),
                        );
                      },
                    ),
            ),
    );
  }
}

// ─── Category Card ───────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final Map<String, dynamic> category;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = (category['name'] ?? '').toString();
    final iconName = (category['icon_name'] ?? 'category_outlined').toString();
    final colorVal = category['color_value'] as int? ?? AppColors.primary.toARGB32();
    final color = Color(colorVal);
    final count = category['record_count'] as int? ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.12),
                color.withValues(alpha: 0.04),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  const Spacer(),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              Icon(_iconFromName(iconName), size: 36, color: color),
              const SizedBox(height: 10),
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '$count record${count == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add Category Card ──────────────────────────────────────────────

class _AddCategoryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCategoryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 36, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(
                'Add New\nCategory',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
